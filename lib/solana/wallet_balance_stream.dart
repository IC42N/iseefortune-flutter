import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iseefortune_flutter/constants/app.dart';
import 'package:iseefortune_flutter/solana/fetch_lamports.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WalletBalanceStream
/// ---------------------------------------------------------------------------
/// Purpose:
/// - Provides a live stream of lamports for a given wallet pubkey.
/// - Uses WebSocket accountSubscribe for real-time updates.
/// - Falls back to HTTP polling when WebSocket is down.
/// - Auto-rotates through multiple RPC endpoints and reconnects with backoff.
///
/// Usage:
///   final stream = WalletBalanceStream();
///   final lamportsStream = stream.watch(pubkey);
///   ...
///   stream.stop();
class WalletBalanceStream {
  // ---------------------------------------------------------------------------
  // WebSocket / Subscription State
  // ---------------------------------------------------------------------------

  /// Active WebSocket channel to the RPC endpoint.
  WebSocketChannel? _channel;

  /// Ensures we only attach a single listener to the channel stream at a time.
  /// When the channel is recreated (reconnect), we reset this to false so we reattach.
  bool _hasListener = false;

  /// Used to distinguish "we closed it ourselves" vs. an unexpected disconnect.
  /// Prevents onDone from triggering reconnect logic when we intentionally closed.
  bool _intentionalClose = false;

  /// In-flight subscribe request id (JSON-RPC "id") for accountSubscribe.
  int? _pendingSubReqId;

  /// Broadcast controller for UI listeners (can have multiple subscribers).
  StreamController<int>? _balanceController;

  /// The subscription id returned from the RPC after successful accountSubscribe.
  /// This is needed to filter notifications and to unsubscribe cleanly.
  dynamic _subscriptionId;

  // ---------------------------------------------------------------------------
  // Reconnect + Backoff State
  // ---------------------------------------------------------------------------

  /// Timer used for scheduled reconnect attempts (exponential-ish backoff).
  Timer? _reconnectTimer;

  /// Count of consecutive reconnect attempts.
  int _reconnectAttempts = 0;

  /// Prevents scheduling multiple reconnect timers simultaneously.
  bool _isReconnecting = false;

  // ---------------------------------------------------------------------------
  // Watched Wallet State
  // ---------------------------------------------------------------------------

  /// The pubkey currently being watched.
  String? _currentPubkey;

  /// Most recently known lamports. Used to:
  /// - emit immediately onListen
  /// - avoid duplicate UI updates
  int? _lastLamports;

  // ---------------------------------------------------------------------------
  // HTTP Polling Fallback State
  // ---------------------------------------------------------------------------

  /// Timer for periodic HTTP polling when WebSocket is down.
  Timer? _pollTimer;

  /// Last subscribe request id (for matching responses).
  int? _lastSubReqId;

  /// Last unsubscribe request id (for matching responses).
  int? _lastUnsubReqId;

  /// The pubkey currently pending subscription (while request is in-flight).
  String? _pendingPubkey;

  /// The pubkey we believe we are subscribed to on the WS server.
  String? _subscribedPubkey;

  /// Tracks which pubkey our polling timer is polling.
  String? _pollingPubkey;

  // ---------------------------------------------------------------------------
  // RPC Rotation State
  // ---------------------------------------------------------------------------

  /// Current index into AppConstants.wsRpcUrls + AppConstants.httpRpcUrls
  /// We rotate this on failures.
  int _currentRpcIndex = 0;

  WalletBalanceStream();

  /// Defensive: uses the minimum length so we never index out of range if one list changes.
  int get _rpcLen {
    final a = AppConstants.wsRpcUrls.length;
    final b = AppConstants.httpRpcUrls.length;
    return (a < b) ? a : b;
  }

  /// Current websocket endpoint (based on rotation index).
  String get _wsUrl => AppConstants.wsRpcUrls[_currentRpcIndex % _rpcLen];

  /// Current HTTP endpoint (based on rotation index).
  String get _httpUrl => AppConstants.httpRpcUrls[_currentRpcIndex % _rpcLen];

