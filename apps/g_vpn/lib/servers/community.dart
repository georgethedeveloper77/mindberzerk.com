import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vpn/community_server.dart';

/// The gvpn-servers Worker. Overridable per build like WHOAMI_URL.
const _base = String.fromEnvironment(
  'COMMUNITY_URL',
  defaultValue: 'https://gvpn-servers.mindberzerk.workers.dev',
);

class CommunityList {
  const CommunityList({required this.notice, required this.updatedAt, required this.servers});

  /// Who runs these servers and what they keep, shown above the list.
  final String notice;
  final DateTime? updatedAt;
  final List<CommunityServer> servers;
}

final communityProvider = FutureProvider<CommunityList>((ref) async {
  final body = await _get('/community');
  final json = jsonDecode(body);
  if (json is! Map) throw const FormatException('Unexpected server list');
  final raw = json['servers'];
  return CommunityList(
    notice: json['notice'] is String ? json['notice'] as String : '',
    updatedAt: DateTime.tryParse('${json['updatedAt']}'),
    servers: raw is List ? raw.map(CommunityServer.fromJson).whereType<CommunityServer>().toList() : const [],
  );
});

/// The server's .ovpn text, fetched at connect so a stale list never holds
/// a stale config.
Future<String> fetchCommunityConfig(String id) => _get('/community/$id.ovpn');

Future<String> _get(String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(Uri.parse('$_base$path'));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse('$_base$path'));
    }
    return body;
  } finally {
    client.close(force: true);
  }
}
