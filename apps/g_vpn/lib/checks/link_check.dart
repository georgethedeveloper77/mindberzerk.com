import 'dart:convert';

import 'package:http/http.dart' as http;

/// The gvpn-linkcheck Worker. Overridable per build like the others.
const _base = String.fromEnvironment(
  'LINKCHECK_URL',
  defaultValue: 'https://gvpn-linkcheck.mindberzerk.workers.dev',
);

enum LinkVerdict {
  /// On the malware and phishing block lists.
  danger,

  /// The address does not exist.
  missing,

  /// Not on the lists. Not a promise; a check.
  clear,
}

/// What the check found for one link.
class LinkResult {
  const LinkResult({required this.verdict, required this.finalUrl, required this.hops, this.threats = const []});

  final LinkVerdict verdict;

  /// Where the link really ends after redirects (short links unfolded).
  final String finalUrl;
  final int hops;

  /// Why it was flagged, as the Worker reports it.
  final List<String> threats;
}

/// Why a check could not answer.
class LinkCheckException implements Exception {
  const LinkCheckException(this.code);

  /// invalid, busy, unavailable or network.
  final String code;
}

/// A link as typed or pasted, made checkable: trimmed, with https:// added
/// when no scheme is given. Null when it cannot be a web address.
String? normaliseLink(String input) {
  var v = input.trim();
  if (v.isEmpty || v.length > 2048 || v.contains(' ')) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v)) v = 'https://$v';
  final uri = Uri.tryParse(v);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || !uri.host.contains('.')) return null;
  return uri.toString();
}

/// Asks the Worker, which unfolds redirects and looks every host up on
/// Cloudflare's security resolver. The link goes to the Worker only;
/// nothing is stored.
Future<LinkResult> checkLink(String link, {http.Client? client}) async {
  final url = normaliseLink(link);
  if (url == null) throw const LinkCheckException('invalid');
  final c = client ?? http.Client();
  try {
    final res = await c
        .post(Uri.parse('$_base/check'), headers: const {'content-type': 'application/json'}, body: jsonEncode({'url': url}))
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(res.body);
    if (res.statusCode == 429) throw const LinkCheckException('busy');
    if (res.statusCode != 200 || body is! Map) {
      throw LinkCheckException(body is Map && body['error'] is String ? body['error'] as String : 'unavailable');
    }
    return LinkResult(
      verdict: switch (body['verdict']) {
        'danger' => LinkVerdict.danger,
        'missing' => LinkVerdict.missing,
        _ => LinkVerdict.clear,
      },
      finalUrl: body['finalUrl'] is String ? body['finalUrl'] as String : url,
      hops: body['hops'] is int ? body['hops'] as int : 0,
      threats: [for (final t in (body['threats'] as List? ?? const [])) '$t'],
    );
  } on LinkCheckException {
    rethrow;
  } on Exception {
    throw const LinkCheckException('network');
  } finally {
    if (client == null) c.close();
  }
}
