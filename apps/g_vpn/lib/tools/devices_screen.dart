import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/meridian.dart';
import '../design/sheet.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'discovery.dart';
import 'lan.dart';
import 'network_screen.dart';
import 'tool_widgets.dart';

class DeviceScanState {
  const DeviceScanState({
    this.devices = const [],
    this.done = 0,
    this.running = false,
    this.finished = false,
    this.error,
    this.fresh = const {},
  });

  final List<LanDevice> devices;

  /// Addresses not seen in the previous scan of this network.
  final Set<String> fresh;
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
      state = DeviceScanState(error: t.devices.needWifi);
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
    // Compare with the last scan of THIS network, kept on the phone only.
    final prefs = await SharedPreferences.getInstance();
    final key = 'gvpn.lan_seen.$base';
    final seen = prefs.getStringList(key);
    final now = [for (final d in devices) d.ip];
    await prefs.setStringList(key, now);
    final fresh = seen == null ? <String>{} : now.where((ip) => !seen.contains(ip)).toSet();
    if (!ref.mounted) return;
    state = DeviceScanState(devices: devices, done: 254, finished: true, fresh: fresh);
  }
}

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

/// Filter groups, in the order people look for them.
enum _Group { all, phones, tvs, computers, other }

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  _Group _group = _Group.all;
  bool _showAll = false;

  static _Group _of(LanDevice d) => switch (d.kind) {
        DeviceKind.phone => _Group.phones,
        DeviceKind.tv || DeviceKind.speaker => _Group.tvs,
        DeviceKind.computer || DeviceKind.printer => _Group.computers,
        _ => _Group.other,
      };

  @override
  void initState() {
    super.initState();
    // The page is the scan: start it on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(deviceScanProvider).finished) ref.read(deviceScanProvider.notifier).scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final scan = ref.watch(deviceScanProvider);
    final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final network = ref.watch(liveSnapshotProvider).value?.ssid;
    final counts = {for (final g in _Group.values) g: scan.devices.where((d) => g == _Group.all || _of(d) == g).length};
    final shown = scan.devices.where((d) => _group == _Group.all || _of(d) == _group).toList();
    final visible = _showAll ? shown : shown.take(8).toList();

    return ToolPage(
      title: t.devices.title,
      info: t.devices.info,
      action: FilledButton(
        onPressed: scan.running ? null : () => ref.read(deviceScanProvider.notifier).scan(),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(scan.running ? t.devices.scanning(n: scan.done) : t.devices.again),
      ),
      children: [
        LanVpnNotice(vpnOn: vpnOn),
        if (scan.error != null) Text(scan.error!, style: TextStyle(color: m.bad)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF0E1220), borderRadius: BorderRadius.circular(Meridian.rCard)),
          child: Row(
            children: [
              Text(
                scan.finished ? '${scan.devices.length}' : '${(scan.done * 100 / 254).round()}%',
                style: m.monoStyle(size: 38, weight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.finished ? t.devices.onNetwork(network: network ?? t.devices.thisNetwork) : t.devices.looking,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      scan.fresh.isEmpty
                          ? (scan.finished ? t.devices.nothingNew : t.devices.takes)
                          : t.devices.newSince(n: scan.fresh.length),
                      style: TextStyle(fontSize: 13, color: scan.fresh.isEmpty ? const Color(0xFFB7BDCC) : const Color(0xFF9DB4FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (scan.running) Padding(padding: const EdgeInsets.only(top: 8), child: LinearProgressIndicator(value: scan.done / 254, minHeight: 3)),
        if (scan.finished) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (g, label) in [
                  (_Group.all, t.devices.all),
                  (_Group.phones, t.devices.phones),
                  (_Group.tvs, t.devices.tvs),
                  (_Group.computers, t.devices.computers),
                  (_Group.other, t.devices.other),
                ])
                  if (g == _Group.all || counts[g]! > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$label ${counts[g]}'),
                        selected: _group == g,
                        onSelected: (_) => setState(() {
                          _group = g;
                          _showAll = false;
                        }),
                        showCheckmark: false,
                        selectedColor: m.text,
                        backgroundColor: m.surface,
                        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _group == g ? m.bg : m.text),
                        shape: StadiumBorder(side: BorderSide(color: _group == g ? m.text : m.line)),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              for (final d in visible) _DeviceCard(device: d, isNew: scan.fresh.contains(d.ip)),
            ],
          ),
          if (shown.length > visible.length)
            TextButton(onPressed: () => setState(() => _showAll = true), child: Text(t.devices.showMore(n: shown.length - visible.length))),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.isNew});

  final LanDevice device;
  final bool isNew;

  static IconData icon(LanDevice d) => switch (d.kind) {
        DeviceKind.phone => Icons.smartphone_rounded,
        DeviceKind.computer => Icons.laptop_rounded,
        DeviceKind.tv => Icons.tv_rounded,
        DeviceKind.speaker => Icons.speaker_rounded,
        DeviceKind.printer => Icons.print_outlined,
        DeviceKind.camera => Icons.videocam_outlined,
        DeviceKind.smartHome => Icons.lightbulb_outline_rounded,
        DeviceKind.router => Icons.router_outlined,
        DeviceKind.unknown => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final ours = device.isSelf || device.isRouter;
    final tone = ours ? m.brand : device.kind == DeviceKind.tv ? m.warn : m.text;
    final title = device.isSelf ? t.devices.thisPhone : device.name ?? (device.isRouter ? t.devices.router : t.devices.unknown);
    final sub = [if (device.model != null) device.model!, device.ip.split('.').length == 4 ? '.${device.ip.split('.').last}' : device.ip].join(' · ');
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isNew ? m.brand : m.line, width: isNew ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showInfoSheet(
          context,
          title: title,
          subtitle: device.model,
          sections: [
            SheetSection.text(t.devices.address, device.ip),
            if (device.rttMs > 0) SheetSection.text(t.devices.answersIn, t.devices.ms(n: device.rttMs.round())),
            SheetSection.text(
              t.devices.type,
              device.kind == DeviceKind.unknown
                  ? t.devices.notAnnounced
                  : device.kind.name[0].toUpperCase() + device.kind.name.substring(1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ours ? m.brandSoft : tone.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon(device), size: 22, color: tone),
                  ),
                  const Spacer(),
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: m.brand, borderRadius: BorderRadius.circular(999)),
                      child: Text(t.devices.newBadge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4, color: m.onBrand)),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: device.name == null && !ours ? m.muted : m.text),
              ),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: m.monoStyle(size: 11, color: m.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
