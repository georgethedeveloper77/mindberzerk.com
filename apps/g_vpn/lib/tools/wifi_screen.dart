import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../design/wifi_name_prompt.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';
import 'network_screen.dart';
import 'oui.dart';
import 'tool_settings.dart';
import 'tool_widgets.dart' show ToolTitle;

final wifiScanProvider = FutureProvider.autoDispose<List<WifiAccessPoint>>(
  (ref) => ref.read(vpnApiProvider).scanWifi(),
);

final _wifiAllowedProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(vpnApiProvider).wifiNamesAllowed());

// ── Model ───────────────────────────────────────────────────────────────

enum _Safety { secure, weak, open }

/// One access point, read the way the screens need it.
class _Net {
  _Net(this.ap, {required this.current})
      : base = ap.security.split('+').first,
        wps = ap.security.split('+').contains('WPS');

  final WifiAccessPoint ap;

  /// The network this phone is on.
  final bool current;

  /// Open, WEP, WPA, WPA2 or WPA3.
  final String base;

  /// WPS left on: a PIN that is easy to guess opens the network.
  final bool wps;

  String get name => ap.ssid.isEmpty ? t.wifi.hidden : ap.ssid;
  bool get is24 => ap.frequencyMhz < 3000;
  String get band => ap.frequencyMhz >= 5925 ? '6 GHz' : ap.frequencyMhz >= 4900 ? '5 GHz' : '2.4 GHz';
  int get channel => ap.channel;
  int get dbm => ap.level;

  _Safety get safety => switch (base) {
        'Open' || 'WEP' => _Safety.open,
        'WPA' => _Safety.weak,
        _ => wps ? _Safety.weak : _Safety.secure,
      };

  String get securityLabel => wps ? '$base/WPS' : base;

  String get verdict => switch (base) {
        'Open' => t.wifi.verdictOpen,
        'WEP' => t.wifi.verdictWep,
        'WPA' => t.wifi.verdictWpa,
        _ => wps ? t.wifi.verdictWps : t.wifi.verdictGood,
      };
}

Color _tone(_Safety s, Meridian m) => switch (s) {
      _Safety.secure => m.good,
      _Safety.weak => m.warn,
      _Safety.open => m.bad,
    };

// ── Screen ──────────────────────────────────────────────────────────────

/// The air around you, the channels it crowds, and the plain list.
class WifiScreen extends ConsumerWidget {
  const WifiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final allowed = ref.watch(_wifiAllowedProvider).value;
    final current = ref.watch(liveSnapshotProvider).value?.ssid;

    Widget scaffold({required Widget body, Widget? action, bool tabs = false}) => DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: ToolTitle(title: t.wifi.title, icon: Icons.wifi_find_rounded, color: m.brand),
              centerTitle: false,
              actions: [InfoAction(title: t.wifi.title, body: allowed == false ? t.wifi.permissionInfo : t.wifi.info)],
              bottom: tabs
                  ? TabBar(
                      labelColor: m.brand,
                      unselectedLabelColor: m.muted,
                      indicatorColor: m.brand,
                      labelStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w800),
                      tabs: [Tab(text: t.wifi.airMap), Tab(text: t.wifi.channels), Tab(text: t.wifi.list)],
                    )
                  : null,
            ),
            body: Column(
              children: [
                Expanded(child: body),
                if (action != null)
                  SafeArea(
                    top: false,
                    child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: SizedBox(width: double.infinity, child: action)),
                  ),
              ],
            ),
          ),
        );

    if (allowed == null) return scaffold(body: const SizedBox.shrink());
    if (!allowed) {
      return scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t.wifi.needsPermission, style: TextStyle(fontSize: 14, color: m.muted)),
        ),
        action: FilledButton(
          onPressed: () async {
            await askForWifiNames(context, ref);
            ref.invalidate(_wifiAllowedProvider);
            ref.invalidate(wifiScanProvider);
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(t.wifi.allow),
        ),
      );
    }

    final scan = ref.watch(wifiScanProvider);
    final again = FilledButton(
      onPressed: scan.isLoading ? null : () => ref.invalidate(wifiScanProvider),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: Text(scan.isLoading ? t.wifi.scanning : t.wifi.again),
    );

    return switch (scan) {
      AsyncData(:final value) when value.isEmpty => scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: Text(t.wifi.none, style: TextStyle(color: m.muted))),
          action: again,
        ),
      AsyncData(:final value) => scaffold(
          tabs: true,
          action: again,
          body: Builder(builder: (context) {
            final nets = [for (final ap in value) _Net(ap, current: current != null && ap.ssid == current)];
            return TabBarView(children: [_AirTab(nets: nets), _ChannelsTab(nets: nets), _ListTab(nets: nets)]);
          }),
        ),
      AsyncError(:final error) => scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(error is PlatformException ? (error.message ?? t.wifi.failed) : '$error', style: TextStyle(color: m.bad)),
          ),
          action: again,
        ),
      _ => scaffold(body: const Center(child: CircularProgressIndicator()), action: again),
    };
  }
}