  // ---------------------------------------------------------------------------
  // HTTP Helper: "fast fetch" used for initial paint and fallback
  // ---------------------------------------------------------------------------

  /// Quick HTTP fetch with a short timeout.
  /// Used for:
  /// - initial balance before WS subscription is fully established
  /// - polling while WS is disconnected
  Future<int?> _tryFetchBalanceHttp(String pubkey) async {
    try {
      final lamports = await fetchLamports(
        pubkey,
        url: _httpUrl,
      ).timeout(const Duration(seconds: 2)); // fast fail
      return lamports;
    } on TimeoutException {
      icLogger.w('[WS] Quick HTTP fetch timed out ($pubkey)');
      return null;
    } catch (e) {
      icLogger.w('[WS] Quick HTTP fetch failed ($pubkey): $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP Polling Fallback
  // ---------------------------------------------------------------------------

  /// Starts periodic HTTP polling for the currently watched pubkey.
  /// We only poll when the WS channel is down.
  void _startHttpPolling(String pubkey) {
    if (_pollingPubkey == pubkey) return;

    _pollingPubkey = pubkey;
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      // If websocket is down, keep the UI alive via HTTP
      if (_channel == null && _pollingPubkey == pubkey) {
        final lamports = await _tryFetchBalanceHttp(pubkey);
        if (lamports != null && lamports != _lastLamports) {
          _lastLamports = lamports;
          _balanceController?.add(lamports);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts watching a pubkey and returns a broadcast stream of lamports.
  ///
  /// Behavior:
  /// - If pubkey changes, we unsubscribe from the previous one and reset state.
  /// - onListen: immediately pushes last known lamports if available.
  /// - Otherwise: does a quick HTTP fetch while WS subscription is being established.
  Stream<int> watch(String pubkey) {
    icLogger.i('[WalletBalanceStream] WATCH $pubkey');

    // "reuse" means: we already have a live controller + active subscription on the same pubkey
    final reuse =
        _balanceController != null &&
        !_balanceController!.isClosed &&
        _currentPubkey == pubkey &&
        _channel != null &&
        _subscriptionId != null;

    final isSamePubkey = _currentPubkey == pubkey;
    final prevSubId = _subscriptionId;
    _currentPubkey = pubkey;

    // If switching pubkeys, unsubscribe and clear subscription state
    if (!isSamePubkey) {
      _lastLamports = null;

      if (prevSubId != null) _sendUnsubscribe(prevSubId);

      // Clear all WS tracking state so we don't mistakenly treat old sub as active
      _subscriptionId = null;
      _subscribedPubkey = null;
      _pendingSubReqId = null;
      _pendingPubkey = null;
      _lastSubReqId = null;
      _lastUnsubReqId = null;

      // Close previous stream controller
      _balanceController?.close();
      _balanceController = null;
    }

    // If not reusing, create a new controller and subscribe
    if (!reuse) {
      _balanceController?.close();
      _balanceController = StreamController<int>.broadcast(
        onListen: () async {
          // If we have a cached last value, emit immediately
          if (_lastLamports != null) {
            _balanceController?.add(_lastLamports!);
            return;
          }

          // Otherwise do a quick HTTP fetch for first paint
          final httpBal = await _tryFetchBalanceHttp(pubkey);
          if (httpBal != null) {
            _lastLamports = httpBal;
            _balanceController?.add(httpBal);
          }
        },
      );

      // Begin WS subscription (async response)
      _sendSubscribe(pubkey);
    } else {
      // We are "reusing" — ensure UI sees current value
      if (_lastLamports == null) {
        _refreshOnce(pubkey);
      } else {
        scheduleMicrotask(() => _balanceController?.add(_lastLamports!));
      }
    }

    // Always keep polling armed as a fallback
    _startHttpPolling(pubkey);

    return _balanceController!.stream;
  }

  /// One-off HTTP refresh (used after subscribe completes, and when reusing).
  Future<void> _refreshOnce(String pubkey) async {
    try {
      final lamports = await fetchLamports(pubkey, url: _httpUrl);
      if (lamports != _lastLamports) {
        _lastLamports = lamports;
        _balanceController?.add(lamports);
      }
    } catch (e) {
      icLogger.e('[WS] refreshOnce failed: $e');
      _stopPolling();
    }
  }

  // ---------------------------------------------------------------------------
  // WebSocket Subscribe / Unsubscribe
  // ---------------------------------------------------------------------------

  /// Sends an accountSubscribe request to the RPC WS server.
  void _sendSubscribe(String pubkey) {
    _ensureChannelConnected();

    // If already subscribed to this pubkey, just emit cached value and return
    if (_subscriptionId != null && _subscribedPubkey == pubkey) {
      icLogger.i('[WS] Already subscribed to $pubkey');
      if (_lastLamports != null) {
        scheduleMicrotask(() => _balanceController?.add(_lastLamports!));
      }
      return;
    }

    // Prevent duplicate subscribe requests while one is still in-flight for same pubkey
    if (_pendingSubReqId != null && _pendingPubkey == pubkey) {
      icLogger.i('[WS] Subscribe already pending for $pubkey (reqId=$_pendingSubReqId)');
      return;
    }

    final reqId = DateTime.now().millisecondsSinceEpoch;
    _lastSubReqId = reqId;
    _pendingSubReqId = reqId;
    _pendingPubkey = pubkey;

    final subRequest = jsonEncode({
      "jsonrpc": "2.0",
      "id": reqId,
      "method": "accountSubscribe",
      "params": [
        pubkey,
        {"encoding": "jsonParsed", "commitment": "confirmed"},
      ],
    });

    icLogger.i('[WS] Subscribing to $pubkey (id=$reqId, ws=$_wsUrl)');
    _channel!.sink.add(subRequest);
  }

  /// Ensures we have a connected WebSocket channel and a listener attached.
  void _ensureChannelConnected() {
    if (_channel != null) return;

    final url = _wsUrl;
    icLogger.w('[WS] Connecting to $url');

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(url), pingInterval: const Duration(seconds: 20));
    } catch (e) {
      icLogger.e('[WS] Immediate connect failed for $url: $e');

      // If it's a network/DNS type error, rotate endpoints and retry
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        _rotateRpc();
        _scheduleReconnect();
        return;
      }

      _scheduleReconnect();
      return;
    }

    // New channel => reset subscription id (we must resubscribe)
    _subscriptionId = null;

    // Attach stream listener once per channel
    if (!_hasListener) {
      _hasListener = true;

      _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message);
            if (decoded is! Map) return;

            // Responses to our requests have an "id"
            final respId = decoded['id'];
            if (respId != null) {
              // Subscribe response
              if (respId == _lastSubReqId || respId == _pendingSubReqId) {
                final result = decoded['result'];
                if (result is int) {
                  _subscriptionId = result;
                  _subscribedPubkey = _pendingPubkey;

                  icLogger.i('[WS] Subscribed id=$_subscriptionId to $_subscribedPubkey');

                  // Clear pending markers
                  final k = _subscribedPubkey;
                  _pendingPubkey = null;
                  _pendingSubReqId = null;
                  _lastSubReqId = null;

                  // Successful subscribe => reset reconnect backoff
                  _reconnectAttempts = 0;

                  // Immediately refresh once via HTTP so UI is correct
                  if (k != null) _refreshOnce(k);
                }
                return;
              }

              // Unsubscribe response
              if (respId == _lastUnsubReqId) {
                _subscriptionId = null;
                _subscribedPubkey = null;
                _lastUnsubReqId = null;
                return;
              }

              return;
            }

            // Notifications come via "method": "accountNotification"
            final method = decoded['method'] as String?;
            if (method == 'accountNotification') {
              final params = decoded['params'] as Map?;
              final subNum = params?['subscription'];

              // Ignore notifications from older subscriptions
              if (_subscriptionId != null && subNum != _subscriptionId) return;

              final value = (params?['result'] as Map?)?['value'] as Map?;
              final lamports = (value?['lamports'] as int?) ?? 0;

              if (lamports != _lastLamports) {
                _lastLamports = lamports;
                _balanceController?.add(lamports);
              }
            }
          } catch (e, st) {
            icLogger.w('[WS] parse error: $e\n$st');
          }
        },
        onError: (e, st) {
          // WS error => rotate and reconnect
          icLogger.e('[WS] Error: $e');
          _pendingSubReqId = null;
          _pendingPubkey = null;
          _rotateRpc();
          _scheduleReconnect();
        },
        onDone: () {
          // WS closed => reconnect unless it was intentional
          icLogger.w('[WS] Closed (url=$url)');
          if (_intentionalClose) {
            _intentionalClose = false;
            return;
          }
          _rotateRpc();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    }
  }

  /// Rotates to the next pair of RPC endpoints (WS + HTTP).
  void _rotateRpc() {
    final len = _rpcLen;
    if (len == 0) return;
    _currentRpcIndex = (_currentRpcIndex + 1) % len;
    icLogger.w('[WS] Rotated RPC -> ws=$_wsUrl http=$_httpUrl');
  }

  /// Sends an unsubscribe request for the current subscription id.
  void _sendUnsubscribe(dynamic subId) {
    if (_channel == null || subId == null) return;

    final reqId = DateTime.now().millisecondsSinceEpoch;
    _lastUnsubReqId = reqId;

    final unsub = jsonEncode({
      "jsonrpc": "2.0",
      "id": reqId,
      "method": "accountUnsubscribe",
      "params": [subId],
    });

    icLogger.i('[WS] Unsubscribing (subId=$subId, id=$reqId)');
    _channel!.sink.add(unsub);
  }

  // ---------------------------------------------------------------------------
  // Reconnect Scheduling
  // ---------------------------------------------------------------------------

  /// Schedules a reconnect attempt with a simple backoff.
  /// Also rotates endpoints on repeated failures.
  void _scheduleReconnect() {
    if (_isReconnecting || _currentPubkey == null) return;

    _isReconnecting = true;
    _reconnectTimer?.cancel();

    // Backoff: 2s, 4s, 6s, 8s, 10s (clamped)
    final attempt = (++_reconnectAttempts).clamp(1, 5);
    final delay = Duration(seconds: 2 * attempt);

    icLogger.w('[WS] Reconnecting in ${delay.inSeconds}s...');

    _reconnectTimer = Timer(delay, () {
      // On repeated failures, rotate again
      if (_reconnectAttempts > 1) _rotateRpc();

      _isReconnecting = false;

      // We are intentionally closing the channel to recreate it
      _intentionalClose = true;

      try {
        _channel?.sink.close();
      } catch (_) {}

      // Reset channel + listener + in-flight request state
      _channel = null;
      _hasListener = false;
      _subscriptionId = null;
      _pendingSubReqId = null;
      _pendingPubkey = null;

      // Reconnect and resubscribe to the current pubkey
      final pk = _currentPubkey;
      if (pk != null) {
        _ensureChannelConnected();
        _sendSubscribe(pk);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Manual Refresh + Stop
  // ---------------------------------------------------------------------------

  /// Manual HTTP refresh for current endpoint.
  Future<void> refresh(String pubkey) async {
    try {
      final latest = await fetchLamports(pubkey, url: _httpUrl);
      if (latest != _lastLamports) {
        _lastLamports = latest;
        _balanceController?.add(latest);
      }
    } catch (e) {
      icLogger.w('[WS] refresh failed: $e');
    }
  }

  /// Stops everything:
  /// - cancels reconnect + polling
  /// - unsubscribes if possible
  /// - closes channel + controller
  void stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _isReconnecting = false;
    _reconnectAttempts = 0;

    _currentPubkey = null;
    _lastLamports = null;

    _stopPolling();

    if (_subscriptionId != null) {
      _sendUnsubscribe(_subscriptionId);
    }

    _intentionalClose = true;
    _channel?.sink.close();
    _channel = null;
    _hasListener = false;

    _balanceController?.close();
    _balanceController = null;

    _subscriptionId = null;
  }

  /// Stops HTTP polling fallback.
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
