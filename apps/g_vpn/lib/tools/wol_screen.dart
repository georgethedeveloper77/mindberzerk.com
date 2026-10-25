import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import 'tool_widgets.dart';

/// Builds the Wake-on-LAN "magic packet": six 0xFF bytes, then the target's
/// MAC address sixteen times. Null when the MAC is not six hex pairs.
List<int>? magicPacket(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.length != 12) return null;
  final bytes = [for (var i = 0; i < 12; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
  return [...List.filled(6, 0xFF), for (var i = 0; i < 16; i++) ...bytes];
}

class WolScreen extends StatefulWidget {
  const WolScreen({super.key});

  @override
  State<WolScreen> createState() => _WolScreenState();
}

class _WolScreenState extends State<WolScreen> {
  static const _macKey = 'gvpn.wol.mac.v1';
  final _mac = TextEditingController();
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) _mac.text = p.getString(_macKey) ?? '';
    });
  }

  @override
  void dispose() {
    _mac.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final packet = magicPacket(_mac.text);
    if (packet == null) {
      setState(() {
        _ok = false;
        _result = t.wol.badMac;
      });
      return;
    }
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      // Port 9 (discard) is the usual target; 7 covers older cards.
      for (final port in const [9, 7]) {
        socket.send(packet, InternetAddress('255.255.255.255'), port);
      }
      socket.close();
      await (await SharedPreferences.getInstance()).setString(_macKey, _mac.text.trim());
      setState(() {
        _ok = true;
        _result = t.wol.sent;
      });
    } on SocketException catch (e) {
      setState(() {
        _ok = false;
        _result = t.wol.failed(error: e.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return ToolPage(
      title: t.wol.title,
      info: t.wol.info,
      action: FilledButton(
        onPressed: _send,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(t.wol.wake),
      ),
      children: [
        TextField(
          controller: _mac,
          style: m.monoStyle(size: 15),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: t.wol.mac,
            hintText: 'AA:BB:CC:DD:EE:FF',
            filled: true,
            fillColor: m.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Text(_result!, style: TextStyle(fontSize: 14, color: _ok ? m.good : m.bad)),
        ],
      ],
    );
  }
}
