import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A port a device on the network asked the router to open to the internet.
class PortMapping {
  const PortMapping({
    required this.externalPort,
    required this.protocol,
    required this.internalClient,
    required this.internalPort,
    required this.description,
  });

  final int externalPort;
  final String protocol;
  final String internalClient;
  final int internalPort;
  final String description;
}

class UpnpReport {
  const UpnpReport({required this.enabled, this.routerName, this.externalIp, this.mappings = const [], this.listed = false});

  /// The router answered UPnP discovery.
  final bool enabled;
  final String? routerName;
  final String? externalIp;
  final List<PortMapping> mappings;

  /// The router let us read its mapping table (some refuse).
  final bool listed;

  /// Carrier-grade NAT or a private address upstream: mappings stop at the
  /// ISP, so nothing is actually reachable from the internet.
  bool get behindCarrierNat {
    final ip = externalIp;
    if (ip == null) return false;
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.contains(null)) return false;
    final a = p[0]!, b = p[1]!;
    return a == 10 || (a == 100 && b >= 64 && b <= 127) || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }
}

const _gatewayTypes = [
  'urn:schemas-upnp-org:service:WANIPConnection:2',
  'urn:schemas-upnp-org:service:WANIPConnection:1',
  'urn:schemas-upnp-org:service:WANPPPConnection:1',
];

/// Asks the router, over UPnP, whether devices may open ports on it, and
/// which they have opened. Read-only: it never adds or removes a mapping.
Future<UpnpReport> checkUpnp() async {
  final location = await _discover();
  if (location == null) return const UpnpReport(enabled: false);

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    final description = await _get(client, location);
    final routerName = _tag(description, 'friendlyName') ?? _tag(description, 'modelName');

    // Find the WAN connection service and its control URL.
    String? serviceType, controlPath;
    for (final block in RegExp(r'<service>(.*?)</service>', dotAll: true).allMatches(description)) {
      final type = _tag(block[1]!, 'serviceType');
      if (type != null && _gatewayTypes.contains(type)) {
        serviceType = type;
        controlPath = _tag(block[1]!, 'controlURL');
        break;
      }
    }
    if (serviceType == null || controlPath == null) {
      return UpnpReport(enabled: true, routerName: routerName);
    }
    final control = location.resolve(controlPath);

    final ipReply = await _soap(client, control, serviceType, 'GetExternalIPAddress', '');
    final externalIp = ipReply == null ? null : _tag(ipReply, 'NewExternalIPAddress');

    final mappings = <PortMapping>[];
    var listed = false;
    for (var i = 0; i < 64; i++) {
      final reply = await _soap(
        client,
        control,
        serviceType,
        'GetGenericPortMappingEntry',
        '<NewPortMappingIndex>$i</NewPortMappingIndex>',
      );
      if (reply == null) break; // a fault marks the end of the table
      listed = true;
      mappings.add(PortMapping(
        externalPort: int.tryParse(_tag(reply, 'NewExternalPort') ?? '') ?? 0,
        protocol: _tag(reply, 'NewProtocol') ?? '?',
        internalClient: _tag(reply, 'NewInternalClient') ?? '?',
        internalPort: int.tryParse(_tag(reply, 'NewInternalPort') ?? '') ?? 0,
        description: _tag(reply, 'NewPortMappingDescription') ?? '',
      ));
    }
    return UpnpReport(
      enabled: true,
      routerName: routerName,
      externalIp: externalIp,
      mappings: mappings,
      listed: listed || mappings.isNotEmpty,
    );
  } on Object {
    return const UpnpReport(enabled: true);
  } finally {
    client.close(force: true);
  }
}

/// SSDP M-SEARCH for an internet gateway; returns its description URL.
Future<Uri?> _discover() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final done = Completer<Uri?>();
  final sub = socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    final text = utf8.decode(datagram.data, allowMalformed: true);
    final location = RegExp(r'^location:\s*(\S+)', caseSensitive: false, multiLine: true).firstMatch(text)?[1];
    if (location != null && !done.isCompleted) done.complete(Uri.tryParse(location));
  });
  const search = 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n';
  final target = InternetAddress('239.255.255.250');
  for (var i = 0; i < 2; i++) {
    socket.send(utf8.encode(search), target, 1900);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  final location = await done.future.timeout(const Duration(seconds: 3), onTimeout: () => null);
  await sub.cancel();
  socket.close();
  return location;
}

Future<String> _get(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  final response = await request.close().timeout(const Duration(seconds: 4));
  return response.transform(utf8.decoder).join();
}

/// One SOAP call. Null on a fault or any HTTP error.
Future<String?> _soap(HttpClient client, Uri control, String serviceType, String action, String args) async {
  final body = '<?xml version="1.0"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body><u:$action xmlns:u="$serviceType">$args</u:$action></s:Body></s:Envelope>';
  try {
    final request = await client.postUrl(control);
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'text/xml; charset="utf-8"')
      ..set('SOAPAction', '"$serviceType#$action"');
    request.add(utf8.encode(body));
    final response = await request.close().timeout(const Duration(seconds: 4));
    final text = await response.transform(utf8.decoder).join();
    return response.statusCode == 200 ? text : null;
  } on Object {
    return null;
  }
}

String? _tag(String xml, String name) =>
    RegExp('<(?:[A-Za-z0-9]+:)?$name>(.*?)</(?:[A-Za-z0-9]+:)?$name>', dotAll: true).firstMatch(xml)?[1]?.trim();
