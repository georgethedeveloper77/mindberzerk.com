/// One volunteer server from the Community list (VPN Gate, ranked by the
/// gvpn-servers Worker). Its OpenVPN config is fetched only at connect time.
class CommunityServer {
  const CommunityServer({
    required this.id,
    required this.country,
    required this.countryCode,
    required this.proto,
    required this.port,
    required this.speedMbps,
    required this.pingMs,
    required this.sessions,
    required this.quality,
    required this.grade,
    this.uptimeDays = 0,
    this.source = 'vpngate',
    this.sstpHost,
    this.sstpPort,
  });

  final String id;
  final String country;
  final String countryCode;
  final String proto;
  final int port;
  final double speedMbps;
  final int pingMs;
  final int sessions;
  final int quality;

  /// fast, good or slow; decided server-side so every phone agrees.
  final String grade;

  /// Days the server has been up without restarting (VPN Gate reports it).
  final double uptimeDays;

  /// vpngate or oneconnect.
  final String source;

  /// Where the server takes SSTP, when it does (VPN Gate lists it).
  final String? sstpHost;
  final int? sstpPort;

  /// Regional-indicator letters: "JP" becomes the Japanese flag.
  String get flag {
    if (countryCode.length != 2) return '';
    const base = 0x1F1E6 - 0x41;
    return String.fromCharCodes(countryCode.toUpperCase().codeUnits.map((c) => base + c));
  }

  Map<String, Object> toJson() => {
        'id': id,
        'country': country,
        'countryCode': countryCode,
        'proto': proto,
        'port': port,
        'speedMbps': speedMbps,
        'pingMs': pingMs,
        'sessions': sessions,
        'quality': quality,
        'grade': grade,
        'uptimeDays': uptimeDays,
        'source': source,
        if (sstpHost != null) 'sstpHost': sstpHost!,
        if (sstpPort != null) 'sstpPort': sstpPort!,
      };

  static CommunityServer? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], country = json['country'], cc = json['countryCode'];
    if (id is! String || country is! String || cc is! String) return null;
    num n(String k) => json[k] is num ? json[k] as num : 0;
    return CommunityServer(
      id: id,
      country: country,
      countryCode: cc,
      proto: json['proto'] is String ? json['proto'] as String : 'udp',
      port: n('port').toInt(),
      speedMbps: n('speedMbps').toDouble(),
      pingMs: n('pingMs').toInt(),
      sessions: n('sessions').toInt(),
      quality: n('quality').toInt(),
      grade: json['grade'] is String ? json['grade'] as String : 'good',
      uptimeDays: n('uptimeDays').toDouble(),
      source: json['source'] is String ? json['source'] as String : 'vpngate',
      sstpHost: json['sstpHost'] is String ? json['sstpHost'] as String : null,
      sstpPort: json['sstpPort'] is num ? (json['sstpPort'] as num).toInt() : null,
    );
  }
}
