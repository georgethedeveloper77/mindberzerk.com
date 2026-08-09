/// Android device instrumentation shared by Mindberzerk apps.
///
/// The generated Pigeon types are re-exported by name rather than with a blanket
/// export. A blanket export would also leak Pigeon's internal codec class and
/// its `PigeonInstanceManager`, and once those are in the public surface a
/// generator upgrade becomes a breaking change for both apps.
library;

export 'src/cpu_load.dart';
export 'src/device_probe_api.g.dart'
    show
        BatterySnapshot,
        CpuCluster,
        CpuInfo,
        CpuSample,
        DeviceSnapshot,
        MemorySnapshot,
        ProbeCapabilities,
        SensorInfo,
        StorageAccess,
        ThermalSample,
        ThermalZone;
export 'src/device_sampler.dart';
export 'src/probe_client.dart';
