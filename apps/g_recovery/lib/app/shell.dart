import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messenger/g_messenger.dart';
import '../core/prefs/prefs_keys.dart';
import '../core/prefs/prefs_store.dart';
import '../features/backup/backup_page.dart';
import '../features/device/device_page.dart';
import '../features/home/home_page.dart';
import '../features/more/more_page.dart';
import '../features/storage/storage_page.dart';
import '../ui/g_bottom_nav.dart';
import 'theme/tokens.dart';

/// Selected tab. A notifier rather than local state so a deep link, a
/// notification tap, or a card on home can move the user to another tab in
/// Phase 4 without threading a callback down the tree.
class GShellTab extends Notifier<int> {
  @override
  int build() {
    final int stored = ref.read(prefsStoreProvider).readInt(GPrefsKeys.shellTab);
    return stored >= 0 && stored < gNavItems.length ? stored : 0;
  }

  void select(int index) {
    if (index == state || index < 0 || index >= gNavItems.length) return;
    state = index;
    ref.read(prefsStoreProvider).writeInt(GPrefsKeys.shellTab, index);
  }
}

final NotifierProvider<GShellTab, int> gShellTabProvider =
    NotifierProvider<GShellTab, int>(GShellTab.new);

const List<GNavItem> gNavItems = <GNavItem>[
  GNavItem(label: 'Home', icon: Icons.auto_awesome_mosaic_outlined),
  GNavItem(label: 'Storage', icon: Icons.donut_small_outlined),
  GNavItem(label: 'Device', icon: Icons.memory_outlined),
  GNavItem(label: 'Backup', icon: Icons.cloud_upload_outlined),
  GNavItem(label: 'More', icon: Icons.more_horiz_rounded),
];

class GShell extends ConsumerWidget {
  const GShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(gShellTabProvider);
    final GTokens t = context.g;

    // IndexedStack, not a swapped child: each tab keeps its scroll position and
    // its in-flight scan state when the user moves away and back.
    return GMessengerInsets(
      bottom: GSpace.navHeight,
      child: Scaffold(
        backgroundColor: t.ink,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: index,
            children: const <Widget>[
              HomePage(),
              StoragePage(),
              DevicePage(),
              BackupPage(),
              MorePage(),
            ],
          ),
        ),
        bottomNavigationBar: GBottomNav(
          items: gNavItems,
          index: index,
          onSelected: ref.read(gShellTabProvider.notifier).select,
        ),
      ),
    );
  }
}

/// Shared page scaffold. Gives every tab the same gutter and scroll behaviour
/// so a page never has to reinvent its own padding.
class GPageBody extends StatelessWidget {
  const GPageBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        GSpace.gutter,
        0,
        GSpace.gutter,
        GSpace.xl,
      ),
      children: children,
    );
  }
}
