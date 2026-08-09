import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_chip.dart';
import 'state/device_providers.dart';
import 'widgets/battery_card.dart';
import 'widgets/cpu_card.dart';
import 'widgets/memory_card.dart';
import 'widgets/sensors_card.dart';
import 'widgets/thermal_card.dart';

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
    final DeviceSection section = ref.watch(deviceSectionProvider);

    // Mutating a plain object, not writing a provider, so this is safe during
    // build. Both setters early-return when nothing changed, so there is no
    // rebuild loop.
    _applyCadence(onTab: onTab);

    return GPageBody(
      children: <Widget>[
        GAppBar(title: 'Device'),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kDeviceSections.length,
            separatorBuilder: (BuildContext _, int _) =>
                const SizedBox(width: GSpace.sm - 2),
            itemBuilder: (BuildContext _, int index) {
              final DeviceSectionSpec spec = kDeviceSections[index];
              return GChip(
                label: spec.label,
                selected: spec.section == section,
                onTap: () => ref
                    .read(deviceSectionProvider.notifier)
                    .select(spec.section),
              );
            },
          ),
        ),
        const SizedBox(height: GSpace.md + 1),
        switch (section) {
          DeviceSection.cpu => const CpuCard(),
          DeviceSection.battery => const BatteryCard(),
          DeviceSection.thermal => const ThermalCard(),
          DeviceSection.memory => const MemoryCard(),
          DeviceSection.sensors => const SensorsCard(),
        },
        const SizedBox(height: GSpace.lg),
        Text(
          onTab
              ? 'Sampling at ${_foreground ? "2 Hz" : "0.5 Hz"}. Readings this '
                  'device refuses are named rather than hidden.'
              : 'Paused.',
          style: GType.micro.copyWith(color: t.dim),
        ),
      ],
    );
  }
}
