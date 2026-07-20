import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Deliberately boring. Swap the body for a real logger later; the call sites
/// never change.
class Log {
  const Log(this._tag);
  final String _tag;

  void d(String message) => _emit('DEBUG', message);
  void i(String message) => _emit('INFO', message);
  void w(String message) => _emit('WARN', message);
  void e(String message, [Object? error, StackTrace? stack]) {
    _emit('ERROR', message);
    if (error != null) developer.log('$error', name: _tag, stackTrace: stack);
  }

  void _emit(String level, String message) {
    if (kReleaseMode && level == 'DEBUG') return;
    developer.log('[$level] $message', name: _tag);
  }
}
