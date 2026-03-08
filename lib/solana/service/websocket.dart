import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/constants/app.dart';
import 'package:iseefortune_flutter/solana/service/ws_rpc_error.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// SolanaWsService
/// ---------------------------------------------------------------------------
/// A small JSON-RPC WebSocket client for Solana.
/// Designed to be:
/// - Single shared socket (reused while there are active subscriptions)
/// - Safe (never crashes on malformed frames)
/// - Observable (logs ack failures / timeouts)
///
/// It supports:
/// - accountSubscribe
/// - programSubscribe
/// - signatureSubscribe
///
/// Critical behavior:
/// - Each subscribe call waits for an ACK (subscription id).
/// - If the ACK errors (JSON-RPC error), we surface it immediately.
/// - If the ACK times out, we reset the socket so the next subscribe reconnects.
///
/// Note:
/// Solana WS "subscribe" responses look like:
///   { "jsonrpc": "2.0", "result": 123, "id": 1 }
///
/// Errors look like:
///   { "jsonrpc": "2.0", "error": { "code": ..., "message": ..., "data": ... }, "id": 1 }
class SolanaWsService {
  WebSocketChannel? _chan;
  StreamSubscription? _chanSub;

  /// Broadcast stream of decoded JSON messages received from the socket.
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  /// JSON-RPC id counter.
  int _nextId = 1;

  /// Active subscriptions count (used to auto-close socket when it reaches zero).
  int _activeSubs = 0;

  /// Optional keepalive timer.
  Timer? _pingTimer;

  /// How long to wait for a subscribe ACK (subscription id) before failing.
  final Duration ackTimeout;

  /// Optional periodic ping interval (set to null to disable).
  final Duration? pingInterval;

  SolanaWsService({this.ackTimeout = const Duration(seconds: 8), this.pingInterval});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Subscribe to account changes for [pubkey].
  ///
  /// Emits:
  /// - the `value` map (decoded from accountNotification)
  /// Drops:
  /// - null values (closed account)
  Stream<Map<String, dynamic>?> accountSubscribe(
    String pubkey, {
    String encoding = 'base64',
    String commitment = 'confirmed',
  }) {
    return _subscribe<Map<String, dynamic>?>(
      method: 'accountSubscribe',
      params: [
        pubkey,
        {'encoding': encoding, 'commitment': commitment},
      ],
      notificationMethod: 'accountNotification',
      extractor: (msg) => (msg['params']?['result']?['value'] as Map?)?.cast<String, dynamic>(),
      unsubscribeMethod: 'accountUnsubscribe',
      unsubscribeParams: (subId) => [subId],
      label: 'accountSubscribe($pubkey)',
    );
  }

  /// Subscribe to a signature status until it reaches [commitment] (usually finalized).
  ///
  /// Emits:
  /// - the result map from signatureNotification (err/slot/confirmationStatus)
  Stream<Map<String, dynamic>> signatureSubscribe(String signature, {String commitment = 'finalized'}) {
    return _subscribe<Map<String, dynamic>>(
      method: 'signatureSubscribe',
      params: [
        signature,
        {'commitment': commitment},
      ],
      notificationMethod: 'signatureNotification',
      extractor: (msg) => (msg['params']?['result'] as Map).cast<String, dynamic>(),
      unsubscribeMethod: 'signatureUnsubscribe',
      unsubscribeParams: (subId) => [subId],
      label: 'signatureSubscribe($signature)',
    ).where((m) => m != null).cast<Map<String, dynamic>>();
  }

  /// Subscribe to all program-owned accounts.
  ///
  /// Emits:
  /// {
  ///   "pubkey": "...",
  ///   "account": { "data": ..., "lamports": ..., "owner": ..., ... }
  /// }
  Stream<Map<String, dynamic>> programSubscribe(
    String programId, {
    String encoding = 'base64',
    String commitment = 'confirmed',
    List<Map<String, dynamic>>? filters,
  }) {
    return _subscribe<Map<String, dynamic>?>(
      method: 'programSubscribe',
      params: [
        programId,
        {'encoding': encoding, 'commitment': commitment, if (filters != null) 'filters': filters},
      ],
      notificationMethod: 'programNotification',
      extractor: (msg) => (msg['params']?['result']?['value'] as Map?)?.cast<String, dynamic>(),
      unsubscribeMethod: 'programUnsubscribe',
      unsubscribeParams: (subId) => [subId],
      label: 'programSubscribe($programId)',
    ).where((r) => r != null).cast<Map<String, dynamic>>();
  }

