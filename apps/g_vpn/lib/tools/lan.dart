import 'dart:async';
import 'dart:io';

import 'discovery.dart';
import 'probe.dart';

/// A device on the local network.
class LanDevice {
  const LanDevice({
    required this.ip,
    required this.rttMs,
    this.name,
    this.model,
    this.kind = DeviceKind.unknown,
    this.isRouter = false,
    this.isSelf = false,
  });

  final String ip;
  final double rttMs;
  final String? name;
  final String? model;
  final DeviceKind kind;
  final bool isRouter;
  final bool isSelf;
}

/// The /24 a scan covers, from the router's address (or the phone's).
/// Home networks are /24 almost without exception.
String? subnetBase(String? gateway, List<String> addresses) {
  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
  for (final candidate in [if (gateway != null) gateway, ...addresses]) {
    final m = ipv4.firstMatch(candidate);
    if (m != null) return '${m[1]}.${m[2]}.${m[3]}';
  }
  return null;
}

/// Ports that nearly every kind of device either opens or REFUSES. A refusal
/// is a reply: it proves something is there. 62078 catches iPhones and
/// iPads; 8008 catches Chromecasts and TVs.
const _knockPorts = [80, 443, 62078, 8008, 445];

/// Knocks on every address in [base].1-254 while asking the network for
/// names (mDNS, UPnP), then fills remaining names from the router's DNS and
/// NetBIOS. Devices that only announce themselves are included too.
Future<List<LanDevice>> scanLan({
  required String base,
  String? gateway,
  String? selfIp,
  int parallel = 32,
  void Function(int done)? onProgress,
  bool Function()? cancelled,
}) async {
  final hintsFuture = discoverNames();
  final hosts = [for (var i = 1; i <= 254; i++) '$base.$i'];
  var done = 0;
  final knocked = await pooled(hosts, parallel, (ip) async {
    double? rtt;
    if (cancelled?.call() != true) {
      for (final port in _knockPorts) {
        rtt = await tcpPing(ip, port, timeout: const Duration(milliseconds: 500));
        if (rtt != null) break;
      }
    }
    onProgress?.call(++done);
    return rtt == null ? null : (ip, rtt);
  });
  final hints = await hintsFuture;

  final rtts = <String, double>{
    for (final k in knocked.whereType<(String, double)>()) k.$1: k.$2,
    for (final ip in hints.keys)
      if (ip.startsWith('$base.')) ip: 0,
    if (selfIp != null) selfIp: 0,
  };
  // Knock timings win over the 0 placeholders for announced devices.
  for (final k in knocked.whereType<(String, double)>()) {
    rtts[k.$1] = k.$2;
  }

  final devices = await pooled(rtts.keys.toList(), 16, (ip) async {
    final hint = hints[ip];
    var name = hint?.name;
    name ??= await _reverseName(ip);
    name ??= ip == selfIp ? null : await netbiosName(ip);
    final kind = ip == gateway
        ? DeviceKind.router
        : hint?.kind != null && hint!.kind != DeviceKind.unknown
            ? hint.kind
            : kindFromName('$name ${hint?.model ?? ''}');
    return LanDevice(
      ip: ip,
      rttMs: rtts[ip]!,
      name: name,
      model: hint?.model == null || hint!.model!.isEmpty ? null : hint.model,
      kind: ip == selfIp ? DeviceKind.phone : kind,
      isRouter: ip == gateway,
      isSelf: ip == selfIp,
    );
  });
  int last(String ip) => int.parse(ip.split('.').last);
  return devices..sort((a, b) => last(a.ip).compareTo(last(b.ip)));
}

/// The name the router's DNS keeps for an address, if any.
Future<String?> _reverseName(String ip) async {
  try {
    final host = await InternetAddress(ip).reverse().timeout(const Duration(milliseconds: 1500));
    if (host.host == ip) return null;
    // "galaxy-s22.lan" -> "galaxy-s22"
    return host.host.split('.').first;
  } on Object {
    return null;
  }
}
