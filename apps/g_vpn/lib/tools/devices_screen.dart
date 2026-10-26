import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/meridian.dart';
import '../alerts/alerts.dart';
import '../design/list_ui.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../providers/internet_tab.dart';
import '../vpn/vpn_controller.dart';
import 'device_memory.dart';
import 'device_type_screen.dart';
import 'discovery.dart';
import 'lan.dart';
import 'network_mesh.dart';
import 'network_screen.dart';
import 'ping_screen.dart';
import 'ports_screen.dart';
import 'probe.dart';
import 'security_check.dart';
import 'security_tab.dart';
import 'tool_widgets.dart';

class DeviceScanState {
  const DeviceScanState({
    this.devices = const [],
    this.done = 0,
    this.running = false,
    this.finished = false,
    this.error,
    this.fresh = const {},
    this.network,
  });

  final List<LanDevice> devices;

  /// Addresses not seen in the previous scan of this network.
  final Set<String> fresh;
  final int done;
  final bool running;
  final bool finished;
  final String? error;

  /// The Wi-Fi name the scan ran on, the key devices are remembered under.
  final String? network;
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
    final network = snap.ssid;
    final self = snap.addresses.where((a) => a.startsWith('$base.')).firstOrNull;
    _stop = false;
    state = DeviceScanState(running: true, network: network);
    final found = await scanLan(
      base: base,
      gateway: snap.gateway,
      selfIp: self,
      cancelled: () => _stop,
      onProgress: (done) {
        if (!_stop && ref.mounted) state = DeviceScanState(running: true, done: done, network: network);
      },
    );
    if (!ref.mounted) return;
    // A device nobody named that serves a video stream (RTSP) is almost
    // always a camera.
    final devices = await pooled(found, 16, (d) async {
      if (d.kind != DeviceKind.unknown || d.isSelf || d.isRouter) return d;
      if (!await isOpen(d.ip, 554, timeout: const Duration(milliseconds: 600))) return d;
      return LanDevice(ip: d.ip, rttMs: d.rttMs, name: d.name, model: d.model, kind: DeviceKind.camera);
    });
    if (!ref.mounted) return;
    // Compare with the last scan of THIS network, kept on the phone only.
    final prefs = await SharedPreferences.getInstance();
    final key = 'gvpn.lan_seen.$base';
    final seen = prefs.getStringList(key);
    final now = [for (final d in devices) d.ip];
    await prefs.setStringList(key, now);
    final fresh = seen == null ? <String>{} : now.where((ip) => !seen.contains(ip)).toSet();
    await ref.read(deviceMemoryProvider.notifier).recordScan(network, devices);
    if (fresh.isNotEmpty) {
      final names = [for (final d in devices.where((d) => fresh.contains(d.ip))) d.name ?? d.ip];
      await ref.read(alertsProvider.notifier).add(
            AlertKind.newDevice,
            title: t.alerts.newDeviceTitle(n: fresh.length, network: network ?? t.alerts.thisNetwork),
            body: names.take(3).join(', '),
            route: '/hub',
          );
    }
    if (!ref.mounted) return;
    state = DeviceScanState(devices: devices, done: 254, finished: true, fresh: fresh, network: network);
  }
}

/// Filter groups, in the order people look for them.
enum _Group { all, phones, tvs, computers, cameras, other }

/// Names the user gave devices, per network ("HomeNet|192.168.1.57").
/// Keyed by address: Android hides hardware addresses, so a device that
/// gets a new address from the router loses its name.
final deviceNamesProvider = AsyncNotifierProvider<DeviceNames, Map<String, String>>(DeviceNames.new);

class DeviceNames extends AsyncNotifier<Map<String, String>> {
  static const _key = 'gvpn.device_names.v1';

  @override
  Future<Map<String, String>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw);
      return j is Map ? {for (final e in j.entries) if (e.value is String) '${e.key}': e.value as String} : const {};
    } on FormatException {
      return const {};
    }
  }

  Future<void> set(String key, String? name) async {
    final next = {...await future};
    if (name == null || name.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = name.trim();
    }
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(next));
  }
}