  /// Manually close everything.
  Future<void> dispose() async {
    _pingTimer?.cancel();
    _pingTimer = null;

    await _chanSub?.cancel();
    _chanSub = null;

    try {
      await _chan?.sink.close();
    } catch (_) {}

    _chan = null;

    await _incoming.close();
  }

  // ---------------------------------------------------------------------------
  // Core subscribe plumbing
  // ---------------------------------------------------------------------------

  /// Generic subscribe helper:
  /// 1) opens socket if needed
  /// 2) sends JSON-RPC subscribe request
  /// 3) waits for ACK => subId
  /// 4) routes notifications for that subId into the returned stream
  Stream<T?> _subscribe<T>({
    required String method,
    required List<dynamic> params,
    required String notificationMethod,
    required T? Function(Map<String, dynamic> message) extractor,
    required String unsubscribeMethod,
    required List<dynamic> Function(int subId) unsubscribeParams,
    required String label,
  }) {
    late final StreamController<T?> controller;

    StreamSubscription? notifSub;
    StreamSubscription? ackSub; // <-- NOT shadowed
    int? subId;

    controller = StreamController<T?>(
      onListen: () async {
        _ensureConnected();
        _activeSubs++;

        final requestId = _nextId++;
        final ack = Completer<int>();

        // ACK listener: listens for response matching requestId.
        // This is where we decode:
        // - error => fail fast
        // - result => subId
        ackSub = _incoming.stream.listen((msg) {
          if (msg['id'] != requestId) return;
          if (ack.isCompleted) return;

          // 1) JSON-RPC error => immediate failure (no timeout guessing)
          final errObj = msg['error'];
          if (errObj != null) {
            final parsed = WsRpcError.fromJson(errObj);
            icLogger.w('[SolanaWsService] ack error ($label): $parsed');
            ack.completeError(StateError('WS ack error for $label: $parsed'));
            return;
          }

          // 2) Missing result => fail immediately
          if (!msg.containsKey('result')) {
            icLogger.w('[SolanaWsService] ack missing result ($label): $msg');
            ack.completeError(StateError('WS ack missing result for $label'));
            return;
          }

          // 3) Normal success => subscription id
          final r = msg['result'];
          if (r is int) {
            ack.complete(r);
            return;
          }
          if (r is Map && r['subscription'] is int) {
            ack.complete(r['subscription'] as int);
            return;
          }

          // 4) Unexpected result shape => fail
          icLogger.w('[SolanaWsService] ack unexpected result ($label): $r');
          ack.completeError(StateError('WS ack unexpected result for $label: $r'));
        });

        // Send subscribe request AFTER ackSub is attached.
        final subscribePayload = {'jsonrpc': '2.0', 'id': requestId, 'method': method, 'params': params};

        try {
          _chan!.sink.add(jsonEncode(subscribePayload));
        } catch (e) {
          await ackSub?.cancel();
          ackSub = null;

          controller.addError(StateError('WS send failed for $label: $e'));
          await controller.close();
          _decrementAndMaybeClose();
          return;
        }

        // Wait for ACK or timeout.
        try {
          subId = await ack.future.timeout(ackTimeout);
        } catch (e) {
          await ackSub?.cancel();
          ackSub = null;

          // If we timed out waiting for ACK, force reset so the next subscribe reconnects.
          await _resetConnection('ack-timeout $label');

          controller.addError(StateError('WS subscribe ack timeout for $method ($label)'));
          await controller.close();
          _decrementAndMaybeClose();
          return;
        } finally {
          // ACK listener not needed after ACK resolved.
          await ackSub?.cancel();
          ackSub = null;
        }

        // Now route notifications for this subscription id.
        notifSub = _incoming.stream
            .where((msg) => msg['method'] == notificationMethod)
            .where((msg) => msg['params']?['subscription'] == subId)
            .listen(
              (msg) {
                try {
                  final out = extractor(msg);
                  if (out == null) return; // intentionally drop nulls
                  controller.add(out);
                } catch (e, st) {
                  // Never poison the whole stream because one message is bad
                  icLogger.w('[SolanaWsService] extractor error ($label/$notificationMethod): $e');
                  icLogger.d('$st');
                }
              },
              onError: controller.addError,
              onDone: () => controller.close(),
            );
      },

      // Called when the consumer cancels their subscription stream.
      onCancel: () async {
        await notifSub?.cancel();
        notifSub = null;

        await ackSub?.cancel();
        ackSub = null;

        // Unsubscribe only if we successfully got a subId.
        final sid = subId;
        if (sid != null) {
          final unId = _nextId++;
          final unsubscribePayload = {
            'jsonrpc': '2.0',
            'id': unId,
            'method': unsubscribeMethod,
            'params': unsubscribeParams(sid),
          };
          try {
            _chan?.sink.add(jsonEncode(unsubscribePayload));
          } catch (_) {
            // socket may already be closing
          }
        }

        _decrementAndMaybeClose();
      },
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Socket lifecycle
  // ---------------------------------------------------------------------------

  /// Ensure the WS connection is up.
  /// Reuses an existing socket as long as it’s still non-null.
  void _ensureConnected() {
    if (_chan != null) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.resumed) {
      icLogger.w('[SolanaWsService] skip connect: app not resumed (state=$lifecycle)');
      return;
    }

    final url = AppConstants.wsClientRawURL;
    icLogger.i('[SolanaWsService] connect url=${_redactApiKey(url)}');

    _chan = WebSocketChannel.connect(Uri.parse(url));

    _chanSub = _chan!.stream.listen(
      (data) {
        try {
          final text = switch (data) {
            final String s => s,
            final List<int> bytes => utf8.decode(bytes),
            _ => data.toString(),
          };

          final decoded = jsonDecode(text);
          if (decoded is! Map) return;

          _incoming.add(decoded.cast<String, dynamic>());
        } catch (_) {
          // ignore malformed frames
        }
      },
      onError: (e) async {
        icLogger.w('[SolanaWsService] socket error: $e');
        await _resetConnection(e);
      },
      onDone: () async {
        icLogger.w('[SolanaWsService] socket done');
        await _resetConnection('onDone');
      },
      cancelOnError: false,
    );

    _pingTimer?.cancel();
    if (pingInterval != null) {
      _pingTimer = Timer.periodic(pingInterval!, (_) {
        try {
          final id = _nextId++;
          _chan?.sink.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': 'getHealth'}));
        } catch (_) {}
      });
    }
  }

  /// Decrement active-sub counter and close the socket when it hits 0.
  void _decrementAndMaybeClose() async {
    _activeSubs = (_activeSubs - 1).clamp(0, 1 << 30);

    if (_activeSubs == 0) {
      _pingTimer?.cancel();
      _pingTimer = null;

      await _chanSub?.cancel();
      _chanSub = null;

      try {
        await _chan?.sink.close();
      } catch (_) {}

      _chan = null;
    }
  }

  /// Reset socket state (used on errors/timeouts).
  Future<void> _resetConnection([Object? reason]) async {
    icLogger.w('[SolanaWsService] resetConnection reason=$reason');

    _pingTimer?.cancel();
    _pingTimer = null;

    try {
      await _chanSub?.cancel();
    } catch (_) {}

    try {
      await _chan?.sink.close();
    } catch (_) {}

    _chanSub = null;
    _chan = null;
  }

  String _redactApiKey(String url) => url.replaceAll(RegExp(r'api-key=[^&]+'), 'api-key=REDACTED');
}
