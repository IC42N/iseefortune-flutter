class WsRpcError {
  WsRpcError({required this.code, required this.message, this.data});

  final int? code;
  final String message;
  final Object? data;

  factory WsRpcError.fromJson(Object? v) {
    if (v is Map) {
      return WsRpcError(
        code: v['code'] is int ? v['code'] as int : int.tryParse('${v['code']}'),
        message: v['message']?.toString() ?? 'Unknown WS RPC error',
        data: v['data'],
      );
    }
    return WsRpcError(code: null, message: v?.toString() ?? 'Unknown WS RPC error', data: null);
  }

  @override
  String toString() => 'WsRpcError(code=$code, message=$message, data=$data)';
}
