import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// What kind of site a test list holds.
enum SiteKind { social, messaging, news, video, privacy }

/// The sites tested, by kind: well-known services people most often find
/// blocked. Kept short so a full test takes under a minute.
const testSites = <SiteKind, List<String>>{
  SiteKind.social: ['facebook.com', 'x.com', 'instagram.com', 'tiktok.com', 'reddit.com', 'linkedin.com', 'pinterest.com', 'snapchat.com'],
  SiteKind.messaging: ['whatsapp.com', 'telegram.org', 'signal.org', 'discord.com', 'viber.com', 'messenger.com'],
  SiteKind.news: ['bbc.com', 'reuters.com', 'dw.com', 'nytimes.com', 'aljazeera.com', 'theguardian.com', 'apnews.com', 'rferl.org'],
  SiteKind.video: ['youtube.com', 'spotify.com', 'twitch.tv', 'netflix.com', 'soundcloud.com', 'vimeo.com'],
  SiteKind.privacy: ['torproject.org', 'protonvpn.com', 'psiphon.ca', 'getoutline.org', 'mullvad.net'],
};

SiteKind kindOf(String host) => testSites.entries.firstWhere((e) => e.value.contains(host)).key;

/// How a site failed, or that it opened.
enum Block {
  open,

  /// The network's name lookup gave a false or empty answer.
  dns,

  /// The connection was cut, usually during the secure handshake.
  reset,

  /// Nothing came back.
  timeout,

  /// Something answered pretending to be the site: a block page.
  page,

  /// Could not be tested (no address anywhere): not counted as blocked.
  unknown,
}

extension BlockX on Block {
  bool get blocked => this == Block.dns || this == Block.reset || this == Block.timeout || this == Block.page;
}

/// Why a step failed, worded by the screen in the user's language.
enum Failure { noAnswer, refused, cutOff, wrongCertificate }

/// One step of a site's test, for the detail sheet.
@immutable
class ProbeStep {
  const ProbeStep(this.ok, this.detail, {this.failure, this.after});

  /// Null when the step was never reached.
  final bool? ok;

  /// Addresses and times: the same in every language.
  final String detail;
  final Failure? failure;

  /// Seconds into the step when it was cut off.
  final double? after;
}

@immutable
class SiteResult {
  const SiteResult({required this.host, required this.block, required this.lookup, required this.connect, required this.handshake, this.ms});

  final String host;
  final Block block;
  final ProbeStep lookup;
  final ProbeStep connect;
  final ProbeStep handshake;

  /// Time to a finished secure handshake, when it finished.
  final int? ms;
}

bool _bogon(InternetAddress a) {
  final b = a.rawAddress;
  if (a.type != InternetAddressType.IPv4 || b.length != 4) return a.isLoopback || a.isLinkLocal;
  return b[0] == 0 || b[0] == 127 || b[0] == 10 || (b[0] == 192 && b[1] == 168) || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 169 && b[1] == 254);
}

/// The site's addresses from Cloudflare's encrypted lookup, which the
/// network cannot change. Empty when that lookup is itself blocked.
Future<List<InternetAddress>> _trueAddresses(String host) async {
  try {
    final res = await http
        .get(Uri.parse('https://cloudflare-dns.com/dns-query?name=$host&type=A'), headers: const {'accept': 'application/dns-json'})
        .timeout(const Duration(seconds: 5));
    final answers = (jsonDecode(res.body) as Map)['Answer'] as List? ?? const [];
    return [
      for (final a in answers)
        if (a is Map && a['type'] == 1) InternetAddress.tryParse('${a['data']}'),
    ].whereType<InternetAddress>().toList();
  } on Object {
    return const [];
  }
}

