import '../alerts/alerts_screen.dart' show AlertsBell;
import '../design/meridian.dart';
import '../design/theme_mode.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/wifi_name_prompt.dart';
import '../history/recents_row.dart';
import '../history/stats_screen.dart';
import '../i18n/strings.g.dart';
import '../map/full_map_screen.dart';
import '../map/g_map.dart';
import '../map/map_data.dart';
import '../map/server_sheet.dart';
import '../presets/presets_screen.dart';
import '../rules/apps_screen.dart';
import '../rules/rules_store.dart';
import '../rules/shield_screen.dart';
import '../tools/speed_screen.dart';
import '../tools/tools_providers.dart' show directSpeedProvider;
import '../vpn/vpn_controller.dart';
import 'connect_card.dart';
import 'dart:async';
import 'dart:math' as math;
import 'home_scan.dart';
import 'ip_sheet.dart';

/// Meridian home. A country map heads the page: exposed, it spotlights
/// where you are in red; protected, it flies to the server's region in
/// green with nearby free servers marked. The connection card overlaps the
/// map's lower edge, and everything below scrolls with it.
class MeridianHome extends ConsumerWidget {
  const MeridianHome({
    super.key,
    required this.openServers,
    required this.openTools,
    required this.openRules,
    required this.openPro,
  });

  final VoidCallback openServers;
  final VoidCallback openTools;
  final VoidCallback openRules;
  final VoidCallback openPro;

  /// Header 56, status line, clock and IP chip: the band at the top that
  /// the camera keeps clear.
  static const _overlayBand = 56.0 + 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final on = vpn.phase == VpnPhase.on;
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final paused = vpn.pausedUntil != null;
    final top = MediaQuery.paddingOf(context).top;

    Future<void> connect() => connectFromHome(ref, openServers: openServers);
    void openMap() => FullMapScreen.open(context);

    final statusColor = on && (vpn.reconnecting || paused) ? m.warn : on ? m.good : busy ? m.warn : m.bad;
    final status = switch (vpn.phase) {
      VpnPhase.on => paused
          ? t.home.status.paused
          : vpn.reconnecting
              ? t.home.status.reconnecting
              : t.home.status.protected,
      VpnPhase.connecting => t.home.status.connecting,
      VpnPhase.disconnecting => t.home.status.stopping,
      VpnPhase.off => t.home.status.notProtected,
    };
    final statusIcon = on ? Icons.lock_rounded : busy ? Icons.sync_rounded : Icons.lock_open_rounded;

