import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../vpn/vpn_controller.dart';
import 'discovery.dart';
import 'lan.dart';
import 'network_screen.dart';
import 'tool_widgets.dart';

class DeviceScanState {
  const DeviceScanState({this.devices = const [], this.done = 0, this.running = false, this.finished = false, this.error});

  final List<LanDevice> devices;
  final int done;
  final bool running;
  final bool finished;
  final String? error;
}

final deviceScanProvider =
    NotifierProvider.autoDispose<DeviceScanController, DeviceScanState>(DeviceScanController.new);

class DeviceScanController extends Notifier<DeviceScanState> {
  bool _stop = false;

  @override
  DeviceScanState build() {
    ref.onDispose(() => _stop = true);
    return const DeviceScanState();
  }

  Future<void> scan() async {
    if (state.running) return;
    final snap = await ref.read(liveSnapshotProvider.future);
    final base = subnetBase(snap.gateway, snap.addresses);
    if (base == null) {
      state = const DeviceScanState(error: 'Connect to a Wi-Fi network first.');
      return;
    }
    final self = snap.addresses.where((a) => a.startsWith('$base.')).firstOrNull;
    _stop = false;
    state = const DeviceScanState(running: true);
    final devices = await scanLan(
      base: base,
      gateway: snap.gateway,
      selfIp: self,
      cancelled: () => _stop,
      onProgress: (done) {
        if (!_stop && ref.mounted) state = DeviceScanState(running: true, done: done);
      },
    );
    if (!ref.mounted) return;
    state = DeviceScanState(devices: devices, done: 254, finished: true);
  }
}

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final scan = ref.watch(deviceScanProvider);
    final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final others = scan.devices.where((d) => !d.isSelf && !d.isRouter).length;

    return ToolPage(
      title: 'Devices on this network',
      info: 'Knocks on every address in your Wi-Fi\'s range, and asks devices to announce themselves. Names come from '
          'what devices publish (Bonjour/mDNS, UPnP, Windows names) and from your router. Android hides hardware '
          'addresses from apps, so silent devices with no announced name show as unknown.',
      action: FilledButton(
        onPressed: scan.running ? null : () => ref.read(deviceScanProvider.notifier).scan(),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(scan.running ? 'Scanning ${scan.done} of 254' : (scan.finished ? 'Scan again' : 'Scan network')),
      ),
      children: [
        LanVpnNotice(vpnOn: vpnOn),
        if (scan.running) LinearProgressIndicator(value: scan.done / 254, minHeight: 3),
        if (scan.error != null) Text(scan.error!, style: TextStyle(color: m.bad)),
        if (scan.finished) ...[
          Text(
            '${scan.devices.length} devices answered',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text),
          ),
          Text(
            others == 0 ? 'Only your phone and the router.' : 'Your phone, the router and $others more.',
            style: TextStyle(fontSize: 13, color: m.muted),
          ),
          const SizedBox(height: 12),
          ToolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, d) in scan.devices.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  _DeviceRow(device: d),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final LanDevice device;

  static IconData _icon(DeviceKind kind) => switch (kind) {
        DeviceKind.phone => Icons.smartphone_rounded,
        DeviceKind.computer => Icons.laptop_rounded,
        DeviceKind.tv => Icons.tv_rounded,
        DeviceKind.speaker => Icons.speaker_rounded,
        DeviceKind.printer => Icons.print_outlined,
        DeviceKind.camera => Icons.videocam_outlined,
        DeviceKind.smartHome => Icons.lightbulb_outline_rounded,
        DeviceKind.router => Icons.router_outlined,
        DeviceKind.unknown => Icons.devices_other_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final title = device.isSelf
        ? 'This phone'
        : device.name ?? (device.isRouter ? 'Router' : 'Unknown device');
    final sub = [if (device.model != null) device.model!, device.ip].join(' · ');
    final known = device.isSelf || device.isRouter || device.name != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: device.isSelf || device.isRouter ? m.brandSoft : m.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(device.kind), size: 22, color: device.isSelf || device.isRouter ? m.brand : m.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: known ? m.text : m.muted)),
                Text(sub, style: m.monoStyle(size: 12, color: m.muted)),
              ],
            ),
          ),
          if (!device.isSelf && device.rttMs > 0)
            Text('${device.rttMs.round()} ms', style: m.monoStyle(size: 12, color: m.muted)),
        ],
      ),
    );
  }
}
