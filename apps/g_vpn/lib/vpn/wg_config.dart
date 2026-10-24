/// A light reader for wg-quick style configs, used ONLY to validate an import
/// and show a summary before saving.
///
/// It is deliberately not the authority. The Kotlin side parses the same text
/// with WireGuard's own `Config.parse`, and that result is what actually brings
/// the tunnel up. Keeping two full parsers in sync is how they drift; this one
/// checks just enough to reject obvious mistakes early.
library;

/// What the UI shows for a saved tunnel.
class WgSummary {
  const WgSummary({
    required this.addresses,
    required this.endpoint,
    required this.dns,
    required this.peerCount,
  });

  final List<String> addresses;
  final String endpoint;
  final List<String> dns;
  final int peerCount;
}

/// Thrown with a message written for a person, not a developer.
class WgConfigException implements Exception {
  const WgConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Base64 of a 32-byte Curve25519 key is always 44 characters ending in '='.
final _keyPattern = RegExp(r'^[A-Za-z0-9+/]{43}=$');

WgSummary parseWgConfig(String text) {
  String? section;
  final iface = <String, String>{};
  final peers = <Map<String, String>>[];

  for (final raw in text.split('\n')) {
    // Strip comments, then whitespace. wg-quick accepts both '#' and ';'.
    final line = raw.split(RegExp('[#;]')).first.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      section = line.substring(1, line.length - 1).trim().toLowerCase();
      if (section == 'peer') peers.add({});
      continue;
    }

    final eq = line.indexOf('=');
    if (eq <= 0) throw WgConfigException('Unreadable line: $line');
    final key = line.substring(0, eq).trim().toLowerCase();
    final value = line.substring(eq + 1).trim();

    switch (section) {
      case 'interface':
        iface[key] = value;
      case 'peer':
        peers.last[key] = value;
      default:
        throw const WgConfigException('Settings must sit under [Interface] or [Peer].');
    }
  }

  final privateKey = iface['privatekey'];
  if (privateKey == null) {
    throw const WgConfigException('Missing PrivateKey in [Interface].');
  }
  if (!_keyPattern.hasMatch(privateKey)) {
    throw const WgConfigException('PrivateKey is not a valid WireGuard key.');
  }
  final address = iface['address'];
  if (address == null || address.isEmpty) {
    throw const WgConfigException('Missing Address in [Interface].');
  }
  if (peers.isEmpty) {
    throw const WgConfigException('The config needs at least one [Peer].');
  }

  for (final peer in peers) {
    final publicKey = peer['publickey'];
    if (publicKey == null || !_keyPattern.hasMatch(publicKey)) {
      throw const WgConfigException('A [Peer] has a missing or invalid PublicKey.');
    }
    if ((peer['allowedips'] ?? '').isEmpty) {
      throw const WgConfigException('A [Peer] is missing AllowedIPs.');
    }
  }

  final endpoint = peers.first['endpoint'];
  if (endpoint == null || !endpoint.contains(':')) {
    throw const WgConfigException('The first [Peer] needs an Endpoint like host:port.');
  }

  List<String> list(String? v) => (v ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  return WgSummary(
    addresses: list(address),
    endpoint: endpoint,
    dns: list(iface['dns']),
    peerCount: peers.length,
  );
}