    return LayoutBuilder(
      builder: (context, box) {
        // The map fills the page. A clear window under the status band
        // shows it; the cards ride up over it as a sheet when scrolled.
        final height = box.maxHeight;
        final window = (height * .40).clamp(220.0, 380.0);
        final sheetTop = top + _overlayBand + window;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _HomeMap(padding: EdgeInsets.fromLTRB(0, top + _overlayBand, 0, height - sheetTop)),
              ),
            ),
            // Keeps the header and status legible over any part of the map.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + _overlayBand + 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [m.bg.withValues(alpha: .92), m.bg.withValues(alpha: .55), m.bg.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: top),
                  _Header(onPro: openPro, onMap: openMap),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(statusIcon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4, color: statusColor),
                      ),
                    ],
                  ),
                  if (paused)
                    Center(
                      child: TextButton(
                        onPressed: () => ref.read(vpnProvider.notifier).resume(),
                        style: TextButton.styleFrom(foregroundColor: m.muted, minimumSize: const Size(48, 36)),
                        child: Text(
                          t.home.resumesAt(time: TimeOfDay.fromDateTime(vpn.pausedUntil!).format(context)),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  else if (on)
                    Center(child: _Clock(since: vpn.connectedAt)),
                  const SizedBox(height: 8),
                  Center(child: _IpChip(onTap: () => showIpSheet(context, onHide: connect))),
                  if (vpn.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Text(vpn.error!, textAlign: TextAlign.center, style: TextStyle(color: m.bad, fontSize: 13)),
                    ),
                  // The window onto the map: a tap on a server marker opens its
                  // servers; anywhere else opens the full map.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) async {
                      final id = await _homeMap.currentState?.markerAt(d.globalPosition);
                      if (!context.mounted) return;
                      final hit = id == null ? null : ref.read(countryServersProvider).where((c) => c.code == id).firstOrNull;
                      if (hit != null) {
                        await showServerSheet(context, country: hit);
                      } else {
                        openMap();
                      }
                    },
                    child: SizedBox(height: window),
                  ),
                  // The sheet: opaque page colour so the map stays behind it.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: m.bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [BoxShadow(color: m.shadow, blurRadius: 24, offset: const Offset(0, -6))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeConnectCard(openServers: openServers),
                          const PresetsRow(),
                          RecentsRow(openServers: openServers),
                          if (!on) ...[const SizedBox(height: 14), const _ScanCard()],
                          const SizedBox(height: 14),
                          const StatsCard(),
                          const SizedBox(height: 14),
                          _Tiles(openRules: openRules, openTools: openTools),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Home's map, reachable from the window above it for marker taps. Only
/// one Home exists at a time.
final _homeMap = GlobalKey<GMapState>();

/// The page-filling map behind Home. Exposed, it opens on the continent,
/// moves to the user's country outlined in red, then their spot; connecting,
/// it spins; protected, it flies into the server's country outlined in
/// green with nearby free servers. Taps go to the full map, not into this.
class _HomeMap extends ConsumerWidget {
  const _HomeMap({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(mapSceneProvider);
    final countries = ref.watch(countryServersProvider);
    return GMap(
      key: _homeMap,
      choreograph: true,
      padding: padding,
      scene: scene.mood == MapMood.protected ? scene.withMarkers([for (final c in countries) c.marker]) : scene,
    );
  }
}

/// Country and IP that sites see; opens the IP sheet.
class _IpChip extends ConsumerWidget {
  const _IpChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final identity = ref.watch(identityProvider);
    final (name, ip) = switch (identity) {
      AsyncData(:final value) => (approximatePlace(value.city, value.country), value.ip),
      AsyncError() => (t.home.ipFailed, null),
      _ => (t.home.ipChecking, null),
    };
    return Material(
      color: m.surface.withValues(alpha: .92),
      shape: StadiumBorder(side: BorderSide(color: m.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null) Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text)),
                if (name != null && ip != null) const SizedBox(width: 8),
                if (ip != null) Text(ip, style: m.monoStyle(size: 13, color: m.muted)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18, color: m.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.onPro, required this.onMap});

  final VoidCallback onPro;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final mode = ref.watch(themeModeProvider);
    final (icon, next, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, ThemeMode.light, t.home.themeSystem),
      ThemeMode.light => (Icons.light_mode_rounded, ThemeMode.dark, t.home.themeLight),
      ThemeMode.dark => (Icons.dark_mode_rounded, ThemeMode.system, t.home.themeDark),
    };
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 20),
          Image.asset('assets/brand/gvpn_mark.png', width: 26, height: 26),
          const SizedBox(width: 10),
          Text('G VPN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3, color: m.text)),
          const Spacer(),
          const AlertsBell(),
          IconButton(
            tooltip: t.map.open,
            onPressed: onMap,
            icon: Icon(Icons.map_outlined, color: m.muted),
          ),
          IconButton(
            tooltip: label,
            onPressed: () => ref.read(themeModeProvider.notifier).set(next),
            icon: Icon(icon, color: m.muted),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: m.brandSoft,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onPro,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(t.home.free, style: TextStyle(color: m.brand, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Ticks once a second, and only while connected and visible.
class _Clock extends StatefulWidget {
  const _Clock({required this.since});

  final DateTime? since;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Clock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.since != null && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (widget.since == null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final d = since == null ? Duration.zero : DateTime.now().difference(since);
    String two(int n) => n.toString().padLeft(2, '0');
    return Text(
      '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}',
      style: context.mer.monoStyle(size: 14, color: context.mer.muted),
    );
  }
}


class _ScanCard extends ConsumerWidget {
  const _ScanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final scan = ref.watch(networkScanProvider);
    final value = scan.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(Meridian.rCard),
        border: Border.all(color: m.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.home.network.title,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6, color: m.muted)),
                    const SizedBox(height: 2),
                    Text(
                      value?.name ?? (value?.nameHidden == true ? t.home.network.wifi : t.home.network.offline),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text),
                    ),
                  ],
                ),
              ),
              if (value?.nameHidden == true)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 40), foregroundColor: m.brand),
                  onPressed: () => askForWifiNames(context, ref),
                  child: Text(t.home.network.showName),
                )
              else if (scan.isLoading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: m.muted)),
            ],
          ),
          const SizedBox(height: 10),
          switch (scan) {
            AsyncData(:final value) => Row(
                children: [
                  for (final (i, chip) in value.chips.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: _Chip(chip: chip)),
                  ],
                ],
              ),
            AsyncError() => Text(t.home.network.scanFailed,
                style: TextStyle(color: m.muted, fontSize: 13)),
            _ => const LinearProgressIndicator(minHeight: 2),
          },
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final ScanChip chip;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (bg, fg) = switch (chip.tone) {
      Tone.bad => (m.badSoft, m.bad),
      Tone.warn => (m.warnSoft, m.warn),
      Tone.ok => (m.surface2, m.text),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Meridian.rChip)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chip.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .4, color: fg.withValues(alpha: .8))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(chip.value, maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _Tiles extends ConsumerWidget {
  const _Tiles({required this.openRules, required this.openTools});

  final VoidCallback openRules;
  final VoidCallback openTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final rules = ref.watch(rulesProvider).value ?? const RulesState();
    final direct = ref.watch(directSpeedProvider).value;
    final auto = switch (rules.autoConnect) {
      AutoConnectChoice.off => t.common.off,
      AutoConnectChoice.open => t.home.tiles.autoOpen,
      AutoConnectChoice.any => t.home.tiles.autoAny,
    };
    final autoOn = rules.autoConnect != AutoConnectChoice.off;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        _Tile(
          icon: Icons.shield_outlined,
          tone: m.good,
          title: t.home.tiles.shield,
          sub: shieldLevelName(rules.shieldLevel),
          accessory: _Switch(on: rules.shield),
          onTap: () => ShieldScreen.open(context),
        ),
        _Tile(
          icon: Icons.alt_route_rounded,
          tone: m.brand,
          title: t.home.tiles.appsDirect,
          sub: rules.excluded.isEmpty ? t.home.tiles.appsAll : t.home.tiles.appsSkip(n: rules.excluded.length),
          accessory: rules.excluded.isEmpty ? null : _Count(rules.excluded.length),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AppsScreen())),
        ),
        _Tile(
          icon: Icons.sync_rounded,
          tone: m.onBrand,
          title: t.home.tiles.autoConnect,
          sub: auto,
          filled: autoOn,
          spin: autoOn,
          accessory: autoOn ? const _OnChip() : null,
          onTap: openRules,
        ),
        _Tile(
          icon: Icons.speed_rounded,
          tone: m.warn,
          title: t.home.tiles.speed,
          sub: direct == null ? t.home.tiles.speedTap : t.home.tiles.speedDirect(mbps: direct.toStringAsFixed(1)),
          accessory: const _Bars(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SpeedScreen())),
        ),
      ],
    );
  }
}

