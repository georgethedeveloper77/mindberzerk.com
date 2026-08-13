import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/features/home/home_page.dart';

import '../core/messenger/g_messenger.dart';
import '../core/prefs/prefs_keys.dart';
import '../core/prefs/prefs_store.dart';
import '../features/device/device_page.dart';
import '../features/messages/state/messages_providers.dart';
import '../features/more/more_page.dart';
import '../features/recovery/state/recovery_providers.dart';
import '../features/storage/storage_page.dart';
import '../ui/g_bottom_nav.dart';
import 'theme/tokens.dart';

/// Selected tab. A notifier rather than local state so a deep link, a
/// notification tap, or a card on home can move the user to another tab in
/// Phase 4 without threading a callback down the tree.
class GShellTab extends Notifier<int> {
  @override
  int build() {
    final int stored = ref
        .read(prefsStoreProvider)
        .readInt(GPrefsKeys.shellTab);
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

/// Tab indices by name. Home reaches Device through one of these rather than a
/// literal, so reordering the bar is a single edit.
class GTabs {
  const GTabs._();

  static const int home = 0;
  static const int storage = 1;
  static const int device = 2;
  static const int more = 3;
}

const List<GNavItem> gNavItems = <GNavItem>[
  GNavItem(label: 'Home', icon: Icons.auto_awesome_mosaic_outlined),
  GNavItem(label: 'Storage', icon: Icons.donut_small_outlined),
  GNavItem(label: 'Device', icon: Icons.monitor_heart_outlined),
  GNavItem(label: 'More', icon: Icons.more_horiz_rounded),
];

/// The shell, with one navigator per tab.
///
/// ─── WHY NESTED NAVIGATORS ───────────────────────────────────────────────────
///
/// Pushing a category onto the ROOT navigator covers the bottom bar, throws away
/// which tab you were on, and makes back a single flat undo across the whole
/// app. The result was three different navigation models in one product: tabs
/// that are not routes, sub pages that are, and Storage's drill in which is
/// neither because it mutates a filter in place. Back meant something different
/// in each.
///
/// A Navigator per tab fixes all three symptoms at once. The bar stays fixed
/// because sub pages render INSIDE the shell. Each tab remembers its own stack,
/// so leaving Storage mid drill and coming back returns to where you were. And
/// back has one clear order: this tab's stack first, then Home, then out.
///
/// Nothing at the call sites changes. `Navigator.of(context)` finds the nearest
/// Navigator, which is now the tab's own, so every existing push lands in the
/// right stack without being touched. The exception is anything that must cover
/// the bar, which asks for `rootNavigator: true` explicitly.
class GShell extends ConsumerStatefulWidget {
  const GShell({super.key});

  @override
  ConsumerState<GShell> createState() => _GShellState();
}

class _GShellState extends ConsumerState<GShell> with WidgetsBindingObserver {
  /// One key per tab, created once and never rebuilt. A key that changed
  /// identity would tear down the stack it is meant to preserve.
  late final List<GlobalKey<NavigatorState>> _keys =
      <GlobalKey<NavigatorState>>[
        for (int i = 0; i < gNavItems.length; i++) GlobalKey<NavigatorState>(),
      ];

  static const List<Widget> _roots = <Widget>[
    HomePage(),
    StoragePage(),
    DevicePage(),
    MorePage(),
  ];

  /// Tabs that have been looked at, which is not the same as tabs that exist.
  ///
  /// ─── AN INDEXED STACK BUILDS EVERY CHILD AT ONCE ─────────────────────────
  ///
  /// That is the price of keeping them alive, and it was being paid at the
  /// wrong moment: all four tabs did their first build during launch, so
  /// opening the app to Home still ran Storage's providers, Device's providers
  /// and More's. Every future cost any tab acquires lands on the cold start of
  /// a tab nobody opened. The comparison ledger reading a scan off disk is the
  /// current example and it will not be the last one.
  ///
  /// A tab is built the first time it is selected and never torn down after,
  /// so everything the stack was chosen for still holds: scroll positions,
  /// in-flight scans and navigation stacks all survive from the first visit.
  /// What is gone is paying for a screen before anyone has asked to see it.
  ///
  /// ─── THE SET IS GROWN DURING BUILD, DELIBERATELY ─────────────────────────
  ///
  /// Adding the selected index here rather than in [GShellTab.select] keeps the
  /// restored tab correct: the notifier reads the last tab out of preferences,
  /// so the first index this widget ever sees may be any of the four and no
  /// select call will have happened. The add is idempotent and always precedes
  /// its own use in the same build, which is what makes a mutation in build
  /// safe in this one case.
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-read the file access grant every time the app comes forward.
  ///
  /// All Files Access is given on a settings screen in another task. There is no
  /// result and no callback, so returning to the foreground is the only moment
  /// this app can learn the answer. Onboarding already does this for its own
  /// step; here it covers every screen at once, which matters most for the
  /// alert on home, since without it that alert would still be shouting at
  /// someone who has just done what it asked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(recoveryAccessProvider);
    // Notification access is granted the same way and read back the same way:
    // a settings screen in another task, no result, no callback.
    ref.invalidate(messageCaptureProvider);
  }

  /// Back, in the only order that makes sense.
  ///
  /// Down the current tab's stack, then to Home, then out of the app. Tapping a
  /// tab is not a route and is deliberately not undoable: a history of visited
  /// tabs means back sometimes goes sideways, which no one can predict.
  void _back() {
    final int index = ref.read(gShellTabProvider);
    final NavigatorState? nav = _keys[index].currentState;

    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (index != GTabs.home) {
      ref.read(gShellTabProvider.notifier).select(GTabs.home);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final int index = ref.watch(gShellTabProvider);
    final GTokens t = context.g;

    _visited.add(index);

    // canPop is always false, and the exit is performed by hand. Letting the
    // framework pop the root route on the last press would leave this handler
    // guessing at which press it was looking at.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _back();
      },
      child: GMessengerInsets(
        bottom: GSpace.navHeight,
        child: Scaffold(
          backgroundColor: t.ink,
          // IndexedStack, not a swapped child: each tab keeps its scroll
          // position, its in-flight scan state, and now its navigation stack.
          //
          // Children appear on first visit rather than at launch. An unvisited
          // tab is an empty box, which costs nothing and occupies the slot so
          // the indices still line up with the bar.
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: index,
              children: <Widget>[
                for (int i = 0; i < _roots.length; i++)
                  if (!_visited.contains(i))
                    const SizedBox.shrink()
                  else
                    Navigator(
                      key: _keys[i],
                      onGenerateRoute: (RouteSettings settings) =>
                          MaterialPageRoute<void>(
                            settings: settings,
                            builder: (BuildContext context) => _roots[i],
                          ),
                    ),
              ],
            ),
          ),
          bottomNavigationBar: GBottomNav(
            items: gNavItems,
            index: index,
            // Tapping the tab you are already on pops that tab back to its
            // root, which is what every app with this shape does and what a
            // person reaches for when they are lost inside a stack.
            onSelected: (int next) {
              if (next == index) {
                _keys[index].currentState?.popUntil(
                  (Route<dynamic> route) => route.isFirst,
                );
                return;
              }
              ref.read(gShellTabProvider.notifier).select(next);
            },
          ),
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
