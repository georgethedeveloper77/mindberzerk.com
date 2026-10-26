import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/config_rules.dart';
import '../vpn/vpn_controller.dart';
import 'rules_store.dart';

/// A level's name, as lists and tiles show it.
String shieldLevelName(ShieldLevel level) => switch (level) {
      ShieldLevel.off => t.shield.off,
      ShieldLevel.malware => t.shield.malware,
      ShieldLevel.family => t.shield.family,
      ShieldLevel.custom => t.shield.custom,
    };

/// Picks how Shield filters lookups while connected.
class ShieldScreen extends ConsumerWidget {
  const ShieldScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShieldScreen()));

  Future<void> _custom(BuildContext context, WidgetRef ref, RulesState rules) async {
    final entered = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CustomDnsDialog(initial: rules.customDns),
    );
    if (entered != null) await ref.read(rulesProvider.notifier).setShieldLevel(ShieldLevel.custom, customDns: entered);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final rules = ref.watch(rulesProvider).value ?? const RulesState();
    final connected = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final notifier = ref.read(rulesProvider.notifier);

    Widget option(ShieldLevel level, String sub, {String? tag, VoidCallback? onTap}) {
      final selected = rules.shieldLevel == level;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: Material(
          color: selected ? m.brandSoft : m.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Meridian.rCard),
            side: BorderSide(color: selected ? m.brand : m.line, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Meridian.rCard),
            onTap: onTap ?? () => notifier.setShieldLevel(level),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      color: selected ? m.brand : m.muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shieldLevelName(level), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
                        const SizedBox(height: 2),
                        Text(sub, style: TextStyle(fontSize: 13, color: m.muted)),
                      ],
                    ),
                  ),
                  if (tag != null) Text(tag, style: m.monoStyle(size: 12, color: m.muted)),
                ],
              ),
            ),
          ),
        ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(title: Text(t.shield.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: (rules.shield ? m.good : m.muted).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.shield_outlined, size: 42, color: rules.shield ? m.good : m.muted),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text(t.shield.sub, style: TextStyle(fontSize: 14, color: m.muted))),
          if (connected) ...[
            const SizedBox(height: 4),
            Center(child: Text(t.common.changesReconnect, style: TextStyle(fontSize: 12, color: m.warn))),
          ],
          const SizedBox(height: 20),
          option(ShieldLevel.off, t.shield.offSub),
          option(ShieldLevel.malware, t.shield.malwareSub, tag: 'Quad9'),
          option(ShieldLevel.family, t.shield.familySub, tag: 'Cloudflare'),
          option(
            ShieldLevel.custom,
            rules.customDns.isEmpty ? t.shield.customSub : rules.customDns.join(', '),
            onTap: () => _custom(context, ref, rules),
          ),
        ],
      ),
    );
  }
}

/// One or two resolver addresses for Custom DNS.
class _CustomDnsDialog extends StatefulWidget {
  const _CustomDnsDialog({required this.initial});

  final List<String> initial;

  @override
  State<_CustomDnsDialog> createState() => _CustomDnsDialogState();
}

class _CustomDnsDialogState extends State<_CustomDnsDialog> {
  late final _first = TextEditingController(text: widget.initial.firstOrNull ?? '');
  late final _second = TextEditingController(text: widget.initial.length > 1 ? widget.initial[1] : '');
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _save() {
    final values = [_first.text.trim(), _second.text.trim()].where((v) => v.isNotEmpty).toList();
    if (values.isEmpty || !values.every(isIpAddress)) {
      setState(() => _error = t.shield.invalid);
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    InputDecoration field(String label) => InputDecoration(
          labelText: label,
          hintText: t.shield.customHint,
          border: const OutlineInputBorder(),
        );
    return AlertDialog(
      backgroundColor: m.surface,
      title: Text(t.shield.custom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _first, keyboardType: TextInputType.url, decoration: field('DNS 1'), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: _second, keyboardType: TextInputType.url, decoration: field('DNS 2')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(fontSize: 13, color: m.bad)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.cancel)),
        TextButton(onPressed: _save, child: Text(t.presets.save)),
      ],
    );
  }
}