/// Tests one site the way a browser reaches it: name lookup, connection,
/// secure handshake. Each step that fails says how the site is blocked.
Future<SiteResult> probeSite(String host) async {
  // 1. The network's own name lookup, against the encrypted one.
  List<InternetAddress> local = const [];
  try {
    local = await InternetAddress.lookup(host, type: InternetAddressType.IPv4).timeout(const Duration(seconds: 5));
  } on Object {
    local = const [];
  }
  final real = await _trueAddresses(host);
  final localOk = local.isNotEmpty && !local.every(_bogon);
  final lookup = localOk
      ? ProbeStep(true, '$host → ${local.first.address}')
      : local.isEmpty
          ? const ProbeStep(false, '', failure: Failure.noAnswer)
          : ProbeStep(false, '$host → ${local.first.address}');
  final dnsBlocked = !localOk && real.isNotEmpty;

  // 2. Connect to a true address, so a false lookup cannot hide what the
  // connection itself meets.
  final target = real.isNotEmpty ? real.first : (localOk ? local.first : null);
  if (target == null) {
    return SiteResult(host: host, block: Block.unknown, lookup: lookup, connect: const ProbeStep(null, ''), handshake: const ProbeStep(null, ''));
  }
  final watch = Stopwatch()..start();
  Socket socket;
  try {
    socket = await Socket.connect(target, 443, timeout: const Duration(seconds: 6));
  } on Object catch (e) {
    final timedOut = e is TimeoutException || '$e'.toLowerCase().contains('timed out');
    return SiteResult(
      host: host,
      block: dnsBlocked ? Block.dns : timedOut ? Block.timeout : Block.reset,
      lookup: lookup,
      connect: ProbeStep(false, '', failure: timedOut ? Failure.noAnswer : Failure.refused),
      handshake: const ProbeStep(null, ''),
    );
  }
  final connectMs = watch.elapsedMilliseconds;

  // 3. The secure handshake, naming the site as a browser does. Equipment
  // that blocks by name cuts it here; a block page shows a wrong certificate.
  var badCert = false;
  try {
    final secure = await SecureSocket.secure(
      socket,
      host: host,
      onBadCertificate: (_) {
        badCert = true;
        return false;
      },
    ).timeout(const Duration(seconds: 6));
    final ms = watch.elapsedMilliseconds;
    secure.destroy();
    return SiteResult(
      host: host,
      block: dnsBlocked ? Block.dns : Block.open,
      lookup: lookup,
      connect: ProbeStep(true, 'port 443 · $connectMs ms'),
      handshake: ProbeStep(true, '$ms ms'),
      ms: ms,
    );
  } on Object catch (e) {
    socket.destroy();
    final timedOut = e is TimeoutException;
    final at = (watch.elapsedMilliseconds - connectMs) / 1000;
    return SiteResult(
      host: host,
      block: dnsBlocked
          ? Block.dns
          : badCert
              ? Block.page
              : timedOut
                  ? Block.timeout
                  : Block.reset,
      lookup: lookup,
      connect: ProbeStep(true, 'port 443 · $connectMs ms'),
      handshake: ProbeStep(
        false,
        '',
        failure: badCert
            ? Failure.wrongCertificate
            : timedOut
                ? Failure.noAnswer
                : Failure.cutOff,
        after: at,
      ),
    );
  }
}

enum TestPhase { idle, running, done }

@immutable
class BlockedState {
  const BlockedState({
    this.phase = TestPhase.idle,
    this.kinds = const {SiteKind.social, SiteKind.messaging, SiteKind.news},
    this.results = const {},
    this.total = 0,
    this.network,
    this.at,
    this.throughVpn = const {},
    this.checkingVpn = false,
  });

  final TestPhase phase;
  final Set<SiteKind> kinds;

  /// In the order they finished.
  final Map<String, SiteResult> results;
  final int total;

  /// The network the results belong to ("Safaricom", a Wi-Fi name).
  final String? network;
  final DateTime? at;

  /// Blocked sites tested again through G VPN: host → opened.
  final Map<String, bool> throughVpn;
  final bool checkingVpn;