// ── Air map ─────────────────────────────────────────────────────────────

/// Where each network sits on the map: 2.4 GHz to the left, 5 and 6 GHz
/// to the right, stronger signals nearer the middle.
List<(Offset, double)> _place(List<_Net> nets, Size size) {
  final c = size.center(Offset.zero);
  final reach = size.shortestSide / 2 - 24;
  final placed = <(Offset, double)>[];
  for (final n in nets) {
    final r = switch (n.ap.widthMhz) { >= 160 => 13.0, >= 80 => 11.0, >= 40 => 9.0, _ => 7.0 };
    final strength = ((n.dbm + 35) / -60).clamp(0.0, 1.0); // 0 strongest, 1 faintest
    final dist = 34 + strength * (reach - 34);
    final side = n.is24 ? -1.0 : 1.0;
    // A steady angle per network, so a rescan does not shuffle the map.
    final seed = n.ap.bssid.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0xffff);
    var angle = (seed / 0xffff - .5) * math.pi * .85;
    Offset at() => c + Offset(side * math.cos(angle) * dist, math.sin(angle) * dist);
    var p = at();
    for (var tries = 0; tries < 24 && placed.any((q) => (q.$1 - p).distance < q.$2 + r + 6); tries++) {
      angle += (tries.isEven ? 1 : -1) * .18 * (tries + 1);
      p = at();
    }
    placed.add((p, r));
  }
  return placed;
}

class _AirTab extends ConsumerStatefulWidget {
  const _AirTab({required this.nets});

  final List<_Net> nets;

  @override
  ConsumerState<_AirTab> createState() => _AirTabState();
}

