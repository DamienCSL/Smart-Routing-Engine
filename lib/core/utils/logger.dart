import 'package:flutter/foundation.dart';

/// Lightweight debug logger — replace with a proper logger in production.
abstract final class AppLogger {
  static void info(String message) {
    if (kDebugMode) debugPrint('[IPOSB] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[IPOSB ERROR] $message');
      if (error != null) debugPrint('  → $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }
}