IconData deviceIcon(DeviceKind kind) => switch (kind) {
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

Color deviceColor(DeviceKind kind, Meridian m) => switch (kind) {
      DeviceKind.phone => m.brand,
      DeviceKind.computer => m.teal,
      DeviceKind.tv || DeviceKind.speaker => m.violet,
      DeviceKind.camera => m.warn,
      DeviceKind.smartHome => m.teal,
      DeviceKind.router => m.good,
      DeviceKind.printer || DeviceKind.unknown => m.muted,
    };

String deviceKindName(DeviceKind kind) => switch (kind) {
      DeviceKind.phone => t.devices.kinds.phone,
      DeviceKind.computer => t.devices.kinds.computer,
      DeviceKind.tv => t.devices.kinds.tv,
      DeviceKind.speaker => t.devices.kinds.speaker,
      DeviceKind.printer => t.devices.kinds.printer,
      DeviceKind.camera => t.devices.kinds.camera,
      DeviceKind.smartHome => t.devices.kinds.smartHome,
      DeviceKind.router => t.devices.kinds.router,
      DeviceKind.unknown => t.devices.kinds.unknown,
    };

/// The type to show: the user's correction, else what was detected.
DeviceKind kindOf(LanDevice d, DeviceMemory? mem, String? network) =>
    mem?.kinds[deviceKey(network, d.ip)] ?? (d.isSelf ? DeviceKind.phone : d.kind);

String deviceTitle(LanDevice d, String? given) =>
    given ?? (d.isSelf ? t.devices.thisPhone : d.name ?? (d.isRouter ? t.devices.router : t.devices.unknown));

/// "5 min ago", "3 h ago", "2 d ago".
String agoText(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inHours < 1) return t.devices.agoMinutes(n: d.inMinutes.clamp(1, 59));
  if (d.inDays < 1) return t.devices.agoHours(n: d.inHours);
  return t.devices.agoDays(n: d.inDays);
}

