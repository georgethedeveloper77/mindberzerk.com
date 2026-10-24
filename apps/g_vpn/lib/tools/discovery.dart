import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// What a device turned out to be, for its icon.
enum DeviceKind { phone, computer, tv, speaker, printer, camera, smartHome, router, unknown }

/// What a device said about itself, from one of the discovery protocols.
class DeviceHint {
  const DeviceHint({this.name, this.model, this.kind = DeviceKind.unknown});

  final String? name;

  /// Maker and model, when the device publishes them.
  final String? model;
  final DeviceKind kind;

  /// Keeps the more specific of two hints, field by field.
  DeviceHint merge(DeviceHint other) => DeviceHint(
        name: name ?? other.name,
        model: model ?? other.model,
        kind: kind != DeviceKind.unknown ? kind : other.kind,
      );
}

/// Asks the network who is there, by name, over three protocols at once.
/// All replies come back unicast to our own socket, so no multicast lock or
/// extra permission is needed. Returns hints keyed by IPv4 address.
Future<Map<String, DeviceHint>> discoverNames({Duration window = const Duration(seconds: 3)}) async {
  final results = await Future.wait([
    _mdns(window).catchError((Object _) => <String, DeviceHint>{}),
    _ssdp(window).catchError((Object _) => <String, DeviceHint>{}),
  ]);
  final merged = <String, DeviceHint>{};
  for (final map in results) {
    map.forEach((ip, hint) => merged[ip] = merged[ip]?.merge(hint) ?? hint);
  }
  return merged;
}

/// NetBIOS name of a Windows PC (or Samba share), if it answers.
Future<String?> netbiosName(String ip) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final reply = Completer<Datagram?>();
    final sub = socket.listen((e) {
      if (e == RawSocketEvent.read && !reply.isCompleted) reply.complete(socket!.receive());
    });
    // NBSTAT query for the wildcard name "*".
    final q = BytesBuilder()
      ..add([0x47, 0x56, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20])
      ..add(ascii.encode('CK${'A' * 30}'))
      ..add([0x00, 0x00, 0x21, 0x00, 0x01]);
    socket.send(q.toBytes(), InternetAddress(ip), 137);
    final d = await reply.future.timeout(const Duration(milliseconds: 700), onTimeout: () => null);
    await sub.cancel();
    if (d == null || d.data.length < 57) return null;
    final data = d.data;
    final count = data[56];
    for (var i = 0; i < count; i++) {
      final off = 57 + i * 18;
      if (off + 18 > data.length) break;
      final suffix = data[off + 15];
      final group = data[off + 16] & 0x80 != 0;
      if (suffix == 0x00 && !group) return ascii.decode(data.sublist(off, off + 15), allowInvalid: true).trim();
    }
    return null;
  } on Object {
    return null;
  } finally {
    socket?.close();
  }
}

// ── mDNS ──────────────────────────────────────────────────────────────────

/// Service types worth asking about, and what each says about a device.
const _serviceKinds = {
  '_googlecast._tcp.local': DeviceKind.tv,
  '_androidtvremote2._tcp.local': DeviceKind.tv,
  '_airplay._tcp.local': DeviceKind.tv,
  '_raop._tcp.local': DeviceKind.speaker,
  '_spotify-connect._tcp.local': DeviceKind.speaker,
  '_sonos._tcp.local': DeviceKind.speaker,
  '_ipp._tcp.local': DeviceKind.printer,
  '_ipps._tcp.local': DeviceKind.printer,
  '_printer._tcp.local': DeviceKind.printer,
  '_hap._tcp.local': DeviceKind.smartHome,
  '_matter._tcp.local': DeviceKind.smartHome,
  '_companion-link._tcp.local': DeviceKind.phone,
  '_smb._tcp.local': DeviceKind.computer,
  '_device-info._tcp.local': DeviceKind.computer,
  '_workstation._tcp.local': DeviceKind.computer,
  '_rtsp._tcp.local': DeviceKind.camera,
  '_http._tcp.local': DeviceKind.unknown,
};

