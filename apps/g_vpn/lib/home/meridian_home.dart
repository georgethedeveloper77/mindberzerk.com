import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/connect_button.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/world_map.dart';
import '../design/meridian.dart';
import '../design/theme_mode.dart';
import '../design/wifi_name_prompt.dart';
import '../design/waves.dart';
import '../rules/rules_store.dart';
import '../tools/speed_screen.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'home_scan.dart';

/// Meridian home. The dotted world fills the whole page and the connect
/// button sits on the user's own location: raw traffic waves in from the
/// left, tunnel output leaves to the right.
class MeridianHome extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<MeridianHome> createState() => _MeridianHomeState();
}

class _MeridianHomeState extends ConsumerState<MeridianHome> {
  final _scroll = ScrollController();

  /// Header 56 + server chip 44 + gap 4 + half the hero. The map is pinned
  /// to this point, so the button always sits on "you".
  static const _buttonY = 56 + 44 + 4 + _Hero.height / 2;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final tunnels = ref.watch(tunnelsProvider).value;
    final choice = tunnels?.choice;
    final identity = ref.watch(identityProvider);
    final home = ref.watch(homeLocationProvider);
    final on = vpn.phase == VpnPhase.on;
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final top = MediaQuery.paddingOf(context).top;

    // Once protected, the lookup answers from the server, so its position is
    // the second pin. Before that there is only "you".
    final id = identity.value;
    // Community servers: their country's centre, known the moment we connect.
    // Your own servers: wherever the IP lookup places them.
    final centre = choice?.countryCode == null ? null : countryCentres[choice!.countryCode!.toUpperCase()];
    final server = !on
        ? null
        : centre != null
            ? LatLon(centre.$1, centre.$2)
            : id?.latitude != null && id?.longitude != null
                ? LatLon(id!.latitude!, id.longitude!)
                : null;

    void tapConnect() {
      final controller = ref.read(vpnProvider.notifier);
      if (on) {
        controller.disconnect();
      } else if (choice == null) {
        widget.openServers();
      } else if (!busy) {
        controller.connect(choice);
      }
    }

    final statusColor = on && vpn.reconnecting ? m.warn : on ? m.good : busy ? m.warn : m.bad;
    final status = switch (vpn.phase) {
      VpnPhase.on => vpn.reconnecting ? 'Reconnecting' : 'Protected',
      VpnPhase.connecting => 'Connecting',
      VpnPhase.disconnecting => 'Stopping',
      VpnPhase.off => 'Not protected',
    };

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _scroll,
              builder: (context, child) => MeridianWorldMap(
                anchor: Offset(
                  box.maxWidth / 2,
                  top + _buttonY - (_scroll.hasClients ? _scroll.offset : 0),
                ),
                scrolling: busy,
                user: home,
                server: server,
                userColor: on ? m.brand : m.bad,
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _Header(onPro: widget.openPro),
                _ServerChip(choice: choice, onTap: widget.openServers),
                const SizedBox(height: 4),
                _Hero(phase: vpn.phase, onTap: tapConnect),
                Text(status, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5, color: statusColor)),
                _Clock(since: on ? vpn.connectedAt : null),
                const SizedBox(height: 6),
                _IpPill(
                  text: switch (identity) {
                    AsyncData(:final value) => 'Sites see ${value.ip}${value.org == null ? '' : ' · ${value.org}'}',
                    AsyncError() => 'Could not check your IP',
                    _ => 'Checking your IP',
                  },
                  color: on ? m.good : m.bad,
                ),
                if (vpn.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Text(vpn.error!, textAlign: TextAlign.center, style: TextStyle(color: m.bad, fontSize: 13)),
                  ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: on && choice != null ? _ConnectionCard(choice: choice, vpn: vpn) : const _ScanCard(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Tiles(openRules: widget.openRules, openTools: widget.openTools),
                ),
              ],
            ),
          ),
        ),
      ],
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
      ThemeMode.system => (Icons.brightness_auto_rounded, ThemeMode.light, 'Theme: follows phone'),
      ThemeMode.light => (Icons.light_mode_rounded, ThemeMode.dark, 'Theme: light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, ThemeMode.system, 'Theme: dark'),
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
                  child: Text('Free', style: TextStyle(color: m.brand, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.choice, required this.onTap});

  final ServerChoice? choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final c = choice;
    return Material(
      color: m.surface,
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
                if (c?.countryCode != null) ...[CountryFlag(c!.countryCode!, width: 22), const SizedBox(width: 8)],
                Text(
                  c == null ? 'Pick a server' : c.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_more_rounded, size: 18, color: m.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.phase, required this.onTap});

  final VpnPhase phase;
  final VoidCallback onTap;

  static const height = 200.0;
  static const _button = 128.0;
  static const _buttonOn = 96.0;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final on = phase == VpnPhase.on;
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final rightMood = on ? WaveMood.secure : busy ? WaveMood.securing : WaveMood.exposed;
    final rightLabel = on ? 'ENCRYPTED' : busy ? 'SECURING' : 'EXPOSED';
    final rightColor = on ? m.good : busy ? m.warn : m.bad;
    final labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8, color: m.bad);

    // FULL WIDTH, explicitly. A Stack sizes itself to its non-positioned
    // children, so without this the hero shrank to the button's 128 dp and
    // the waves and labels were laid out underneath the button.
    return SizedBox(
      width: double.infinity,
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          // Each wave runs from the screen edge to just under the button.
          final side = (box.maxWidth - _button) / 2 + 10;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                width: side,
                top: height / 2 - 36,
                child: const MeridianWaves(mood: WaveMood.exposed, fadeFromLeft: true),
              ),
              Positioned(
                right: 0,
                width: side,
                top: height / 2 - 36,
                child: MeridianWaves(mood: rightMood, fadeFromLeft: false),
              ),
              Positioned(left: 14, top: height / 2 + 40, child: Text('EXPOSED', style: labelStyle)),
              Positioned(
                right: 14,
                top: height / 2 + 40,
                child: Text(rightLabel, style: labelStyle.copyWith(color: rightColor)),
              ),
              // Smaller once protected, so the server's country reads
              // around it on the zoomed map.
              TweenAnimationBuilder<double>(
                tween: Tween(end: on ? _buttonOn : _button),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                builder: (_, size, __) => ConnectButton(phase: phase, onTap: onTap, size: size),
              ),
            ],
          );
        },
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