class _AirTabState extends ConsumerState<_AirTab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final nets = widget.nets;
    final strongest = nets.reduce((a, b) => a.dbm >= b.dbm ? a : b);
    final open = nets.where((n) => n.safety == _Safety.open).toList();
    final me = nets.where((n) => n.current).firstOrNull;
    final shared = me == null ? const <_Net>[] : nets.where((n) => !n.current && n.channel == me.channel).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text(t.wifi.nearby(n: nets.length), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, box) {
            final size = box.biggest;
            final spots = _place(nets, size);
            return GestureDetector(
              onTapUp: (d) {
                var best = -1;
                var bestD = 30.0;
                for (final (i, s) in spots.indexed) {
                  final dist = (s.$1 - d.localPosition).distance - s.$2;
                  if (dist < bestD) {
                    bestD = dist;
                    best = i;
                  }
                }
                if (best >= 0) _showNetwork(context, nets[best]);
              },
              child: Semantics(
                label: t.wifi.nearby(n: nets.length),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => CustomPaint(
                    size: size,
                    painter: _AirPainter(nets: nets, spots: spots, m: m, pulse: _pulse.value),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final (label, color) in [(t.wifi.secure, m.good), (t.wifi.weakLabel, m.warn), (t.wifi.openLabel, m.bad)])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: m.muted)),
              ]),
            Text(t.wifi.sizeIsWidth, style: TextStyle(fontSize: 12, color: m.muted)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _StripCard(label: t.wifi.strongest, value: strongest.name, sub: '${strongest.dbm} dBm', color: m.good,
                  onTap: () => _showNetwork(context, strongest)),
              _StripCard(
                label: t.wifi.openNearby,
                value: open.isEmpty ? t.wifi.noneNearby : t.wifi.count(n: open.length),
                sub: open.map((n) => n.name).take(2).join(', '),
                color: open.isEmpty ? m.good : m.bad,
              ),
              if (me != null)
                _StripCard(
                  label: t.wifi.onYourChannel,
                  value: shared.isEmpty ? t.wifi.noneNearby : t.wifi.count(n: shared.length),
                  sub: 'CH ${me.channel}',
                  color: shared.isEmpty ? m.good : m.warn,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AirPainter extends CustomPainter {
  _AirPainter({required this.nets, required this.spots, required this.m, required this.pulse});

  final List<_Net> nets;
  final List<(Offset, double)> spots;
  final Meridian m;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final reach = size.shortestSide / 2 - 24;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = m.line;
    // Rings at -50, -65 and -80 dBm, and the outer edge.
    for (final dbm in [-50, -65, -80]) {
      final r = 34 + ((dbm + 35) / -60).clamp(0.0, 1.0) * (reach - 34);
      canvas.drawCircle(c, r, line);
      _text(canvas, '$dbm', c + Offset(4, -r + 2), m.muted, 9, mono: true);
    }
    canvas.drawCircle(c, reach + 10, line);
    canvas.drawLine(Offset(c.dx, c.dy - reach - 10), Offset(c.dx, c.dy + reach + 10), line);
    _text(canvas, '2.4 GHz', const Offset(4, 0), m.muted, 11, bold: true);
    _text(canvas, '5 GHz', Offset(size.width - 4, 0), m.muted, 11, bold: true, right: true);

    for (final (i, n) in nets.indexed) {
      final (p, r) = spots[i];
      final color = _tone(n.safety, m);
      if (n.current) {
        canvas.drawCircle(p, r + 4 + 14 * pulse, Paint()..color = color.withValues(alpha: .5 * (1 - pulse)));
      }
      canvas.drawCircle(p, r + 2, Paint()..color = m.bg);
      canvas.drawCircle(p, r, Paint()..color = color.withValues(alpha: n.current ? 1 : .8));
      if (n.current || n.dbm > -62) {
        _text(canvas, n.name, p + Offset(0, r + 4), n.current ? m.text : m.muted, 11, bold: true, centre: true);
      }
    }

    // You, in the middle.
    canvas.drawCircle(c, 16, Paint()..color = m.brand);
    const icon = Icons.smartphone_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: 18, fontFamily: icon.fontFamily, package: icon.fontPackage, color: m.onBrand),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(Canvas canvas, String s, Offset at, Color color, double size,
      {bool bold = false, bool mono = false, bool right = false, bool centre = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontFamily: mono ? Meridian.mono : Meridian.sans,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: null,
    )..layout(maxWidth: 120);
    final dx = right ? at.dx - tp.width : centre ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_AirPainter old) => old.pulse != pulse || old.nets != nets || old.m != m;
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.label, required this.value, required this.sub, required this.color, this.onTap});

  final String label;
  final String value;
  final String sub;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: m.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Meridian.rTile), side: BorderSide(color: m.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(Meridian.rTile),
          onTap: onTap,
          child: Container(
            width: 156,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: color)),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                Text(sub, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: TextStyle(fontSize: 12, color: m.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Channels ────────────────────────────────────────────────────────────

/// The 5 GHz channels most routers use, in order across the band.
const _channels5 = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165];

/// Channels that avoid radar rules, so any router can move to them.
const _clear5 = [36, 40, 44, 48, 149, 153, 157, 161];

/// How crowded [channel] is: strong neighbours count more than faint ones,
/// and on 2.4 GHz channels within four of each other overlap.
double _load(List<_Net> nets, int channel, {required bool twoFour}) {
  var load = 0.0;
  for (final n in nets) {
    if (n.is24 != twoFour || n.current) continue;
    final near = twoFour ? (n.channel - channel).abs() < 5 : n.channel == channel;
    if (near) load += ((n.dbm + 100) / 50).clamp(0.1, 1.5);
  }
  return load;
}

class _ChannelsTab extends StatefulWidget {
  const _ChannelsTab({required this.nets});

  final List<_Net> nets;

  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  late bool _twoFour = widget.nets.where((n) => n.current).firstOrNull?.is24 ?? true;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final nets = widget.nets.where((n) => n.is24 == _twoFour).toList();
    final me = widget.nets.where((n) => n.current && n.is24 == _twoFour).firstOrNull;
    final axis = _twoFour ? [for (var c = 1; c <= 13; c++) c] : _channels5;
    final candidates = _twoFour ? const [1, 6, 11] : _clear5;
    final best = candidates.reduce((a, b) => _load(widget.nets, a, twoFour: _twoFour) <= _load(widget.nets, b, twoFour: _twoFour) ? a : b);
    final mine = me == null ? null : _load(widget.nets, me.channel, twoFour: _twoFour);
    final bestLoad = _load(widget.nets, best, twoFour: _twoFour);

    // Channels worth listing: those in use, and the clear candidates.
    final used = {for (final n in nets) n.channel};
    final rows = {...used, ...candidates}.where(axis.contains).toList()
      ..sort((a, b) => _load(widget.nets, b, twoFour: _twoFour).compareTo(_load(widget.nets, a, twoFour: _twoFour)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('2.4 GHz')), ButtonSegment(value: false, label: Text('5 GHz'))],
          selected: {_twoFour},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _twoFour = v.first),
        ),
        const SizedBox(height: 12),
        MerCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: SizedBox(
            height: 130,
            child: CustomPaint(size: Size.infinite, painter: _ChannelPainter(nets: nets, axis: axis, m: m)),
          ),
        ),
        if (me != null) ...[
          const SizedBox(height: 10),
          _Advice(
            good: mine! <= bestLoad + .3,
            text: mine <= bestLoad + .3 ? t.wifi.onClear(name: me.name) : t.wifi.move(name: me.name, n: best),
          ),
        ],
        const SizedBox(height: 12),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, ch) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, color: m.line),
                _ChannelRow(
                  channel: ch,
                  load: _load(widget.nets, ch, twoFour: _twoFour),
                  count: nets.where((n) => !n.current && (_twoFour ? (n.channel - ch).abs() < 5 : n.channel == ch)).length,
                  you: me?.channel == ch,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelPainter extends CustomPainter {
  _ChannelPainter({required this.nets, required this.axis, required this.m});

  final List<_Net> nets;
  final List<int> axis;
  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 18;
    final step = (size.width - 24) / (axis.length - 1);
    double xOf(num index) => 12 + index.toDouble() * step;
    for (final (i, ch) in axis.indexed) {
      if (axis.length > 14 && i.isOdd) continue;
      final tp = TextPainter(
        text: TextSpan(text: '$ch', style: TextStyle(fontSize: 9, fontFamily: Meridian.mono, color: m.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xOf(i) - tp.width / 2, base + 4));
    }
    for (final n in nets) {
      final i = axis.indexOf(n.channel);
      if (i < 0) continue;
      // A 20 MHz network spans two channels either side on 2.4 GHz; on
      // 5 GHz each listed channel is 20 MHz wide.
      final half = axis.length == 13 ? 2.0 * (n.ap.widthMhz / 20).clamp(1, 2) : (n.ap.widthMhz / 40).clamp(.5, 4);
      final height = ((n.dbm + 95) / 60).clamp(.08, 1.0) * (base - 6);
      final color = n.current ? m.brand : _tone(n.safety, m);
      final path = Path()
        ..moveTo(xOf(i - half), base)
        ..quadraticBezierTo(xOf(i), base - height * 2, xOf(i + half), base);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: n.current ? .3 : .14));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = n.current ? 2.4 : 1.6
          ..color = color,
      );
    }
    canvas.drawLine(Offset(0, base), Offset(size.width, base), Paint()..color = m.line);
  }

  @override
  bool shouldRepaint(_ChannelPainter old) => old.nets != nets || old.axis != axis || old.m != m;
}

