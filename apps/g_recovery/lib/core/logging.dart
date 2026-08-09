import 'dart:developer' as developer;

/// Structured logging. Never print() anywhere in this app: print output is
/// unfilterable in logcat once a store build is on a user device.
enum GLogLevel { debug, info, warn, error }

class GLog {
  const GLog._();

  static void d(String message, {String scope = 'app'}) =>
      _emit(GLogLevel.debug, scope, message, null, null);

  static void i(String message, {String scope = 'app'}) =>
      _emit(GLogLevel.info, scope, message, null, null);

  static void w(String message, {String scope = 'app', Object? cause}) =>
      _emit(GLogLevel.warn, scope, message, cause, null);

  static void e(
    String message, {
    String scope = 'app',
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      _emit(GLogLevel.error, scope, message, cause, stackTrace);

  static void _emit(
    GLogLevel level,
    String scope,
    String message,
    Object? cause,
    StackTrace? stackTrace,
  ) {
    developer.log(
      message,
      name: 'g_recovery.$scope',
      level: _value(level),
      error: cause,
      stackTrace: stackTrace,
    );
  }

  static int _value(GLogLevel level) {
    switch (level) {
      case GLogLevel.debug:
        return 500;
      case GLogLevel.info:
        return 800;
      case GLogLevel.warn:
        return 900;
      case GLogLevel.error:
        return 1000;
    }
  }
}
