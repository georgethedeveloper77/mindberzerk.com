import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/app/shell.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_enter.dart';
import 'device_format.dart';
import 'device_section_page.dart';
import 'pages/cpu_page.dart';
import 'pages/display_page.dart';
import 'pages/memory_page.dart';
import 'pages/network_page.dart';
import 'pages/sim_page.dart';
import 'state/device_history.dart';
import 'state/device_providers.dart';
import 'state/identity_providers.dart';
import 'tools/screen_test_page.dart';
import 'tools/sound_test_page.dart';
import 'widgets/battery_card.dart';
import 'widgets/battery_health_strip.dart';
import 'widgets/device_index.dart';
import 'widgets/g_line_chart.dart';
import 'widgets/sensors_card.dart';
import 'widgets/system_card.dart';
import 'widgets/thermal_card.dart';
import '../../core/i18n/g_strings.dart';

/// Index of this page inside [gNavItems]. Used to decide whether the sampler
/// should be running at all.
const int kDeviceTabIndex = 2;

class DevicePage extends ConsumerStatefulWidget {
  const DevicePage({super.key});

  @override
  ConsumerState<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends ConsumerState<DevicePage>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    setState(() => _foreground = next);
  }

  /// True while this tab is the one showing.
  ///
  /// Tracked rather than only read, so leaving the tab can clear the history.
  /// Without that, coming back after ten minutes joins two separate visits into
  /// one line and draws a minute that never happened.
  bool _wasOnTab = false;

  /// Cadence is decided in one place from two independent facts: is the app in
  /// front, and is this tab the selected one.
  ///
  /// The tab check is not optional. The shell keeps every page alive in an
  /// IndexedStack, so this widget stays mounted and subscribed while the user is
  /// on Home. Without it the app polls sysfs twice a second for a screen nobody
  /// is looking at, which is the exact behaviour a device monitor has no excuse
  /// for.
  void _applyCadence({required bool onTab}) {
    final sampler = ref.read(deviceSamplerProvider);
    sampler.setPaused(value: !onTab);
    sampler.setInterval(
      _foreground ? kDeviceForegroundInterval : kDeviceBackgroundInterval,
    );
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool onTab = ref.watch(gShellTabProvider) == kDeviceTabIndex;

    // Mutating a plain object, not writing a provider, so this is safe during
    // build. Both setters early-return when nothing changed, so there is no
    // rebuild loop.
    _applyCadence(onTab: onTab);

    if (onTab != _wasOnTab) {
      _wasOnTab = onTab;
      if (!onTab) {
        // Post frame, because Riverpod forbids writing a provider during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(vitalHistoryProvider.notifier).clear();
        });
      }
    }

    final DeviceIdentity? identity = ref.watch(deviceIdentityProvider).value;

    return GPageBody(
      children: <Widget>[
        GAppBar(
          title: deviceTitle(identity),
          subtitle: identity == null
              ? null
              : '${deviceCaption(identity)}  ·  Android '
                    '${identity.androidRelease}',
        ),

        const _Live(),
        const SizedBox(height: GSpace.md + 1),

        // GType.overline rather than the GOverline widget. It lives in a file
        // this page does not import, and reaching for a widget to draw one
        // styled string is not worth an import that other screens already
        // disagree about.
        Text(
          context.s('DETAILS'),
          style: GType.overline.copyWith(color: t.dim),
        ),
        const SizedBox(height: GSpace.sm + 1),
        DeviceIndex(
          entries: _entries(
            context,
            ref.watch(deviceTickProvider).value?.current,
          ),
        ),

        const SizedBox(height: GSpace.lg),
        Text(context.s('TOOLS'), style: GType.overline.copyWith(color: t.dim)),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          onTap: () => Navigator.of(context).push(ScreenTestPage.route()),
          child: Row(
            children: <Widget>[
              Icon(Icons.grid_on_rounded, size: 20, color: t.accentText),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.s('Screen test'),
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      context.s('Dead pixels, backlight and touch response'),
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.dim),
            ],
          ),
        ),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          onTap: () => Navigator.of(context).push(SoundTestPage.route()),
          child: Row(
            children: <Widget>[
              Icon(Icons.graphic_eq_rounded, size: 20, color: t.accentText),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.s('Speakers and vibration'),
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      context.s('Each speaker on its own, and the motor'),
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.dim),
            ],
          ),
        ),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          onTap: () => Navigator.of(context).push(TouchTestPage.route()),
          child: Row(
            children: <Widget>[
              Icon(Icons.touch_app_rounded, size: 20, color: t.accentText),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.s('Touch'),
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      context.s('How many fingers the screen can follow'),
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.dim),
            ],
          ),
        ),
      ],
    );
  }
}

