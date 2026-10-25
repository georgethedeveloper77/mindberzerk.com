import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

/// The few events G VPN logs, for the admin's analytics (BigQuery export).
///
/// How the app is used, never what anyone does online: which kind of server
/// and protocol a connection used, the server's country, why a connection
/// failed, which tool was opened. No addresses, no sites, no traffic.
/// Logging never blocks or fails the app.
abstract final class Events {
  static void connected({required String kind, required String protocol, String? serverCountry}) => _log('vpn_connect', {
        'kind': kind,
        'protocol': protocol,
        if (serverCountry != null && serverCountry.isNotEmpty) 'server_country': serverCountry,
      });

  static void connectFailed({required String kind, required String protocol, required String code}) =>
      _log('vpn_connect_failed', {'kind': kind, 'protocol': protocol, 'code': code});

  static void tool(String name) => _log('tool_open', {'tool': name});

  static void _log(String name, Map<String, Object> parameters) {
    unawaited(
      FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters).catchError((Object _) {}),
    );
  }
}
