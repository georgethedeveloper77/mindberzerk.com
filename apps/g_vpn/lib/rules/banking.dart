import '../vpn/vpn_api.g.dart';

/// Money apps that commonly refuse VPN addresses. Matched against package
/// names AND labels, because bank package names are unpredictable.
///
/// A suggestion, never applied silently: the user confirms the list, so a
/// false match costs one tap, not a broken app.
const _hints = [
  'bank', 'mpesa', 'm-pesa', 'safaricom', 'mshwari', 'fuliza', 'equity',
  'kcb', 'coop', 'co-op', 'ncba', 'absa', 'stanbic', 'stanchart',
  'standard chartered', 'dtbafrica', 'imbank', 'familybank', 'airtel money',
  'pesalink', 'sacco', 'paypal',
];

bool looksLikeMoneyApp(InstalledApp app) {
  final haystack = '${app.packageName} ${app.label}'.toLowerCase();
  return _hints.any(haystack.contains);
}
