import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import 'device_memory.dart';
import 'recent_hosts.dart';
import 'tools_providers.dart' show shareResultsProvider;

/// Choices that shape how the tools behave, kept on this phone.
@immutable
class ToolSettings {
  const ToolSettings({this.askOnMobile = true, this.hideMac = true, this.names = true, this.rememberHosts = true});

  /// Confirm before a speed test on mobile data, which can use a lot of it.
  final bool askOnMobile;

  /// Show only the maker part of hardware (MAC) addresses.
  final bool hideMac;

  /// Look up names for addresses (reverse DNS) in Traceroute.
  final bool names;

  /// Keep recent hosts for Traceroute.
  final bool rememberHosts;

  ToolSettings copyWith({bool? askOnMobile, bool? hideMac, bool? names, bool? rememberHosts}) => ToolSettings(
        askOnMobile: askOnMobile ?? this.askOnMobile,
        hideMac: hideMac ?? this.hideMac,
        names: names ?? this.names,
        rememberHosts: rememberHosts ?? this.rememberHosts,
      );
}

final toolSettingsProvider = AsyncNotifierProvider<ToolSettingsController, ToolSettings>(ToolSettingsController.new);

class ToolSettingsController extends AsyncNotifier<ToolSettings> {
  static const _askOnMobile = 'gvpn.tools.ask_on_mobile.v1';
  static const _hideMac = 'gvpn.tools.hide_mac.v1';
  static const _names = 'gvpn.tools.names.v1';
  static const _remember = 'gvpn.tools.remember_hosts.v1';

  @override
  Future<ToolSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ToolSettings(
      askOnMobile: prefs.getBool(_askOnMobile) ?? true,
      hideMac: prefs.getBool(_hideMac) ?? true,
      names: prefs.getBool(_names) ?? true,
      rememberHosts: prefs.getBool(_remember) ?? true,
    );
  }

  Future<void> setNames(bool on) async {
    state = AsyncData((await future).copyWith(names: on));
    await (await SharedPreferences.getInstance()).setBool(_names, on);
  }

  Future<void> setRememberHosts(bool on) async {
    state = AsyncData((await future).copyWith(rememberHosts: on));
    await (await SharedPreferences.getInstance()).setBool(_remember, on);
    if (!on) await ref.read(recentHostsProvider.notifier).clear();
  }

  Future<void> setHideMac(bool on) async {
    state = AsyncData((await future).copyWith(hideMac: on));
    await (await SharedPreferences.getInstance()).setBool(_hideMac, on);
  }

  Future<void> setAskOnMobile(bool on) async {
    state = AsyncData((await future).copyWith(askOnMobile: on));
    await (await SharedPreferences.getInstance()).setBool(_askOnMobile, on);
  }
}

/// Tools › settings.
class ToolSettingsScreen extends ConsumerWidget {
  const ToolSettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ToolSettingsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final settings = ref.watch(toolSettingsProvider).value ?? const ToolSettings();
    final sharing = ref.watch(shareResultsProvider).value ?? true;

    Widget row(String title, String sub, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          value: value,
          onChanged: onChanged,
          title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
          subtitle: Text(sub, style: TextStyle(fontSize: 12, color: m.muted)),
        );

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(title: Text(t.toolSettings.title), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          MerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                row(
                  t.toolSettings.askMobile,
                  t.toolSettings.askMobileSub,
                  settings.askOnMobile,
                  (v) => ref.read(toolSettingsProvider.notifier).setAskOnMobile(v),
                ),
                Divider(height: 1, color: m.line),
                row(
                  t.toolSettings.hideMac,
                  t.toolSettings.hideMacSub,
                  settings.hideMac,
                  (v) => ref.read(toolSettingsProvider.notifier).setHideMac(v),
                ),
                Divider(height: 1, color: m.line),
                row(
                  t.toolSettings.names,
                  t.toolSettings.namesSub,
                  settings.names,
                  (v) => ref.read(toolSettingsProvider.notifier).setNames(v),
                ),
                Divider(height: 1, color: m.line),
                row(
                  t.toolSettings.remember,
                  t.toolSettings.rememberSub,
                  settings.rememberHosts,
                  (v) => ref.read(toolSettingsProvider.notifier).setRememberHosts(v),
                ),
                Divider(height: 1, color: m.line),
                row(t.speed.compare, t.speed.compareSub, sharing, (v) => ref.read(shareResultsProvider.notifier).set(v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MerCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(Icons.delete_outline_rounded, color: m.bad),
              title: Text(t.toolSettings.clear, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.bad)),
              subtitle: Text(t.toolSettings.clearSub, style: TextStyle(fontSize: 12, color: m.muted)),
              onTap: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(t.toolSettings.clear),
                    content: Text(t.toolSettings.clearSub),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.common.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: TextButton.styleFrom(foregroundColor: m.bad),
                        child: Text(t.toolSettings.clearGo),
                      ),
                    ],
                  ),
                );
                if (sure == true) await clearToolHistory(ref);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Forgets recent hosts and which devices each network has had (the
/// memory behind NEW). Saved Wake on LAN devices and names you gave
/// devices stay: you made those.
Future<void> clearToolHistory(WidgetRef ref) async {
  await ref.read(recentHostsProvider.notifier).clear();
  await ref.read(deviceMemoryProvider.notifier).forgetSeen();
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().where((k) => k.startsWith('gvpn.lan_seen.'))) {
    await prefs.remove(key);
  }
}
