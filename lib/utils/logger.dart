import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final icLogger = Logger(
  printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: true),
  level: kReleaseMode ? Level.off : Level.debug,
);
