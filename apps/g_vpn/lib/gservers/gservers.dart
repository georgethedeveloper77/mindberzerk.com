import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../vpn/secrets.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_api.g.dart';

/// The G Servers broker (a Cloudflare Worker). It hands this phone's PUBLIC
/// key to the chosen server and returns the server's half of the config.
const _base = String.fromEnvironment('GSERVERS_URL', defaultValue: 'https://gvpn-gservers.mindberzerk.workers.dev');

class GServer {
  const GServer({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.online,
    this.busy,
    this.history = const [],
    this.host,
    this.pingPort,
  });

  final String id;
  final String name;
  final String city;
  final String country;
  final bool online;

  /// 0 to 100, from the server's load; null when it cannot be read.
  final int? busy;

  /// Busy every 15 minutes for the last 24 hours, oldest first.
  final List<int> history;

  /// Where the phone times a connection to show ping.
  final String? host;
  final int? pingPort;

  factory GServer.fromJson(Map<String, dynamic> j) => GServer(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        city: j['city'] as String? ?? '',
        country: j['country'] as String? ?? '',
        online: j['online'] == true,
        busy: (j['busy'] as num?)?.toInt(),
        history: [for (final v in (j['history'] as List? ?? const [])) (v as num).toInt()],
        host: j['host'] as String?,
        pingPort: (j['pingPort'] as num?)?.toInt(),
      );
}

class GServersInfo {
  const GServersInfo({required this.enabled, required this.proOnly, required this.limit, required this.servers, this.idleDays = 30});

  final bool enabled;
  final bool proOnly;
  final int limit;
  final List<GServer> servers;

  /// Days an unused phone keeps its place before it is removed.
  final int idleDays;

  /// What the Pro tab shows: servers when switched on and any are listed.
  bool get available => enabled && servers.isNotEmpty;

  /// The least busy server that is up.
  GServer? get best {
    final up = servers.where((s) => s.online).toList()..sort((a, b) => (a.busy ?? 100).compareTo(b.busy ?? 100));
    return up.firstOrNull;
  }

  static const none = GServersInfo(enabled: false, proOnly: false, limit: 5, servers: []);
}

final gServersProvider = FutureProvider<GServersInfo>((ref) async {
  try {
    final res = await http.get(Uri.parse('$_base/servers')).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return GServersInfo.none;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return GServersInfo(
      enabled: j['enabled'] == true,
      proOnly: j['access'] == 'pro',
      limit: (j['limit'] as num?)?.toInt() ?? 5,
      idleDays: (j['idleDays'] as num?)?.toInt() ?? 30,
      servers: [for (final s in (j['servers'] as List? ?? const [])) GServer.fromJson(s as Map<String, dynamic>)],
    );
  } on Exception {
    return GServersInfo.none;
  }
});

/// Why registering failed, in terms the screens can act on.
class GServerException implements Exception {
  const GServerException(this.code, {this.devices = const [], this.limit});

  /// limit, full, busy, pro_required, off, network
  final String code;
  final List<GDevice> devices;
  final int? limit;
}

class GDevice {
  const GDevice({required this.key, required this.name, required this.server, required this.lastSeen, required this.you});

  final String key;
  final String? name;
  final String server;
  final DateTime lastSeen;
  final bool you;

  factory GDevice.fromJson(Map<String, dynamic> j) => GDevice(
        key: j['key'] as String,
        name: j['name'] as String?,
        server: j['server'] as String? ?? '',
        lastSeen: DateTime.fromMillisecondsSinceEpoch((j['lastSeen'] as num?)?.toInt() ?? 0),
        you: j['you'] == true,
      );
}

/// This phone's G Servers identity: its key pair (made here; only the public
/// half is ever sent) and the broker's device token. Stored encrypted with
/// the phone's Keystore key, like the user's own server configs.
class _Identity {
  static const _key = 'gvpn.gidentity.v1';