Future<Map<String, DeviceHint>> _mdns(Duration window) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final out = <String, DeviceHint>{};
  final hostIps = <String, String>{}; // host.local -> ip
  final instances = <String, (String host, DeviceKind kind)>{}; // instance -> target host

  final sub = socket.listen((e) {
    if (e != RawSocketEvent.read) return;
    final d = socket.receive();
    if (d == null) return;
    final records = _parseDns(d.data);
    if (records == null) return;
    final ip = d.address.address;
    for (final r in records) {
      switch (r.type) {
        case 1: // A
          if (r.ipv4 != null) hostIps[r.name.toLowerCase()] = r.ipv4!;
        case 33: // SRV: instance -> host
          final kind = _kindForInstance(r.name);
          if (r.target != null) instances[r.name] = (r.target!.toLowerCase(), kind);
        case 12: // PTR: service -> instance
          if (r.target != null && !r.name.startsWith('_services')) {
            final kind = _serviceKinds[r.name.toLowerCase()] ?? DeviceKind.unknown;
            // The reply's source address is the device itself.
            final hint = DeviceHint(name: _instanceLabel(r.target!), kind: kind);
            out[ip] = out[ip]?.merge(hint) ?? hint;
          }
        case 16: // TXT: model ("md=Chromecast", "model=...")
          final model = r.txt['md'] ?? r.txt['model'] ?? r.txt['ty'] ?? r.txt['fn'];
          if (model != null && model.isNotEmpty) {
            final hint = DeviceHint(model: model);
            out[ip] = out[ip]?.merge(hint) ?? hint;
          }
      }
    }
  });

  final target = InternetAddress('224.0.0.251');
  for (final service in _serviceKinds.keys) {
    socket.send(_dnsQuery(service, 12), target, 5353);
  }
  await Future<void>.delayed(window);
  await sub.cancel();
  socket.close();

  // Instances whose SRV named a host we also got an address for.
  instances.forEach((instance, v) {
    final ip = hostIps[v.$1];
    if (ip == null) return;
    final hint = DeviceHint(name: _instanceLabel(instance), kind: v.$2);
    out[ip] = out[ip]?.merge(hint) ?? hint;
  });
  return out;
}

DeviceKind _kindForInstance(String instance) {
  final lower = instance.toLowerCase();
  for (final e in _serviceKinds.entries) {
    if (lower.endsWith(e.key)) return e.value;
  }
  return DeviceKind.unknown;
}

/// "Living Room TV._googlecast._tcp.local" -> "Living Room TV".
String _instanceLabel(String instance) {
  final cut = instance.indexOf('._');
  final label = cut > 0 ? instance.substring(0, cut) : instance.replaceAll('.local', '');
  // Apple devices prefix a MAC ("A1B2C3D4E5F6@Living Room").
  final at = label.indexOf('@');
  return at > 0 ? label.substring(at + 1) : label;
}

