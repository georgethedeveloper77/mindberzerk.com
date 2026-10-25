import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import '../design/country_map.dart';
import '../design/meridian.dart';
import '../design/theme_mode.dart';
import '../design/wifi_name_prompt.dart';
import '../design/world_map.dart' show LatLon;
import '../i18n/strings.g.dart';
import '../rules/apps_screen.dart';
import '../rules/rules_store.dart';
import '../servers/community.dart';
import '../tools/speed_screen.dart';
import '../tools/tools_providers.dart' show directSpeedProvider;
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'connect_card.dart';
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

  /// How far the connection card rises into the map.
  static const _overlap = 56.0;

  /// Header 56, status line, clock and IP chip: the band at the top of the
  /// map that the camera keeps clear.
  static const _overlayBand = 56.0 + 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final on = vpn.phase == VpnPhase.on;
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final paused = vpn.pausedUntil != null;
    final top = MediaQuery.paddingOf(context).top;
    final mapHeight = (MediaQuery.sizeOf(context).height * .52).clamp(380.0, 480.0) + top;

    Future<void> connect() => connectFromHome(ref, openServers: openServers);

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

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight,
            child: _HomeMap(
              framePadding: EdgeInsets.fromLTRB(24, top + _overlayBand, 24, _overlap + 12),
            ),
          ),
          // Fades the map into the page so the card sits on calm ground.
          Positioned(
            top: mapHeight - 120,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [m.bg.withValues(alpha: 0), m.bg],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: mapHeight - _overlap,
                child: Padding(
                  padding: EdgeInsets.only(top: top),
                  child: Column(
                    children: [
                      _Header(onPro: openPro),
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
                        TextButton(
                          onPressed: () => ref.read(vpnProvider.notifier).resume(),
                          style: TextButton.styleFrom(foregroundColor: m.muted, minimumSize: const Size(48, 36)),
                          child: Text(
                            t.home.resumesAt(time: TimeOfDay.fromDateTime(vpn.pausedUntil!).format(context)),
                            style: const TextStyle(fontSize: 13),
                          ),
                        )
                      else if (on)
                        _Clock(since: vpn.connectedAt),
                      const SizedBox(height: 8),
                      _IpChip(onTap: () => showIpSheet(context, onHide: connect)),
                      if (vpn.error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Text(vpn.error!, textAlign: TextAlign.center, style: TextStyle(color: m.bad, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HomeConnectCard(openServers: openServers),
              ),
              if (!on) ...[
                const SizedBox(height: 10),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _ScanCard()),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Tiles(openRules: openRules, openTools: openTools),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The map, fed from the VPN state, the IP lookups and the free list.
class _HomeMap extends ConsumerWidget {
  const _HomeMap({required this.framePadding});

  final EdgeInsets framePadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final choice = ref.watch(tunnelsProvider).value?.choice;
    final id = ref.watch(identityProvider).value;
    final home = ref.watch(homeLocationProvider);
    final servers = ref.watch(communityProvider).value?.servers ?? const [];
    final on = phase == VpnPhase.on;
    final idCountry = id?.country != null && id!.country!.length == 2 ? id.country!.toUpperCase() : null;

    // Community servers sit at their country's centre the moment we
    // connect; your own servers wherever the lookup through them lands.
    final centre = choice?.countryCode == null ? null : countryCentres[choice!.countryCode!.toUpperCase()];
    final server = !on
        ? null
        : centre != null
            ? LatLon(centre.$1, centre.$2)
            : id?.latitude != null && id?.longitude != null
                ? LatLon(id!.latitude!, id.longitude!)
                : null;

    // One dot per country with a free server.
    final dots = <LatLon>[
      for (final code in {for (final s in servers) s.countryCode.toUpperCase()})
        if (countryCentres[code] case final c?) LatLon(c.$1, c.$2),
    ];

    return CountryMap(
      mood: switch (phase) {
        VpnPhase.on => MapMood.protected,
        VpnPhase.connecting || VpnPhase.disconnecting => MapMood.connecting,
        VpnPhase.off => MapMood.exposed,
      },
      you: home,
      // Exposed, the lookup is the user's own; protected, it is the server's.
      youCountry: on ? null : idCountry,
      server: server,
      serverCountry: choice?.countryCode ?? (on ? idCountry : null),
      dots: dots,
      framePadding: framePadding,
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
  const _Header({required this.onPro});

  final VoidCallback onPro;

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
  const _Chip({required this.chip, this.good = false});

  final ScanChip chip;

  /// Protected-state chips: tinted with the "secure" colour.
  final bool good;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (bg, fg) = good
        ? (m.good.withValues(alpha: .10), m.good)
        : switch (chip.tone) {
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
          sub: rules.shield ? t.home.tiles.shieldOn : t.common.off,
          accessory: _Switch(on: rules.shield),
          onTap: () => ref.read(rulesProvider.notifier).setShield(!rules.shield),
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
