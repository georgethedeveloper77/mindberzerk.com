import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What websites see when this device connects: the "Am I protected?" answer.
class PublicIdentity {
  const PublicIdentity({
    required this.ip,
    this.country,
    this.city,
    this.asn,
    this.org,
    this.colo,
    this.latitude,
    this.longitude,
  });

  final String ip;
  final String? country;
  final String? city;
  final int? asn;

  /// The provider name sites see, for example the user's ISP or a VPN host.
  final String? org;

  /// Cloudflare data centre that answered; a rough "where am I routed" hint.
  final String? colo;

  /// City-level position for the globe pin. Null on the trace fallback.
  final double? latitude;
  final double? longitude;
}

class IdentityException implements Exception {
  const IdentityException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Looks up the public identity.
///
/// With [endpoint] set it calls the Mindberzerk whoami Worker, which returns
/// provider and city from Cloudflare's own request metadata. Without it, it
/// falls back to Cloudflare's public trace page, which gives IP and country
/// but no provider name. Either way no third-party tracker is involved.
Future<PublicIdentity> fetchPublicIdentity({
  Uri? endpoint,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    if (endpoint != null) {
      final body = await _get(client, endpoint, timeout);
      final json = jsonDecode(body);
      if (json is! Map || json['ip'] is! String) {
        throw const IdentityException('The lookup service sent an unexpected reply.');
      }
      return PublicIdentity(
        ip: json['ip'] as String,
        country: json['country'] as String?,
        city: json['city'] as String?,
        asn: (json['asn'] as num?)?.toInt(),
        org: json['org'] as String?,
        colo: json['colo'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
    }

    final body = await _get(client, Uri.parse('https://1.1.1.1/cdn-cgi/trace'), timeout);
    final fields = <String, String>{
      for (final line in const LineSplitter().convert(body))
        if (line.contains('=')) line.substring(0, line.indexOf('=')): line.substring(line.indexOf('=') + 1),
    };
    final ip = fields['ip'];
    if (ip == null) throw const IdentityException('The lookup service sent an unexpected reply.');
    return PublicIdentity(ip: ip, country: fields['loc'], colo: fields['colo']);
  } on SocketException {
    throw const IdentityException('No internet connection.');
  } on TimeoutException {
    throw const IdentityException('The lookup timed out.');
  } finally {
    client.close(force: true);
  }
}

Future<String> _get(HttpClient client, Uri uri, Duration timeout) async {
  final request = await client.getUrl(uri).timeout(timeout);
  request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  final response = await request.close().timeout(timeout);
  final body = await response.transform(utf8.decoder).join().timeout(timeout);
  if (response.statusCode != 200) {
    throw IdentityException('Lookup failed (HTTP ${response.statusCode}).');
  }
  return body;
}
