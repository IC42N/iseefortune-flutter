String lamportsToSolText(BigInt lamports) {
  final scale = BigInt.from(1000000000);
  final whole = lamports ~/ scale;
  final frac = (lamports % scale).toInt().abs();
  final fracStr = frac.toString().padLeft(9, '0').replaceFirst(RegExp(r'0+$'), '');
  return fracStr.isEmpty ? '$whole' : '$whole.$fracStr';
}


// maybe not needed.
String formatSol(double value, {int maxDecimals = 5}) {
  if (value == 0) return '0';

  if (value >= 1) {
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String formatted = value.toStringAsFixed(maxDecimals);

  // Remove trailing zeros and the decimal point if not needed
  formatted = formatted.replaceAll(RegExp(r'0+$'), '');
  formatted = formatted.replaceAll(RegExp(r'\.$'), '');

  return formatted;
}

String lamportsToSolTrim(BigInt lamports) {
  if (lamports == BigInt.zero) return '0';

  const sol = 1000000000;
  final whole = lamports ~/ BigInt.from(sol);
  final rem = lamports % BigInt.from(sol);

  if (rem == BigInt.zero) return whole.toString();

  final v = lamports.toDouble() / sol;
  return _trimZeros(v.toStringAsFixed(3));
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}
