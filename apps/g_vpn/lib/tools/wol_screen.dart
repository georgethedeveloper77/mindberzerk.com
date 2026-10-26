import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import 'tool_widgets.dart' show ToolTitle;

/// Builds the Wake-on-LAN "magic packet": six 0xFF bytes, then the target's
/// MAC address sixteen times. Null when the MAC is not six hex pairs.
List<int>? magicPacket(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.length != 12) return null;
  final bytes = [for (var i = 0; i < 12; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
  return [...List.filled(6, 0xFF), for (var i = 0; i < 16; i++) ...bytes];
}

/// "aabbccddeeff" or "AA-BB-..." as "AA:BB:CC:DD:EE:FF".
String _tidy(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  return [for (var i = 0; i + 1 < hex.length; i += 2) hex.substring(i, i + 2)].join(':');
}

/// Sends the magic packet to the whole network. Throws on socket errors.
Future<void> sendWake(String mac) async {
  final packet = magicPacket(mac)!;
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  // Port 9 (discard) is the usual target; 7 covers older cards.
  for (final port in const [9, 7]) {
    socket.send(packet, InternetAddress('255.255.255.255'), port);
  }
  socket.close();
}

@immutable
class WolDevice {
  const WolDevice({required this.name, required this.mac});

  final String name;
  final String mac;

  Map<String, String> toJson() => {'n': name, 'm': mac};

  static WolDevice? fromJson(Object? j) =>
      j is Map && j['m'] is String ? WolDevice(name: j['n'] is String ? j['n'] as String : '', mac: j['m'] as String) : null;
}

final wolDevicesProvider = AsyncNotifierProvider<WolDevices, List<WolDevice>>(WolDevices.new);

/// The computers the user wakes, kept on this phone.
class WolDevices extends AsyncNotifier<List<WolDevice>> {
  static const _key = 'gvpn.wol.devices.v1';
  static const _legacy = 'gvpn.wol.mac.v1';

  @override
  Future<List<WolDevice>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return (jsonDecode(raw) as List).map(WolDevice.fromJson).whereType<WolDevice>().toList();
      } on FormatException {
        return const [];
      }
    }
    // The single address the old screen remembered becomes the first device.
    final old = prefs.getString(_legacy);
    return old == null || magicPacket(old) == null ? const [] : [WolDevice(name: t.wol.computer, mac: _tidy(old))];
  }

  Future<void> add(String name, String mac) async {
    final next = [...await future.then((l) => l.where((d) => d.mac != _tidy(mac))), WolDevice(name: name, mac: _tidy(mac))];
    await _save(next);
  }

  Future<void> remove(WolDevice device) async => _save([...(await future).where((d) => d.mac != device.mac)]);

  Future<void> _save(List<WolDevice> list) async {
    state = AsyncData(list);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final d in list) d.toJson()]));
  }
}

/// Wakes saved computers with one tap, or a new one by its address.
class WolScreen extends ConsumerStatefulWidget {
  const WolScreen({super.key});

  @override
  ConsumerState<WolScreen> createState() => _WolScreenState();
}

class _WolScreenState extends ConsumerState<WolScreen> with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _mac = TextEditingController();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  /// The device a wake was last sent to, and how it went.
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _wake(WolDevice d) async {
    try {
      await sendWake(d.mac);
      if (!mounted) return;
      setState(() {
        _sentTo = d.name;
        _error = null;
      });
      if (!MediaQuery.disableAnimationsOf(context)) _pulse.repeat();
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (mounted) _pulse.stop();
      });
    } on SocketException catch (e) {
      if (mounted) setState(() => _error = t.wol.failed(error: e.message));
    }
  }

  Future<void> _addAndWake() async {
    final mac = _mac.text;
    if (magicPacket(mac) == null) {
      setState(() => _error = t.wol.badMac);
      return;
    }
    final name = _name.text.trim().isEmpty ? t.wol.computer : _name.text.trim();
    await ref.read(wolDevicesProvider.notifier).add(name, mac);
    _name.clear();
    _mac.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await _wake(WolDevice(name: name, mac: mac));
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final devices = ref.watch(wolDevicesProvider).value ?? const <WolDevice>[];
    InputDecoration field(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: m.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
        );

    return Scaffold(
      appBar: AppBar(
        title: ToolTitle(title: t.wol.title, icon: Icons.power_settings_new_rounded, color: m.teal),
        centerTitle: false,
        actions: [InfoAction(title: t.wol.title, body: t.wol.info)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  painter: _WakePainter(color: m.teal, t: _pulse.isAnimating ? _pulse.value : null),
                  child: Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(color: m.teal, shape: BoxShape.circle),
                      child: Icon(Icons.power_settings_new_rounded, size: 48, color: m.bg),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? (_sentTo == null ? t.wol.pick : t.wol.waking(name: _sentTo!)),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _error != null ? m.bad : _sentTo == null ? m.muted : m.teal),
          ),
          if (_sentTo != null && _error == null)
            Text(t.wol.sent, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: m.muted)),
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(t.wol.yours, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
            const SizedBox(height: 8),
            MerCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, d) in devices.indexed) ...[
                    if (i > 0) Divider(height: 1, color: m.line),
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: m.teal.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)),
                        child: Icon(Icons.computer_rounded, size: 19, color: m.teal),
                      ),
                      title: Text(d.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                      subtitle: Text(d.mac, style: m.monoStyle(size: 11, color: m.muted)),
                      onLongPress: () => ref.read(wolDevicesProvider.notifier).remove(d),
                      trailing: IconButton.filledTonal(
                        tooltip: t.wol.wakeNamed(name: d.name),
                        onPressed: () => _wake(d),
                        style: IconButton.styleFrom(
                          backgroundColor: m.teal.withValues(alpha: .16),
                          foregroundColor: m.teal,
                          fixedSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.power_settings_new_rounded, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(t.wol.removeHint, style: TextStyle(fontSize: 12, color: m.muted)),
            ),
          ],
          const SizedBox(height: 18),
          Text(t.wol.add, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
          const SizedBox(height: 8),
          TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: field(t.wol.name, hint: t.wol.computer)),
          const SizedBox(height: 10),
          TextField(
            controller: _mac,
            style: m.monoStyle(size: 15),
            textCapitalization: TextCapitalization.characters,
            decoration: field(t.wol.mac, hint: 'AA:BB:CC:DD:EE:FF'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _addAndWake,
            icon: const Icon(Icons.power_settings_new_rounded),
            label: Text(t.wol.saveWake),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: m.teal,
              foregroundColor: m.bg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rings spreading from the power button while a wake goes out.
class _WakePainter extends CustomPainter {
  _WakePainter({required this.color, required this.t});

  final Color color;

  /// 0 to 1 through the pulse; null when resting.
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .35);
    canvas.drawCircle(c, 66, ring);
    final p = t;
    if (p == null) return;
    for (final phase in [p, (p + .5) % 1]) {
      canvas.drawCircle(c, 52 + 34 * phase, Paint()..color = color.withValues(alpha: .35 * (1 - phase)));
    }
  }

  @override
  bool shouldRepaint(_WakePainter old) => old.t != t || old.color != color;
}