/// The network hub's Devices view: everything on this Wi-Fi, as a list or
/// as a mesh around the router, with the ones that left shown greyed.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  _Group _group = _Group.all;
  bool _mesh = false;

  static _Group _of(DeviceKind k) => switch (k) {
        DeviceKind.phone => _Group.phones,
        DeviceKind.tv || DeviceKind.speaker => _Group.tvs,
        DeviceKind.computer || DeviceKind.printer => _Group.computers,
        DeviceKind.camera => _Group.cameras,
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
    final snap = ref.watch(liveSnapshotProvider).value;
    final mem = ref.watch(deviceMemoryProvider).value;
    final network = scan.network ?? snap?.ssid;

    // Devices seen here before but not in this scan: listed greyed.
    final present = {for (final d in scan.devices) d.ip};
    final offline = scan.finished
        ? ((mem?.known[network ?? 'lan']?.values ?? const <KnownDevice>[]).where((k) => !present.contains(k.ip)).toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen)))
        : const <KnownDevice>[];
    final toConfirm = scan.devices
        .where((d) => !d.isSelf && !d.isRouter && mem?.mine[deviceKey(network, d.ip)] == null)
        .length;
    final counts = {
      for (final g in _Group.values) g: scan.devices.where((d) => g == _Group.all || _of(kindOf(d, mem, network)) == g).length,
    };
    final shown = scan.devices.where((d) => _group == _Group.all || _of(kindOf(d, mem, network)) == _group).toList();

    final mhz = snap?.frequencyMhz;
    final facts = [
      if (snap?.transport == Transport.wifi) ...[
        switch (snap?.wifiSecurity) {
          WifiSecurity.wpa3 => 'WPA3',
          WifiSecurity.wpa2 => 'WPA2',
          WifiSecurity.open => t.scan.open,
          WifiSecurity.wep => t.scan.wep,
          _ => null,
        },
        if (mhz != null) mhz >= 5925 ? '6 GHz' : mhz >= 4900 ? '5 GHz' : '2.4 GHz',
      ],
    ].whereType<String>().toList();

    final scanButton = FilledButton(
      onPressed: scan.running ? null : () => ref.read(deviceScanProvider.notifier).scan(),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: m.good, foregroundColor: m.bg),
      child: Text(scan.running ? t.devices.scanning(n: scan.done) : t.devices.again),
    );
    final checkButton = FilledButton(
      onPressed: () => ref.invalidate(securityReportProvider),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: m.good, foregroundColor: m.bg),
      child: Text(t.security.checkAgain),
    );
    final score = ref.watch(securityReportProvider).value;

    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        final tabs = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: ToolTitle(title: network ?? t.devices.title, icon: Icons.wifi_rounded, color: m.good),
            centerTitle: false,
            actions: [
              if (score != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(child: ScoreChip(score: score.score)),
                ),
              IconButton(
                tooltip: t.devices.details,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NetworkScreen())),
                icon: Icon(Icons.tune_rounded, color: m.text),
              ),
              InfoAction(title: t.devices.title, body: t.devices.info),
            ],
            bottom: TabBar(
              labelColor: m.good,
              unselectedLabelColor: m.muted,
              indicatorColor: m.good,
              labelStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w800),
              tabs: [Tab(text: t.devices.title), Tab(text: t.security.tab), Tab(text: t.providers.tab)],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
        if (facts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(facts.join(' · '), style: TextStyle(fontSize: 13, color: m.muted)),
          ),
        LanVpnNotice(vpnOn: vpnOn),
        if (scan.error != null) Text(scan.error!, style: TextStyle(color: m.bad)),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.format_list_bulleted_rounded, size: 18), label: Text(t.devices.listView)),
            ButtonSegment(value: true, icon: const Icon(Icons.hub_outlined, size: 18), label: Text(t.devices.meshView)),
          ],
          selected: {_mesh},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _mesh = v.first),
        ),
        const SizedBox(height: 12),
        if (scan.running) ...[
          Row(
            children: [
              Expanded(
                child: Text(t.devices.looking, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: m.text)),
              ),
              Text('${(scan.done * 100 / 254).round()}%', style: m.monoStyle(size: 12, color: m.muted)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: scan.done / 254, minHeight: 6, borderRadius: BorderRadius.circular(3), color: m.good),
          const SizedBox(height: 12),
        ],
        if (scan.finished) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(text: t.devices.onlineCount(n: scan.devices.length), color: m.good),
              if (offline.isNotEmpty) _Tag(text: t.devices.offlineCount(n: offline.length), color: m.muted),
              if (toConfirm > 0) _Tag(text: t.devices.toConfirm(n: toConfirm), color: m.warn),
              if (scan.fresh.isNotEmpty) _Tag(text: t.devices.newSince(n: scan.fresh.length), color: m.warn),
            ],
          ),
          const SizedBox(height: 12),
          if (_mesh)
            NetworkMesh(devices: scan.devices, offline: offline, fresh: scan.fresh, network: network)
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (g, label) in [
                    (_Group.all, t.devices.all),
                    (_Group.phones, t.devices.phones),
                    (_Group.tvs, t.devices.tvs),
                    (_Group.computers, t.devices.computers),
                    (_Group.cameras, t.devices.cameras),
                    (_Group.other, t.devices.other),
                  ])
                    if (g == _Group.all || counts[g]! > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$label ${counts[g]}'),
                          selected: _group == g,
                          onSelected: (_) => setState(() => _group = g),
                          showCheckmark: false,
                          selectedColor: (g == _Group.cameras ? m.warn : m.good).withValues(alpha: .16),
                          backgroundColor: m.surface,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _group == g ? (g == _Group.cameras ? m.warn : m.good) : m.text,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(color: _group == g ? (g == _Group.cameras ? m.warn : m.good) : m.line),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            MerCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, d) in shown.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 64, color: m.line),
                    DeviceRow(device: d, isNew: scan.fresh.contains(d.ip), network: network),
                  ],
                ],
              ),
            ),
            if (offline.isNotEmpty && _group == _Group.all) ...[
              ToolHeading(t.devices.offlineHeading),
              MerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, k) in offline.indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 64, color: m.line),
                      DeviceRow(device: k.asLan, isNew: false, network: network, lastSeen: k.lastSeen),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
                      ],
                    ),
                    SecurityTab(openDevices: () => tabs.animateTo(0)),
                    const InternetTab(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: tabs,
                      builder: (_, __) => switch (tabs.index) {
                        0 => scanButton,
                        1 => checkButton,
                        _ => const InternetActions(),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// One device: what it is, its name, its maker or model, its address.
/// Devices that left the network ([lastSeen]) are greyed.
class DeviceRow extends ConsumerWidget {
  const DeviceRow({super.key, required this.device, required this.isNew, required this.network, this.lastSeen});

  final LanDevice device;
  final bool isNew;
  final String? network;
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final key = deviceKey(network, device.ip);
    final given = ref.watch(deviceNamesProvider).value?[key];
    final mem = ref.watch(deviceMemoryProvider).value;
    final kind = kindOf(device, mem, network);
    final color = deviceColor(kind, m);
    final online = lastSeen == null;
    final mine = mem?.mine[key];
    final sub = [
      device.model ?? deviceKindName(kind),
      if (!online) t.devices.seen(when: agoText(lastSeen!)),
    ].join(' · ');
    return Opacity(
      opacity: online ? 1 : .5,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DeviceScreen(device: device, isNew: isNew, network: network, lastSeen: lastSeen),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                    child: Icon(deviceIcon(kind), size: 19, color: color),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: online ? m.good : m.muted,
                        shape: BoxShape.circle,
                        border: Border.all(color: m.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            deviceTitle(device, given),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: given == null && device.name == null && !device.isSelf && !device.isRouter ? m.muted : m.text,
                            ),
                          ),
                        ),
                        if (isNew) ...[const SizedBox(width: 6), _Tag(text: t.devices.newBadge, color: m.warn)],
                        if (mine == true) ...[const SizedBox(width: 6), Icon(Icons.check_rounded, size: 15, color: m.good)],
                        if (mine == false) ...[const SizedBox(width: 6), Icon(Icons.warning_amber_rounded, size: 15, color: m.bad)],
                      ],
                    ),
                    Text(sub, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: TextStyle(fontSize: 12, color: m.muted)),
                  ],
                ),
              ),
              Text('.${device.ip.split('.').last}', style: m.monoStyle(size: 12, color: m.muted)),
              Icon(Icons.chevron_right_rounded, color: m.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

/// A device's page: what it is, whether it is yours, what it serves, and
/// what to do next.
class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key, required this.device, required this.isNew, required this.network, this.lastSeen});

  final LanDevice device;
  final bool isNew;
  final String? network;

  /// Set for a device that has left the network.
  final DateTime? lastSeen;

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  /// The common services this device answers on, checked once on open.
  late final Future<List<KnownPort>> _services = widget.lastSeen != null
      ? Future.value(const <KnownPort>[])
      : pooled(
          knownPorts,
          6,
          (p) async => await isOpen(widget.device.ip, p.port, timeout: const Duration(milliseconds: 800)) ? p : null,
        ).then((found) => found.whereType<KnownPort>().toList());

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final d = widget.device;
    final key = deviceKey(widget.network, d.ip);
    final given = ref.watch(deviceNamesProvider).value?[key];
    final mem = ref.watch(deviceMemoryProvider).value;
    final kind = kindOf(d, mem, widget.network);
    final mine = mem?.mine[key];
    final color = deviceColor(kind, m);
    final title = deviceTitle(d, given);
    final online = widget.lastSeen == null;

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    Future<void> rename() async {
      final name = await askText(context, title: t.devices.rename, action: t.devices.save, initial: title);
      if (name != null) await ref.read(deviceNamesProvider.notifier).set(key, name);
    }

    Widget ownership(bool value, String label, IconData icon, Color tone) {
      final on = mine == value;
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: () => ref.read(deviceMemoryProvider.notifier).setMine(key, on ? null : value),
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: on ? tone : m.text,
            backgroundColor: on ? tone.withValues(alpha: .14) : null,
            side: BorderSide(color: on ? tone : m.line, width: on ? 1.5 : 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return ToolPage(
      title: t.devices.device,
      icon: deviceIcon(kind),
      color: color,
      children: [
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(24)),
            child: Icon(deviceIcon(kind), size: 36, color: color),
          ),
        ),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isNew) ...[_Tag(text: t.devices.newBadge, color: m.warn), const SizedBox(width: 6)],
            _Tag(
              text: online ? t.devices.online : t.devices.seen(when: agoText(widget.lastSeen!)),
              color: online ? m.good : m.muted,
            ),
          ],
        ),
        if (!d.isSelf && !d.isRouter) ...[
          const SizedBox(height: 16),
          MerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.devices.yours, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ownership(true, t.devices.mine, Icons.check_rounded, m.good),
                    const SizedBox(width: 8),
                    ownership(false, t.devices.notMine, Icons.warning_amber_rounded, m.bad),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        MerCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              MerRow(t.devices.address, d.ip, mono: true),
              InkWell(
                onTap: () => open(DeviceTypeScreen(device: d, network: widget.network)),
                child: Row(
                  children: [
                    Expanded(child: MerRow(t.devices.type, deviceKindName(kind))),
                    Icon(Icons.chevron_right_rounded, size: 18, color: m.muted),
                  ],
                ),
              ),
              if (d.model != null) MerRow(t.devices.model, d.model!),
              if (given != null && d.name != null) MerRow(t.devices.announced, d.name!),
              if (d.rttMs > 0) MerRow(t.devices.answersIn, t.devices.ms(n: d.rttMs.round()), mono: true),
            ],
          ),
        ),
        if (online) ...[
          ToolHeading(t.devices.services),
          FutureBuilder<List<KnownPort>>(
            future: _services,
            builder: (_, snap) {
              if (!snap.hasData) {
                return Row(children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: m.muted)),
                  const SizedBox(width: 10),
                  Text(t.devices.checkingServices, style: TextStyle(fontSize: 13, color: m.muted)),
                ]);
              }
              final open = snap.data!;
              if (open.isEmpty) return Text(t.devices.noServices, style: TextStyle(fontSize: 13, color: m.muted));
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in open)
                    _Tag(
                      text: '${p.port} · ${p.service}',
                      color: switch (p.risk) { PortRisk.risky => m.bad, PortRisk.review => m.warn, PortRisk.normal => m.muted },
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            for (final (i, (label, icon, tone, action)) in [
              if (online) (t.tools.ping, Icons.show_chart_rounded, m.teal, () {
                open(PingScreen(host: d.ip));
              }),
              if (online) (t.tools.ports, Icons.lock_outline_rounded, m.bad, () {
                open(PortsScreen(host: d.ip));
              }),
              (t.devices.rename, Icons.edit_outlined, m.muted, () {
                rename();
              }),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: action,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    side: BorderSide(color: m.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    foregroundColor: m.text,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 20, color: tone),
                    const SizedBox(height: 4),
                    Text(label, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