Uint8List _dnsQuery(String name, int type) {
  final b = BytesBuilder()
    ..add([0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in name.split('.')) {
    final bytes = utf8.encode(label);
    b
      ..addByte(bytes.length)
      ..add(bytes);
  }
  // Type, then class IN with the "unicast response" bit set.
  b.add([0, 0, (type >> 8) & 0xFF, type & 0xFF, 0x80, 0x01]);
  return b.toBytes();
}

class _Rr {
  _Rr(this.name, this.type);

  final String name;
  final int type;
  String? target;
  String? ipv4;
  Map<String, String> txt = const {};
}

/// Minimal DNS reader: answers and additionals of the record types above.
List<_Rr>? _parseDns(Uint8List p) {
  if (p.length < 12) return null;
  int u16(int o) => (p[o] << 8) | p[o + 1];

  (String, int) readName(int o, [int depth = 0]) {
    final parts = <String>[];
    var pos = o;
    int? end;
    while (pos < p.length) {
      final len = p[pos];
      if (len == 0) {
        pos++;
        break;
      }
      if (len & 0xC0 == 0xC0) {
        if (pos + 1 >= p.length || depth > 10) break;
        final pointer = ((len & 0x3F) << 8) | p[pos + 1];
        end ??= pos + 2;
        final (rest, _) = readName(pointer, depth + 1);
        if (rest.isNotEmpty) parts.add(rest);
        pos = end;
        return (parts.join('.'), end);
      }
      if (pos + 1 + len > p.length) break;
      parts.add(utf8.decode(p.sublist(pos + 1, pos + 1 + len), allowMalformed: true));
      pos += 1 + len;
    }
    return (parts.join('.'), end ?? pos);
  }

  try {
    final qd = u16(4), an = u16(6), ns = u16(8), ar = u16(10);
    var o = 12;
    for (var i = 0; i < qd; i++) {
      o = readName(o).$2 + 4;
    }
    final out = <_Rr>[];
    for (var i = 0; i < an + ns + ar && o + 10 <= p.length; i++) {
      final (name, after) = readName(o);
      o = after;
      final type = u16(o);
      final rdlen = u16(o + 8);
      final rd = o + 10;
      if (rd + rdlen > p.length) break;
      final r = _Rr(name, type);
      switch (type) {
        case 1 when rdlen == 4:
          r.ipv4 = '${p[rd]}.${p[rd + 1]}.${p[rd + 2]}.${p[rd + 3]}';
        case 12:
          r.target = readName(rd).$1;
        case 33 when rdlen > 6:
          r.target = readName(rd + 6).$1;
        case 16:
          final txt = <String, String>{};
          var t = rd;
          while (t < rd + rdlen) {
            final l = p[t];
            final s = utf8.decode(p.sublist(t + 1, math.min(t + 1 + l, rd + rdlen)), allowMalformed: true);
            final eq = s.indexOf('=');
            if (eq > 0) txt[s.substring(0, eq).toLowerCase()] = s.substring(eq + 1);
            t += 1 + l;
          }
          r.txt = txt;
      }
      out.add(r);
      o = rd + rdlen;
    }
    return out;
  } on RangeError {
    return null;
  }
}

// ── SSDP / UPnP ──────────────────────────────────────────────────────────

Future<Map<String, DeviceHint>> _ssdp(Duration window) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final locations = <String, Uri>{};
  final sub = socket.listen((e) {
    if (e != RawSocketEvent.read) return;
    final d = socket.receive();
    if (d == null) return;
    final text = utf8.decode(d.data, allowMalformed: true);
    final loc = RegExp(r'^location:\s*(\S+)', caseSensitive: false, multiLine: true).firstMatch(text)?[1];
    final uri = loc == null ? null : Uri.tryParse(loc);
    if (uri != null) locations.putIfAbsent(d.address.address, () => uri);
  });
  const search = 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: ssdp:all\r\n\r\n';
  socket.send(utf8.encode(search), InternetAddress('239.255.255.250'), 1900);
  await Future<void>.delayed(window);
  await sub.cancel();
  socket.close();

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  final out = <String, DeviceHint>{};
  try {
    await Future.wait(locations.entries.take(24).map((e) async {
      try {
        final request = await client.getUrl(e.value);
        final response = await request.close().timeout(const Duration(seconds: 2));
        final xml = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 2));
        String? tag(String n) => RegExp('<$n>(.*?)</$n>', dotAll: true).firstMatch(xml)?[1]?.trim();
        final type = (tag('deviceType') ?? '').toLowerCase();
        final maker = tag('manufacturer');
        final model = tag('modelName');
        final kind = type.contains('internetgatewaydevice')
            ? DeviceKind.router
            : type.contains('mediarenderer') || type.contains('dial')
                ? DeviceKind.tv
                : type.contains('printer')
                    ? DeviceKind.printer
                    : DeviceKind.unknown;
        out[e.key] = DeviceHint(
          name: tag('friendlyName'),
          model: [maker, model].whereType<String>().where((s) => s.isNotEmpty).join(' '),
          kind: kind,
        );
      } on Object {
        // A device that will not describe itself keeps its other hints.
      }
    }));
  } finally {
    client.close(force: true);
  }
  return out;
}

/// Last resort: guess from a name ("Galaxy S22", "DESKTOP-4F2", "LG TV").
DeviceKind kindFromName(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.isEmpty) return DeviceKind.unknown;
  if (RegExp(r'iphone|ipad|galaxy|pixel|redmi|oppo|vivo|tecno|infinix|phone|android').hasMatch(n)) return DeviceKind.phone;
  if (RegExp(r'\btv\b|tizen|bravia|roku|chromecast|fire ?stick|webos').hasMatch(n)) return DeviceKind.tv;
  if (RegExp(r'macbook|imac|desktop-|laptop-|\bpc\b|thinkpad|windows').hasMatch(n)) return DeviceKind.computer;
  if (RegExp(r'printer|epson|canon|hp |brother').hasMatch(n)) return DeviceKind.printer;
  if (RegExp(r'camera|cam\b|hikvision|dahua|ezviz|tapo').hasMatch(n)) return DeviceKind.camera;
  if (RegExp(r'echo|alexa|sonos|speaker|homepod').hasMatch(n)) return DeviceKind.speaker;
  return DeviceKind.unknown;
}