/// THE FOUR THINGS THAT MOVE.
///
/// CPU and battery get a full width chart because they are the two people
/// actually watch. Memory and temperature share a row underneath, because a
/// glance is enough for both and four full charts would push the index off the
/// screen entirely.
///
/// Every one of them is free. Castro puts exactly these behind a paywall, and
/// this app is already sampling all four for the card on Home, so charging for
/// them would mean charging for work already being done.
class _Live extends ConsumerWidget {
  const _Live();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<VitalSample> history = ref.watch(vitalHistoryProvider);
    final VitalSample? now = history.isEmpty ? null : history.last;

    final List<double> busy = vitalSeries(
      history,
      (VitalSample s) => s.busy == null ? null : s.busy! * 100,
    );
    final List<double> battery = vitalSeries(
      history,
      (VitalSample s) => s.batteryPercent?.toDouble(),
    );
    final List<double> memory = vitalSeries(
      history,
      (VitalSample s) => s.freeBytes == null ? null : s.freeBytes! / 1073741824,
    );
    final List<double> temp = vitalSeries(
      history,
      (VitalSample s) => s.tempDeciC == null ? null : s.tempDeciC! / 10,
    );

    return Column(
      children: <Widget>[
        if (busy.isNotEmpty)
          GEnter(
            index: 0,
            child: _Chart(
              onTap: () =>
                  Navigator.of(context).push(CpuPage.route(hue: t.video)),
              label: 'CPU',
              value: now?.busy == null
                  ? null
                  : '${(now!.busy! * 100).round()}%',
              hue: t.video,
              values: busy,
              // Fixed to the full scale. A percentage that rescales to its own
              // range makes a quiet phone look as busy as a hot one.
              minY: 0,
              maxY: 100,
            ),
          ),
        if (battery.isNotEmpty) ...<Widget>[
          const SizedBox(height: GSpace.sm + 1),
          GEnter(
            index: 1,
            child: _Chart(
              onTap: () => Navigator.of(context).push(
                DeviceSectionPage.route(
                  title: context.s('Battery'),
                  hue: t.docs,
                  icon: Icons.battery_full_rounded,
                  child: const BatteryCard(),
                ),
              ),
              label: context.s('Battery'),
              value: now?.batteryPercent == null
                  ? null
                  : '${now!.batteryPercent}%',
              hue: t.docs,
              values: battery,
              height: 58,
            ),
          ),
          // Directly under the chart it belongs to, and gone entirely on a
          // phone that reports none of the three.
          GEnter(
            index: 2,
            child: BatteryHealthStrip(
              battery: ref.watch(deviceTickProvider).value?.current.battery,
            ),
          ),
        ],
        if (memory.isNotEmpty || temp.isNotEmpty) ...<Widget>[
          const SizedBox(height: GSpace.sm + 1),
          // No stretch. This Row lives in a ListView, so its height is
          // unbounded, and a horizontal Row stretching its children on the
          // cross axis has no height to stretch to. The two cards are the same
          // shape and size themselves to match without it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (memory.isNotEmpty)
                Expanded(
                  child: GEnter(
                    index: 2,
                    child: _Chart(
                      onTap: () => Navigator.of(
                        context,
                      ).push(MemoryPage.route(hue: t.photo)),
                      label: context.s('Free memory'),
                      value: GFormat.bytesOrNull(now?.freeBytes),
                      hue: t.photo,
                      values: memory,
                      height: 44,
                      compact: true,
                    ),
                  ),
                ),
              if (memory.isNotEmpty && temp.isNotEmpty)
                const SizedBox(width: GSpace.sm + 1),
              if (temp.isNotEmpty)
                Expanded(
                  child: GEnter(
                    index: 3,
                    child: _Chart(
                      onTap: () => Navigator.of(context).push(
                        DeviceSectionPage.route(
                          title: context.s('Thermal'),
                          hue: t.audio,
                          icon: Icons.thermostat_rounded,
                          child: const ThermalCard(),
                        ),
                      ),
                      label: context.s('Temperature'),
                      value: DeviceFormat.celsiusFromDeci(now?.tempDeciC),
                      hue: t.audio,
                      values: temp,
                      height: 44,
                      compact: true,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One tinted chart card.
class _Chart extends StatelessWidget {
  const _Chart({
    required this.label,
    required this.value,
    required this.hue,
    required this.values,
    this.height = 72,
    this.minY,
    this.maxY,
    this.compact = false,
    this.onTap,
  });

  final String label;

  /// Opens the matching detail.
  ///
  /// The cards looked tappable and were not, which is worse than looking inert:
  /// a card with a border, a title and a figure is the most obvious target on
  /// the screen, and a tap that does nothing reads as the app having frozen.
  final VoidCallback? onTap;

  /// Nullable, and an absent one renders as nothing rather than a dash. A phone
  /// that will not report a figure should not be shown a placeholder for it.
  final String? value;

  final Color hue;
  final List<double> values;
  final double height;
  final double? minY;
  final double? maxY;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const <double>[0, 0.55, 1],
          colors: <Color>[
            hue.withValues(alpha: dark ? 0.42 : 0.20),
            hue.withValues(alpha: dark ? 0.29 : 0.135),
            hue.withValues(alpha: dark ? 0.16 : 0.07),
          ],
        ),
        border: Border.all(color: hue.withValues(alpha: dark ? 0.5 : 0.3)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: GRadius.all(GRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.md,
              GSpace.md,
              GSpace.md,
              GSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      label,
                      style: (compact ? GType.micro : GType.heading).copyWith(
                        color: t.text,
                      ),
                    ),
                    const Spacer(),
                    if (value != null)
                      Text(
                        value!,
                        style: GType.monoNumber.copyWith(
                          color: t.text,
                          fontSize: compact ? 17 : 22,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: GSpace.sm),
                GLineChart(
                  values: values,
                  colour: hue,
                  height: height,
                  minY: minY,
                  maxY: maxY,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The index, in the order these are actually wanted.
///
/// Not alphabetical. CPU, battery and memory are what someone opens this tab
/// for; system and access are what they open it for once, and they sit where
/// they can be found rather than where they compete.
///
/// EVERY ENTRY LEADS SOMEWHERE REAL. Codecs and DRM are the only pages from the
/// survey still missing, and they belong behind one Developer entry rather than
/// two bubbles competing with Battery for attention.
List<DeviceEntry> _entries(BuildContext context, DeviceSnapshot? now) {
  final GTokens t = context.g;

  void open(
    String title,
    Widget child, {
    required Color hue,
    required IconData icon,
    String? subtitle,
  }) {
    Navigator.of(context).push(
      DeviceSectionPage.route(
        title: title,
        hue: hue,
        icon: icon,
        subtitle: subtitle,
        child: child,
      ),
    );
  }

  return <DeviceEntry>[
    DeviceEntry(
      label: 'CPU',
      icon: Icons.memory_rounded,
      hue: t.video,
      // DeviceSnapshot.cpu is a CpuSample, not CpuInfo. A sample carries per
      // core readings and no count, so the count is the length of the list.
      value: now?.cpu?.coreKhz == null
          ? null
          : '${now!.cpu!.coreKhz.length} cores',
      open: (BuildContext c) =>
          Navigator.of(c).push(CpuPage.route(hue: t.video)),
    ),
    DeviceEntry(
      label: context.s('Battery'),
      icon: Icons.battery_full_rounded,
      hue: t.docs,
      // Health where the phone reports it, level where it does not. The more
      // interesting number wins the space.
      value: now?.battery?.stateOfHealthPercent != null
          ? '${now!.battery!.stateOfHealthPercent}% health'
          : now?.battery?.percent == null
          ? null
          : '${now!.battery!.percent}%',
      open: (BuildContext c) => open(
        'Battery',
        const BatteryCard(),
        hue: t.docs,
        icon: Icons.battery_full_rounded,
      ),
    ),
    DeviceEntry(
      label: context.s('Memory'),
      icon: Icons.grid_view_rounded,
      hue: t.photo,
      value: now?.memory?.totalBytes == null
          ? null
          : GFormat.bytes(now!.memory!.totalBytes!),
      open: (BuildContext c) =>
          Navigator.of(c).push(MemoryPage.route(hue: t.photo)),
    ),
    DeviceEntry(
      label: context.s('Thermal'),
      icon: Icons.thermostat_rounded,
      hue: t.audio,
      value: now?.battery?.tempDeciC == null
          ? null
          : '${(now!.battery!.tempDeciC! / 10).toStringAsFixed(1)} C',
      open: (BuildContext c) => open(
        'Thermal',
        const ThermalCard(),
        hue: t.audio,
        icon: Icons.thermostat_rounded,
      ),
    ),
    DeviceEntry(
      label: context.s('Display'),
      icon: Icons.smartphone_rounded,
      hue: t.chat,
      open: (BuildContext c) =>
          Navigator.of(c).push(DisplayPage.route(hue: t.chat)),
    ),
    DeviceEntry(
      label: context.s('Cameras'),
      icon: Icons.photo_camera_rounded,
      hue: t.photo,
      open: (BuildContext c) =>
          Navigator.of(c).push(CamerasPage.route(hue: t.photo)),
    ),
    DeviceEntry(
      label: context.s('Network'),
      icon: Icons.wifi_rounded,
      hue: t.video,
      open: (BuildContext c) =>
          Navigator.of(c).push(NetworkPage.route(hue: t.video)),
    ),
    DeviceEntry(
      label: 'SIM',
      icon: Icons.sim_card_outlined,
      hue: t.audio,
      open: (BuildContext c) =>
          Navigator.of(c).push(SimPage.route(hue: t.audio)),
    ),
    DeviceEntry(
      label: context.s('Bluetooth'),
      icon: Icons.bluetooth_rounded,
      hue: t.chat,
      open: (BuildContext c) =>
          Navigator.of(c).push(BluetoothPage.route(hue: t.chat)),
    ),
    DeviceEntry(
      label: context.s('Sensors'),
      icon: Icons.sensors_rounded,
      hue: t.apps,
      open: (BuildContext c) => open(
        'Sensors',
        const SensorsCard(),
        hue: t.apps,
        icon: Icons.sensors_rounded,
      ),
    ),
    DeviceEntry(
      label: context.s('System'),
      icon: Icons.android_rounded,
      hue: t.chat,
      open: (BuildContext c) => open(
        'System',
        const SystemCard(),
        hue: t.chat,
        icon: Icons.android_rounded,
      ),
    ),
    DeviceEntry(
      label: context.s('Access'),
      icon: Icons.folder_open_rounded,
      hue: t.docs,
      open: (BuildContext c) => open(
        'Storage access',
        const AccessCard(),
        hue: t.docs,
        icon: Icons.folder_open_rounded,
        subtitle: c.s('What this app is allowed to read'),
      ),
    ),
  ];
}
