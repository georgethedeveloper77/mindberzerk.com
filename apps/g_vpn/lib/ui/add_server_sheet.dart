import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/wg_config.dart';

/// "Your Server" import: paste a wg-quick config. QR scan follows once the
/// camera permission is justified by it.
class AddServerSheet extends ConsumerStatefulWidget {
  const AddServerSheet({super.key, this.initialName, this.initialConfig});

  /// Prefilled by QR scan or file import; the user still reviews and saves.
  final String? initialName;
  final String? initialConfig;

  static Future<void> show(BuildContext context, {String? name, String? config}) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Meridian.rCard)),
        ),
        builder: (_) => AddServerSheet(initialName: name, initialConfig: config),
      );

  @override
  ConsumerState<AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends ConsumerState<AddServerSheet> {
  final _name = TextEditingController();
  final _config = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    final config = widget.initialConfig;
    if (config != null) {
      _config.text = config;
      // Say straight away if a scanned code was not a WireGuard config (a
      // Wi-Fi QR or a website link, say), rather than at Save.
      try {
        parseWgConfig(config);
      } on WgConfigException catch (e) {
        _error = t.addServer.notWireguard(error: e.message);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _config.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = t.addServer.clipboardEmpty);
      return;
    }
    setState(() {
      _config.text = text;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await ref.read(tunnelsProvider.notifier).add(name: _name.text, configText: _config.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = error;
        _saving = false;
      });
    }
  }

  InputDecoration _input(Meridian m, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: m.muted),
        filled: true,
        fillColor: m.surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: m.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(t.addServer.title, style: TextStyle(color: m.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            t.addServer.body,
            style: TextStyle(color: m.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, style: TextStyle(color: m.text), decoration: _input(m, t.addServer.nameHint)),
          const SizedBox(height: 10),
          TextField(
            controller: _config,
            minLines: 6,
            maxLines: 10,
            style: m.monoStyle(size: 12),
            decoration: _input(m, '[Interface]\nPrivateKey = your key'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: m.bad, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _paste,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: m.text,
                    side: BorderSide(color: m.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(t.addServer.paste),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: Text(t.addServer.save))),
            ],
          ),
        ],
      ),
    );
  }
}