class _Advice extends StatelessWidget {
  const _Advice({required this.good, required this.text});

  final bool good;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final c = good ? m.good : m.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(Meridian.rTile),
        border: Border.all(color: c.withValues(alpha: .4)),
      ),
      child: Row(children: [
        Icon(good ? Icons.check_rounded : Icons.swap_horiz_rounded, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text))),
      ]),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, required this.load, required this.count, required this.you});

  final int channel;
  final double load;
  final int count;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (label, color) = load <= 1.0
        ? (t.wifi.clear, m.good)
        : load <= 3.0
            ? (t.wifi.busy, m.warn)
            : (t.wifi.crowded, m.bad);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text('$channel', style: m.monoStyle(size: 15, weight: FontWeight.w700, color: m.bg)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
            Text(t.wifi.count(n: count), style: TextStyle(fontSize: 12, color: m.muted)),
          ]),
        ),
        if (you) _Pill(text: t.wifi.you, color: m.brand, icon: Icons.person_rounded),
      ]),
    );
  }
}

// ── List ────────────────────────────────────────────────────────────────

enum _Filter { all, b24, b5, open }

class _ListTab extends StatefulWidget {
  const _ListTab({required this.nets});

  final List<_Net> nets;

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final shown = widget.nets.where((n) => switch (_filter) {
          _Filter.all => true,
          _Filter.b24 => n.is24,
          _Filter.b5 => !n.is24,
          _Filter.open => n.safety == _Safety.open,
        }).toList();
    final labels = {
      _Filter.all: t.wifi.allBands,
      _Filter.b24: '2.4 GHz',
      _Filter.b5: '5 GHz',
      _Filter.open: t.wifi.openOnly,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in _Filter.values)
            ChoiceChip(
              label: Text(labels[f]!),
              selected: _filter == f,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = f),
            ),
        ]),
        const SizedBox(height: 12),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, n) in shown.indexed) ...[
              if (i > 0) Divider(height: 1, color: m.line),
              InkWell(
                onTap: () => _showNetwork(context, n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    _Bars(dbm: n.dbm, color: n.current ? m.brand : m.text, dim: m.line),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: n.ap.ssid.isEmpty ? m.muted : m.text)),
                        Text('${n.band} · CH ${n.channel} · ${n.dbm} dBm', style: m.monoStyle(size: 11, color: m.muted)),
                      ]),
                    ),
                    if (n.current) ...[_Pill(text: t.wifi.you, color: m.brand), const SizedBox(width: 6)],
                    _Pill(text: n.securityLabel, color: _tone(n.safety, m)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.dbm, required this.color, required this.dim});

  final int dbm;
  final Color color;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    final bars = dbm >= -55 ? 4 : dbm >= -67 ? 3 : dbm >= -78 ? 2 : 1;
    return SizedBox(
      width: 22,
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 4,
              height: 5.0 + i * 4,
              decoration: BoxDecoration(color: i < bars ? color : dim, borderRadius: BorderRadius.circular(1)),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon, this.solid = false});

  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = solid ? m.bg : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: solid ? color : color.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        if (icon != null) ...[const SizedBox(width: 5), Icon(icon, size: 13, color: fg)],
      ]),
    );
  }
}

