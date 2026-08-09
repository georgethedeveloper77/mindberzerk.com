import 'package:device_probe/device_probe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 2 Hz while the tab is visible and the app is foregrounded.
///
/// Fast enough that a frequency bar looks live, slow enough that the platform
/// thread is idle between reads. Anything above this and a budget device spends
/// measurable battery watching itself.
const Duration kDeviceForegroundInterval = Duration(milliseconds: 500);

/// 0.5 Hz when the app is backgrounded but the tab is still the selected one.
/// Keeps the deltas warm so returning to the app shows a live figure rather
/// than a pending one.
const Duration kDeviceBackgroundInterval = Duration(seconds: 2);

final Provider<DeviceProbe> deviceProbeProvider =
    Provider<DeviceProbe>((Ref ref) => DeviceProbe());

/// Probed once natively and cached for the process, so this is cheap to watch
/// from every card.
final FutureProvider<ProbeCapabilities?> deviceCapabilitiesProvider =
    FutureProvider<ProbeCapabilities?>(
  (Ref ref) => ref.watch(deviceProbeProvider).capabilities(),
);

final FutureProvider<CpuInfo?> cpuInfoProvider = FutureProvider<CpuInfo?>(
  (Ref ref) => ref.watch(deviceProbeProvider).cpuInfo(),
);

final FutureProvider<List<SensorInfo>> sensorListProvider =
    FutureProvider<List<SensorInfo>>(
  (Ref ref) => ref.watch(deviceProbeProvider).sensors(),
);

/// The sampler is created paused.
///
/// Deliberate: the shell builds every tab up front in an IndexedStack, so this
/// provider is constructed the moment the app opens even when the user never
/// leaves Home. Starting paused means nothing polls sysfs until the Device page
/// says it is visible.
final Provider<DeviceSampler> deviceSamplerProvider =
    Provider<DeviceSampler>((Ref ref) {
  final DeviceSampler sampler = DeviceSampler(
    probe: ref.watch(deviceProbeProvider),
    interval: kDeviceForegroundInterval,
  );
  sampler.setPaused(value: true);
  ref.onDispose(sampler.dispose);
  return sampler;
});

final StreamProvider<ProbeTick> deviceTickProvider = StreamProvider<ProbeTick>(
  (Ref ref) => ref.watch(deviceSamplerProvider).ticks,
);

/// Which section of the Device tab is showing.
enum DeviceSection { cpu, battery, thermal, memory, sensors }

class DeviceSectionController extends Notifier<DeviceSection> {
  @override
  DeviceSection build() => DeviceSection.cpu;

  void select(DeviceSection section) {
    if (section == state) return;
    state = section;
  }
}

final NotifierProvider<DeviceSectionController, DeviceSection>
    deviceSectionProvider =
    NotifierProvider<DeviceSectionController, DeviceSection>(
  DeviceSectionController.new,
);

@immutable
class DeviceSectionSpec {
  const DeviceSectionSpec(this.section, this.label);

  final DeviceSection section;
  final String label;
}

const List<DeviceSectionSpec> kDeviceSections = <DeviceSectionSpec>[
  DeviceSectionSpec(DeviceSection.cpu, 'CPU'),
  DeviceSectionSpec(DeviceSection.battery, 'Battery'),
  DeviceSectionSpec(DeviceSection.thermal, 'Thermal'),
  DeviceSectionSpec(DeviceSection.memory, 'Memory'),
  DeviceSectionSpec(DeviceSection.sensors, 'Sensors'),
];