  static Future<({String privateKey, String publicKey, String? token})> load(VpnHostApi api) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await Secrets.read(prefs, _key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (privateKey: j['private'] as String, publicKey: j['public'] as String, token: j['token'] as String?);
    }
    final pair = await api.generateWgKeyPair();
    await Secrets.write(prefs, _key, jsonEncode({'private': pair.privateKey, 'public': pair.publicKey}));
    return (privateKey: pair.privateKey, publicKey: pair.publicKey, token: null);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final j = jsonDecode((await Secrets.read(prefs, _key))!) as Map<String, dynamic>;
    j['token'] = token;
    await Secrets.write(prefs, _key, jsonEncode(j));
  }

  static Future<String?> token() async {
    final raw = await Secrets.read(await SharedPreferences.getInstance(), _key);
    return raw == null ? null : (jsonDecode(raw) as Map<String, dynamic>)['token'] as String?;
  }
}

/// Adds this phone to [server] (or confirms it is still there) and returns
/// the WireGuard config to connect with.
Future<SavedTunnel> registerGServer(VpnHostApi api, GServer server, {String? purchaseToken}) async {
  final id = await _Identity.load(api);
  final http.Response res;
  try {
    res = await http
        .post(
          Uri.parse('$_base/devices'),
          headers: {
            'content-type': 'application/json',
            if (id.token != null) 'authorization': 'Bearer ${id.token}',
          },
          body: jsonEncode({
            'publicKey': id.publicKey,
            'serverId': server.id,
            'name': await api.deviceName(),
            'purchaseToken': purchaseToken,
          }),
        )
        .timeout(const Duration(seconds: 20));
  } on Exception {
    throw const GServerException('network');
  }
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 429) throw const GServerException('busy');
  if (res.statusCode == 409 && j['error'] == 'server_full') throw const GServerException('full');
  if (res.statusCode == 409) {
    throw GServerException(
      'limit',
      limit: (j['limit'] as num?)?.toInt(),
      devices: [for (final d in (j['devices'] as List? ?? const [])) GDevice.fromJson(d as Map<String, dynamic>)],
    );
  }
  if (res.statusCode == 402) throw const GServerException('pro_required');
  if (res.statusCode == 403) throw const GServerException('off');
  if (res.statusCode != 200) throw const GServerException('network');

  await _Identity.saveToken(j['token'] as String);
  final config = [
    '[Interface]',
    '# Name = ${server.name}',
    'PrivateKey = ${id.privateKey}',
    'Address = ${j['address']}',
    'DNS = ${j['dns']}',
    '',
    '[Peer]',
    'PublicKey = ${j['serverPublicKey']}',
    'AllowedIPs = ${j['allowedIps']}',
    'Endpoint = ${j['endpoint']}',
    'PersistentKeepalive = 25',
    '',
  ].join('\n');
  return SavedTunnel(id: '$gserverPrefix${server.id}', name: server.city.isEmpty ? server.name : server.city, configText: config);
}

/// The phones in this phone's group (one plan), newest first.
final gDevicesProvider = FutureProvider<({int limit, List<GDevice> devices})?>((ref) async {
  final token = await _Identity.token();
  if (token == null) return null;
  try {
    final res = await http
        .get(Uri.parse('$_base/devices'), headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      limit: (j['limit'] as num?)?.toInt() ?? 5,
      devices: [for (final d in (j['devices'] as List)) GDevice.fromJson(d as Map<String, dynamic>)],
    );
  } on Exception {
    return null;
  }
});

/// Removes a phone from G Servers. Its key stops working at once.
Future<bool> removeGDevice(String key) async {
  final token = await _Identity.token();
  if (token == null) return false;
  final path = key.replaceAll('+', '-').replaceAll('/', '_');
  try {
    final res = await http
        .delete(Uri.parse('$_base/devices/${Uri.encodeComponent(path)}'), headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    return res.statusCode == 200;
  } on Exception {
    return false;
  }
}

/// Round trip from this phone to a G Server, in ms: the quickest of three
/// TCP connections (Android apps cannot send classic pings). Null when the
/// server does not answer.
final gPingProvider = FutureProvider.autoDispose.family<int?, String>((ref, id) async {
  final info = await ref.watch(gServersProvider.future);
  final server = info.servers.where((s) => s.id == id).firstOrNull;
  if (server?.host == null || server?.pingPort == null) return null;
  int? best;
  for (var i = 0; i < 3; i++) {
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(server!.host!, server.pingPort!, timeout: const Duration(seconds: 3));
      watch.stop();
      socket.destroy();
      final ms = watch.elapsedMilliseconds;
      if (best == null || ms < best) best = ms;
    } on Exception {
      // A lost probe; the others decide.
    }
  }
  return best;
});