class _IpPill extends StatelessWidget {
  const _IpPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: m.line),
      ),
      child: Text(text, style: m.monoStyle(size: 12, color: color)),
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
                    Text('THIS NETWORK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6, color: m.muted)),
                    const SizedBox(height: 2),
                    Text(
                      value?.name ?? (value?.nameHidden == true ? 'Wi-Fi' : 'Offline'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text),
                    ),
                  ],
                ),
              ),
              if (value?.nameHidden == true)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 40), foregroundColor: m.brand),
                  onPressed: () => askForWifiNames(context, ref),
                  child: const Text('Show name'),
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
            AsyncError() => Text('Scan failed. It runs again when the network changes.',
                style: TextStyle(color: m.muted, fontSize: 13)),
            _ => const LinearProgressIndicator(minHeight: 2),
          },
        ],
      ),
    );
  }
}

/// Replaces "This network" while protected: what the connection IS now,
/// rather than the local network it is hiding.
class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.choice, required this.vpn});

  final ServerChoice choice;
  final VpnState vpn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final shield = ref.watch(rulesProvider.select((r) => r.value?.shield ?? true));
    final protocol = switch (choice) {
      OwnServer() => 'WireGuard',
      CommunityChoice(:final server) => 'OpenVPN ${server.proto.toUpperCase()}',
    };
    Widget pair(ScanChip a, ScanChip b) => Row(
          children: [
            Expanded(child: _Chip(chip: a, good: true)),
            const SizedBox(width: 6),
            Expanded(child: _Chip(chip: b, good: true)),
          ],
        );
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
          Text('CONNECTED VIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6, color: m.muted)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (choice.countryCode != null) ...[CountryFlag(choice.countryCode!, width: 24), const SizedBox(width: 8)],
              Expanded(
                child: Text(choice.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          pair(
            ScanChip('PROTOCOL', protocol, Tone.ok),
            ScanChip('DNS', shield ? 'Quad9, in tunnel' : 'Server, in tunnel', Tone.ok),
          ),
          const SizedBox(height: 6),
          pair(
            ScanChip('DOWNLOADED', _bytes(vpn.rxBytes), Tone.ok),
            ScanChip('UPLOADED', _bytes(vpn.txBytes), Tone.ok),
          ),
        ],
      ),
    );
  }

  static String _bytes(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
    final rules = ref.watch(rulesProvider).value ?? const RulesState();
    final auto = switch (rules.autoConnect) {
      AutoConnectChoice.off => 'Off',
      AutoConnectChoice.open => 'Public Wi-Fi',
      AutoConnectChoice.any => 'Every Wi-Fi',
    };
    Widget row(Widget a, Widget b) => Row(
          children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
        );
    return Column(
      children: [
        row(
          _Tile(
            name: 'Shield',
            sub: rules.shield ? 'Malware sites blocked' : 'Off',
            on: rules.shield,
            onTap: () => ref.read(rulesProvider.notifier).setShield(!rules.shield),
          ),
          _Tile(
            name: 'Apps direct',
            sub: rules.excluded.isEmpty ? 'None' : '${rules.excluded.length} apps skip the VPN',
            on: rules.excluded.isNotEmpty,
            onTap: openRules,
          ),
        ),
        const SizedBox(height: 10),
        row(
          _Tile(name: 'Auto-connect', sub: auto, on: rules.autoConnect != AutoConnectChoice.off, onTap: openRules),
          _Tile(
            name: 'Speed test',
            sub: 'Check this connection',
            on: false,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SpeedScreen())),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.name, required this.sub, required this.on, required this.onTap});

  final String name;
  final String sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = on ? m.onBrand : m.text;
    return Material(
      color: on ? m.brand : m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rTile),
        side: BorderSide(color: on ? Colors.transparent : m.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Meridian.rTile),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shrinks rather than breaking "Auto-connect" at its hyphen.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(name, maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: .85))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
