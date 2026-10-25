import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/theme_mode.dart';
import '../i18n/strings.g.dart';
import '../legal.dart';
import '../vpn/vpn_controller.dart';
import 'apps_screen.dart';
import 'rules_store.dart';

final _batteryProvider = FutureProvider.autoDispose<bool>(
    (ref) => ref.read(vpnApiProvider).batteryUnrestricted());

class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
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
    final connected =
        ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    if (rules == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final notifier = ref.read(rulesProvider.notifier);

    Widget radio(AutoConnectChoice c, String title, String sub) => ListItem(
          title: title,
          subtitle: sub,
          onTap: () => _autoConnect(c),
          trailing: Icon(
            rules.autoConnect == c
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: rules.autoConnect == c ? m.brand : m.line,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.rules.title),
        centerTitle: false,
        actions: [
          InfoAction(
            title: t.rules.title,
            body: [
              t.rules.info.shield,
              t.rules.info.autoConnect,
              t.rules.info.apps,
              t.rules.info.reconnect,
              t.rules.info.stay,
            ].join('\n\n'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (connected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t.common.changesReconnect,
                  style: TextStyle(fontSize: 12, color: m.warn)),
            ),
          SectionTitle(t.rules.protection),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.shield_outlined, color: m.brand),
              title: t.rules.shield,
              subtitle: t.rules.shieldSub,
              trailing:
                  Switch(value: rules.shield, onChanged: notifier.setShield),
              onTap: () => notifier.setShield(!rules.shield),
            ),
            ListItem(
              leading: Icon(Icons.dns_outlined, color: m.muted),
              title: t.rules.privateDns,
              subtitle: t.rules.privateDnsSub,
              trailing: Icon(Icons.copy_rounded, size: 18, color: m.muted),
              onTap: () async {
                await Clipboard.setData(
                    const ClipboardData(text: 'dns.quad9.net'));
                if (!context.mounted) return;
                await InfoAction.show(
                  context,
                  t.rules.privateDnsCopied,
                  t.rules.privateDnsHow,
                );
              },
            ),
          ]),
          SectionTitle(t.rules.stay),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.all_inclusive_rounded, color: m.brand),
              title: t.rules.alwaysOn,
              subtitle: t.rules.alwaysOnSub,
              trailing:
                  Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () => ref.read(vpnApiProvider).openVpnSettings(),
            ),
            ListItem(
              leading: Icon(Icons.battery_saver_outlined, color: m.brand),
              title: t.rules.battery,
              subtitle: ref.watch(_batteryProvider).value == true
                  ? t.rules.batteryOk
                  : t.rules.batteryRestricted,
              trailing:
                  Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () async {
                await ref.read(vpnApiProvider).openBatterySettings();
                ref.invalidate(_batteryProvider);
              },
            ),
          ]),
          SectionTitle(t.rules.autoConnect),
          ListGroup(children: [
            radio(AutoConnectChoice.off, t.rules.autoOff, t.rules.autoOffSub),
            radio(
                AutoConnectChoice.open, t.rules.autoOpen, t.rules.autoOpenSub),
            radio(AutoConnectChoice.any, t.rules.autoAny, t.rules.autoAnySub),
          ]),
          SectionTitle(t.rules.apps),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.alt_route_rounded, color: m.brand),
              title: t.rules.appsDirect,
              subtitle: rules.excluded.isEmpty
                  ? t.rules.appsNone
                  : t.rules.appsSome(n: rules.excluded.length),
              trailing: Icon(Icons.chevron_right_rounded, color: m.muted),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AppsScreen())),
            ),
          ]),
          SectionTitle(t.rules.appearance),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: ThemeMode.system, label: Text(t.rules.themePhone)),
                ButtonSegment(
                    value: ThemeMode.light, label: Text(t.rules.themeLight)),
                ButtonSegment(
                    value: ThemeMode.dark, label: Text(t.rules.themeDark)),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          SectionTitle(t.rules.about),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.privacy_tip_outlined, color: m.brand),
              title: t.legal.privacy,
              trailing:
                  Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () => Legal.open(Legal.privacy),
            ),
            ListItem(
              leading: Icon(Icons.description_outlined, color: m.brand),
              title: t.legal.terms,
              trailing:
                  Icon(Icons.open_in_new_rounded, size: 18, color: m.muted),
              onTap: () => Legal.open(Legal.terms),
            ),
          ]),
        ],
      ),
    );
  }
}