// ── The tapped network ──────────────────────────────────────────────────

Future<void> _showNetwork(BuildContext context, _Net n) {
  final m = context.mer;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _NetworkSheet(net: n),
  );
}

class _NetworkSheet extends ConsumerWidget {
  const _NetworkSheet({required this.net});

  final _Net net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final hide = ref.watch(toolSettingsProvider).value?.hideMac ?? true;
    final tone = _tone(net.safety, m);
    final private = Oui.isPrivate(net.ap.bssid);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.wifi_rounded, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(net.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
                Text(net.verdict, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tone)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Pill(text: net.securityLabel, color: tone, icon: Icons.lock_outline_rounded, solid: true),
            _Pill(text: net.band, color: m.muted),
            _Pill(text: '${net.ap.widthMhz} MHz', color: m.muted),
            _Pill(text: 'CH ${net.channel}', color: m.muted),
            _Pill(text: '${net.dbm} dBm', color: m.muted),
            if (net.current) _Pill(text: t.wifi.you, color: m.brand, icon: Icons.person_rounded),
          ]),
          const SizedBox(height: 10),
          FutureBuilder<String?>(
            future: Oui.maker(net.ap.bssid),
            builder: (_, maker) => Column(children: [
              if (maker.data != null) MerRow(t.wifi.maker, maker.data!),
              if (net.ap.bssid.isNotEmpty)
                MerRow(t.wifi.address, private ? t.wifi.privateAddress : maskMac(net.ap.bssid, hide: hide), mono: !private),
            ]),
          ),
        ],
      ),
    );
  }
}
