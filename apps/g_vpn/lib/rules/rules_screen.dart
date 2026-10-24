import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/theme_mode.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';
import 'banking.dart';
import 'rules_store.dart';

final _batteryProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(vpnApiProvider).batteryUnrestricted());

final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) => ref.read(vpnApiProvider).listApps(),
);

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  String _query = '';

  Future<void> _autoConnect(AutoConnectChoice choice) async {
    if (choice != AutoConnectChoice.off) {
      final api = ref.read(vpnApiProvider);
      // Consent must exist before the phone reaches the cafe: the background
      // path cannot show Android's dialog.
      if (!await api.prepare()) return;
      await api.requestNotifications();
    }
    await ref.read(rulesProvider.notifier).setAutoConnect(choice);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final rules = ref.watch(rulesProvider).value;
    final connected = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    if (rules == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final notifier = ref.read(rulesProvider.notifier);

    Widget radio(AutoConnectChoice c, String title, String sub) => ListItem(
          title: title,
          subtitle: sub,
          onTap: () => _autoConnect(c),
          trailing: Icon(
            rules.autoConnect == c ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: rules.autoConnect == c ? m.brand : m.line,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        centerTitle: false,
        actions: const [
          InfoAction(
            title: 'Rules',
            body: 'Shield sends lookups to Quad9, which refuses known malware and phishing sites. It does not block ads, '
                'and it replaces the server\'s DNS while on.\n\n'
                'Auto-connect uses your selected WireGuard server. Disconnecting by hand pauses it until you join '
                'another network.\n\n'
                'Apps that skip the VPN connect directly. Banks often block VPN addresses, so payments can fail '
                'through a VPN.\n\n'
                'Changing Shield or apps reconnects the VPN for a moment.\n\n'
                'Stay connected: some phones stop apps in the background to save battery. Always-on VPN and an '
                'unrestricted battery setting keep G VPN running.',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (connected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Changes reconnect the VPN', style: TextStyle(fontSize: 12, color: m.warn)),
            ),
          const SectionTitle('Protection'),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.shield_outlined, color: m.brand),
              title: 'Shield',
              subtitle: 'Blocks malware and phishing sites',
              trailing: Switch(value: rules.shield, onChanged: notifier.setShield),
              onTap: () => notifier.setShield(!rules.shield),
            ),
            ListItem(
              leading: Icon(Icons.dns_outlined, color: m.muted),
              title: 'Shield without the VPN',
              subtitle: 'Copy dns.quad9.net for Private DNS',
              trailing: Icon(Icons.copy_rounded, size: 18, color: m.muted),
              onTap: () async {
                await Clipboard.setData(const ClipboardData(text: 'dns.quad9.net'));
                if (!context.mounted) return;
                await InfoAction.show(
                  context,
                  'Copied dns.quad9.net',
                  'Open Settings, search for Private DNS, choose "Private DNS provider hostname" and paste it.',
                );
              },
            ),
          ]),
          const SectionTitle('Stay connected'),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.all_inclusive_rounded, color: m.brand),
              title: 'Always-on VPN',
              subtitle: 'Android restarts G VPN if it stops',
              trailing: Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () => ref.read(vpnApiProvider).openVpnSettings(),
            ),
            ListItem(
              leading: Icon(Icons.battery_saver_outlined, color: m.brand),
              title: 'Battery',
              subtitle: ref.watch(_batteryProvider).value == true ? 'Unrestricted' : 'Restricted: may stop in background',
              trailing: Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () async {
                await ref.read(vpnApiProvider).openBatterySettings();
                ref.invalidate(_batteryProvider);
              },
            ),
          ]),
          const SectionTitle('Auto-connect'),
          ListGroup(children: [
            radio(AutoConnectChoice.off, 'Off', 'Only when you tap'),
            radio(AutoConnectChoice.open, 'Public Wi-Fi', 'Open, WEP or sign-in networks'),
            radio(AutoConnectChoice.any, 'Every Wi-Fi', 'Any Wi-Fi network'),
          ]),
          SectionTitle(
            'Apps that skip the VPN',
            trailing: rules.excluded.isEmpty ? null : Tag('${rules.excluded.length}', color: m.brand),
          ),
          _Apps(rules: rules, query: _query, onQuery: (q) => setState(() => _query = q)),
          const SectionTitle('Appearance'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Phone')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _Apps extends ConsumerWidget {
  const _Apps({required this.rules, required this.query, required this.onQuery});

  final RulesState rules;
  final String query;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final notifier = ref.read(rulesProvider.notifier);
    return switch (ref.watch(installedAppsProvider)) {
      AsyncData(value: final apps) => Builder(builder: (context) {
          final money = apps.where(looksLikeMoneyApp).map((a) => a.packageName).toSet();
          final missing = money.difference(rules.excluded);
          final q = query.trim().toLowerCase();
          final shown = q.isEmpty ? apps : apps.where((a) => '${a.label} ${a.packageName}'.toLowerCase().contains(q)).toList();
          return Column(
            children: [
              if (money.isNotEmpty)
                ListGroup(children: [
                  ListItem(
                    leading: Icon(Icons.account_balance_outlined, color: m.brand),
                    title: 'Banking and mobile money',
                    subtitle: '${money.length} apps found',
                    trailing: missing.isEmpty
                        ? Icon(Icons.check_rounded, color: m.good)
                        : Text('Add all', style: TextStyle(color: m.brand, fontWeight: FontWeight.w700)),
                    onTap: missing.isEmpty ? null : () => notifier.setExcluded({...rules.excluded, ...money}),
                  ),
                ]),
              const SizedBox(height: 10),
              TextField(
                onChanged: onQuery,
                style: TextStyle(color: m.text),
                decoration: InputDecoration(
                  hintText: 'Search apps',
                  prefixIcon: Icon(Icons.search_rounded, color: m.muted),
                  filled: true,
                  fillColor: m.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              ListGroup(children: [
                for (final a in shown)
                  ListItem(
                    title: a.label,
                    subtitle: a.packageName,
                    mono: true,
                    onTap: () {
                      final next = {...rules.excluded};
                      if (!next.remove(a.packageName)) next.add(a.packageName);
                      notifier.setExcluded(next);
                    },
                    trailing: Checkbox(
                      value: rules.excluded.contains(a.packageName),
                      onChanged: (on) {
                        final next = {...rules.excluded};
                        if (on == true) {
                          next.add(a.packageName);
                        } else {
                          next.remove(a.packageName);
                        }
                        notifier.setExcluded(next);
                      },
                    ),
                  ),
              ]),
            ],
          );
        }),
      AsyncError(:final error) => Text('$error', style: TextStyle(color: m.bad)),
      _ => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2)),
    };
  }
}
