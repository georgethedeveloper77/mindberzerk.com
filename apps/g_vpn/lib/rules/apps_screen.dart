import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/sheet.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';
import 'banking.dart';
import 'rules_store.dart';

final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) => ref.read(vpnApiProvider).listApps(),
);

/// Launcher icons, fetched once per app and kept for the session.
final appIconProvider = FutureProvider.family<Uint8List?, String>((ref, pkg) {
  ref.keepAlive();
  return ref.read(vpnApiProvider).appIcon(pkg, 96);
});

/// Apps the user starred, shown first.
final favouriteAppsProvider = AsyncNotifierProvider<FavouriteApps, Set<String>>(FavouriteApps.new);

class FavouriteApps extends AsyncNotifier<Set<String>> {
  static const _key = 'gvpn.app_favourites.v1';

  @override
  Future<Set<String>> build() async => ((await SharedPreferences.getInstance()).getStringList(_key) ?? const []).toSet();

  Future<void> toggle(String pkg) async {
    final next = {...?state.value};
    if (!next.remove(pkg)) next.add(pkg);
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setStringList(_key, next.toList());
  }
}

/// Apps that skip the VPN. The list people actually use is short, so the
/// screen leads with what is already skipping, favourites and a banking
/// suggestion, then the first ten apps A to Z; search reaches the rest.
class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  static const _collapsed = 10;
  String _query = '';
  bool _showAll = false;

  void _set(Set<String> excluded, String pkg, bool skip) {
    final next = {...excluded};
    skip ? next.add(pkg) : next.remove(pkg);
    ref.read(rulesProvider.notifier).setExcluded(next);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final rules = ref.watch(rulesProvider).value;
    final apps = ref.watch(installedAppsProvider);
    final favs = ref.watch(favouriteAppsProvider).value ?? const <String>{};
    final connected = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final excluded = rules?.excluded ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(t.apps.title),
        centerTitle: false,
        actions: [
          InfoIcon(
            onPressed: () => showInfoSheet(
              context,
              icon: Icons.call_split_rounded,
              title: t.apps.title,
              subtitle: t.apps.sheetSubtitle,
              sections: [
                SheetSection.text(t.apps.whyTitle, t.apps.whyBody),
                SheetSection.text(t.apps.favourites, t.apps.favouritesBody),
                SheetSection.text(t.apps.whileConnected, t.apps.whileConnectedBody),
              ],
            ),
          ),
        ],
      ),
      body: switch (apps) {
        AsyncData(value: final all) => Builder(builder: (context) {
            final byPkg = {for (final a in all) a.packageName: a};
            final q = _query.trim().toLowerCase();
            final sorted = [...all]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
            final money = all.where(looksLikeMoneyApp).map((a) => a.packageName).toSet();
            final moneyMissing = money.difference(excluded);
            final skipping = [for (final p in excluded) if (byPkg[p] != null) byPkg[p]!];
            final starred = sorted.where((a) => favs.contains(a.packageName)).toList();
            final matches = q.isEmpty
                ? sorted.where((a) => !favs.contains(a.packageName)).toList()
                : sorted.where((a) => '${a.label} ${a.packageName}'.toLowerCase().contains(q)).toList();
            final visible = q.isEmpty && !_showAll ? matches.take(_collapsed).toList() : matches;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (connected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(t.common.changesReconnect, style: TextStyle(fontSize: 12, color: m.warn)),
                  ),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: m.text),
                  decoration: InputDecoration(
                    hintText: t.apps.search(n: all.length),
                    prefixIcon: Icon(Icons.search_rounded, color: m.muted),
                    filled: true,
                    fillColor: m.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
                  ),
                ),
                if (q.isEmpty) ...[
                  SectionTitle(t.apps.skipping, trailing: skipping.isEmpty ? null : Tag('${skipping.length}', color: m.brand)),
                  if (skipping.isEmpty)
                    Text(t.apps.skippingNone, style: TextStyle(fontSize: 14, color: m.muted))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in skipping)
                          InputChip(
                            avatar: _AppIcon(pkg: a.packageName, size: 24),
                            label: Text(a.label),
                            onDeleted: () => _set(excluded, a.packageName, false),
                            deleteButtonTooltipMessage: t.apps.protectAgain(app: a.label),
                            backgroundColor: m.surface,
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: m.text),
                            shape: StadiumBorder(side: BorderSide(color: m.line)),
                          ),
                      ],
                    ),
                  if (moneyMissing.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ListGroup(children: [
                      ListItem(
                        leading: Icon(Icons.account_balance_outlined, color: m.brand),
                        title: t.apps.banking,
                        subtitle: t.apps.bankingFound(n: moneyMissing.length),
                        trailing: Text(t.apps.addAll, style: TextStyle(color: m.brand, fontWeight: FontWeight.w700)),
                        onTap: () => ref.read(rulesProvider.notifier).setExcluded({...excluded, ...money}),
                      ),
                    ]),
                  ],
                  if (starred.isNotEmpty) ...[
                    SectionTitle(t.apps.favourites),
                    ListGroup(children: [
                      for (final a in starred) _AppRow(app: a, skipping: excluded.contains(a.packageName), starred: true, onSkip: (v) => _set(excluded, a.packageName, v)),
                    ]),
                  ],
                ],
                SectionTitle(q.isEmpty ? t.apps.all : t.apps.found(n: matches.length)),
                if (visible.isEmpty)
                  Text(t.apps.noMatch, style: TextStyle(fontSize: 14, color: m.muted))
                else
                  ListGroup(children: [
                    for (final a in visible)
                      _AppRow(
                        app: a,
                        skipping: excluded.contains(a.packageName),
                        starred: favs.contains(a.packageName),
                        onSkip: (v) => _set(excluded, a.packageName, v),
                      ),
                  ]),
                if (q.isEmpty && !_showAll && matches.length > _collapsed)
                  TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: Text(t.apps.showAll(n: matches.length)),
                  ),
              ],
            );
          }),
        AsyncError(:final error) => Center(child: Text('$error', style: TextStyle(color: m.bad))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _AppRow extends ConsumerWidget {
  const _AppRow({required this.app, required this.skipping, required this.starred, required this.onSkip});

  final InstalledApp app;
  final bool skipping;
  final bool starred;
  final ValueChanged<bool> onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    return ListItem(
      leading: _AppIcon(pkg: app.packageName, size: 38),
      title: app.label,
      subtitle: skipping ? t.apps.skips : null,
      onTap: () => onSkip(!skipping),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: starred ? t.apps.unstar : t.apps.star,
            onPressed: () => ref.read(favouriteAppsProvider.notifier).toggle(app.packageName),
            icon: Icon(starred ? Icons.star_rounded : Icons.star_outline_rounded, color: starred ? m.warn : m.muted),
          ),
          Switch(value: skipping, onChanged: onSkip),
        ],
      ),
    );
  }
}

class _AppIcon extends ConsumerWidget {
  const _AppIcon({required this.pkg, required this.size});

  final String pkg;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final bytes = ref.watch(appIconProvider(pkg)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: SizedBox(
        width: size,
        height: size,
        child: bytes == null
            ? ColoredBox(color: m.surface2)
            : Image.memory(bytes, width: size, height: size, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }
}