/// A home tile: an icon in a soft square, an accessory top-right that shows
/// state at a glance, and a title with one line of live detail.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.sub,
    required this.onTap,
    this.accessory,
    this.filled = false,
    this.spin = false,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final Widget? accessory;

  /// Brand-filled: the feature is actively doing something.
  final bool filled;
  final bool spin;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = filled ? m.onBrand : m.text;
    final iconColor = filled ? m.onBrand : tone;
    final iconBox = filled ? m.onBrand.withValues(alpha: .18) : tone.withValues(alpha: .13);
    return Material(
      color: filled ? m.brand : m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        side: BorderSide(color: filled ? Colors.transparent : m.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: iconBox, borderRadius: BorderRadius.circular(14)),
                    child: spin ? _Spin(child: Icon(icon, color: iconColor)) : Icon(icon, color: iconColor),
                  ),
                  const Spacer(),
                  if (accessory != null) accessory!,
                ],
              ),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: filled ? fg.withValues(alpha: .85) : m.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 24,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? m.good : m.line, borderRadius: BorderRadius.circular(999)),
      child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(999)),
      child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: m.brand)),
    );
  }
}

class _OnChip extends StatelessWidget {
  const _OnChip();

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: m.onBrand.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)),
      child: Text('ON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: m.onBrand)),
    );
  }
}

/// Slow rotation for an active feature; still when animations are off.
class _Spin extends StatefulWidget {
  const _Spin({required this.child});

  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}

/// Three bars breathing out of step: a meter that reads as "measuring".
class _Bars extends StatefulWidget {
  const _Bars();

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 5,
              // Each bar is a third of a cycle behind the last.
              height: 9 + 17 * (0.5 + 0.5 * math.sin((_c.value + i / 3) * 2 * math.pi)),
              decoration: BoxDecoration(color: m.warn, borderRadius: BorderRadius.circular(3)),
            ),
          ],
        ],
      ),
    );
  }
}