  List<SiteResult> get blocked => [for (final r in results.values) if (r.block.blocked) r];

  BlockedState copyWith({
    TestPhase? phase,
    Set<SiteKind>? kinds,
    Map<String, SiteResult>? results,
    int? total,
    String? network,
    DateTime? at,
    Map<String, bool>? throughVpn,
    bool? checkingVpn,
  }) =>
      BlockedState(
        phase: phase ?? this.phase,
        kinds: kinds ?? this.kinds,
        results: results ?? this.results,
        total: total ?? this.total,
        network: network ?? this.network,
        at: at ?? this.at,
        throughVpn: throughVpn ?? this.throughVpn,
        checkingVpn: checkingVpn ?? this.checkingVpn,
      );
}

final blockedProvider = NotifierProvider<BlockedController, BlockedState>(BlockedController.new);

/// Runs a test, four sites at a time, and keeps the last results for as
/// long as the app runs. Nothing is stored or sent anywhere.
class BlockedController extends Notifier<BlockedState> {
  int _run = 0;

  @override
  BlockedState build() => const BlockedState();

  void setKinds(Set<SiteKind> kinds) => state = state.copyWith(kinds: kinds);

  Future<void> start({required String network}) async {
    final run = ++_run;
    final hosts = [for (final k in SiteKind.values) if (state.kinds.contains(k)) ...testSites[k]!];
    state = BlockedState(kinds: state.kinds, phase: TestPhase.running, total: hosts.length, network: network);
    var next = 0;
    Future<void> worker() async {
      while (next < hosts.length && run == _run) {
        final host = hosts[next++];
        final r = await probeSite(host);
        if (run != _run) return;
        state = state.copyWith(results: {...state.results, host: r});
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    if (run == _run) state = state.copyWith(phase: TestPhase.done, at: DateTime.now());
  }

  void stop() {
    _run++;
    state = state.copyWith(phase: state.results.isEmpty ? TestPhase.idle : TestPhase.done, at: DateTime.now());
  }

  void reset() {
    _run++;
    state = BlockedState(kinds: state.kinds);
  }

  /// With G VPN on: tries each blocked site again, to show it now opens.
  Future<void> checkThroughVpn() async {
    state = state.copyWith(checkingVpn: true);
    final out = <String, bool>{};
    await Future.wait([
      for (final r in state.blocked)
        probeSite(r.host).then((v) => out[r.host] = v.block == Block.open),
    ]);
    state = state.copyWith(throughVpn: out, checkingVpn: false);
  }
}

// ── The country, from OONI's open data ─────────────────────────────────

const _countryUrl = String.fromEnvironment('BLOCKED_URL', defaultValue: 'https://gvpn-blocked.mindberzerk.workers.dev');

@immutable
class CountryBlock {
  const CountryBlock({required this.domain, required this.tests, required this.anomalies, required this.confirmed});

  final String domain;
  final int tests;
  final int anomalies;

  /// Tests where a block page was recognised: certain.
  final int confirmed;

  bool get certain => confirmed > 0;
}

@immutable
class CountryReport {
  const CountryReport({required this.country, required this.sites});

  final String country;
  final List<CountryBlock> sites;
}

/// What volunteers' tests in the phone's country found over the last 30
/// days. Read through our Worker, so OONI never sees the phone.
final countryBlocksProvider = FutureProvider.autoDispose<CountryReport?>((ref) async {
  try {
    final res = await http.get(Uri.parse('$_countryUrl/country')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map;
    return CountryReport(
      country: '${j['country']}',
      sites: [
        for (final s in (j['blocked'] as List? ?? const []))
          if (s is Map)
            CountryBlock(
              domain: '${s['domain']}',
              tests: (s['tests'] as num?)?.toInt() ?? 0,
              anomalies: (s['anomalies'] as num?)?.toInt() ?? 0,
              confirmed: (s['confirmed'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  } on Object {
    return null;
  }
});
