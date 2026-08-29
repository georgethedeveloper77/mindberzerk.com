library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspaces/workspace_controller.dart';

/// The HOME press, arriving from `LauncherActivity.onNewIntent`.
///
/// ─── THE HALF THAT WAS NEVER WRITTEN ────────────────────────────────────────
///
/// Native has sent `"home"` down `g_launcher/home_press` since the Activity was
/// written, on every home press while the launcher is already the resumed task.
/// Nothing in `lib/` ever listened. The channel name appeared exactly once in
/// the whole Dart tree, in a doc comment on [ActiveWorkspace.reset] describing
/// the handler that was going to call it.
///
/// So the home button did nothing. With `launchMode=singleTask` and an engine
/// warmed in `LauncherApplication`, the widget tree is exactly as it was left,
/// which is the same property that makes a home press fast: the drawer is still
/// open, the pushed route is still on top, and the desktop is behind both. The
/// one gesture on the phone that means "take me back to the beginning" was the
/// one gesture that could not.
///
/// It showed up first on search, because search is a pushed route with no
/// chrome and a focused field, so back had to get through the keyboard and two
/// routes to reach the desktop and home could not help. But the fault was never
/// search's, and every full screen surface had it.
///
/// ─── WHY A WIDGET AND NOT A PROVIDER ────────────────────────────────────────
///
/// The handler has to pop routes and it has to call [closeApps], and those want
/// two different things: a `Navigator` from the tree, and a `WidgetRef` rather
/// than a `Ref`. A `ConsumerState` has both. A provider would need a global
/// navigator key and a second copy of the open/close branch that
/// `workspace_controller` exists to keep in one place.
///
/// Mounted under `MaterialApp` so `Navigator.of` resolves, and above the setup
/// gate so it survives setup finishing and the desktop mounting fresh.
class HomeIntent extends ConsumerStatefulWidget {
  const HomeIntent({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeIntent> createState() => _HomeIntentState();
}

class _HomeIntentState extends ConsumerState<HomeIntent> {
  /// StringCodec, matching `BasicMessageChannel<String>` with
  /// `StringCodec.INSTANCE` on the Kotlin side. A codec mismatch here would
  /// fail as a decode error on a message nobody is watching for, which is the
  /// quietest possible way to reinstate the bug this file fixes.
  ///
  /// `String?` and not `String`, which is not a style choice: `StringCodec`
  /// implements `MessageCodec<String?>`, so the channel is
  /// `BasicMessageChannel<String?>` and the handler returns `Future<String?>`.
  /// Kotlin's side is non-null `String` and that is fine; the nullability is
  /// Dart's, covering a null decode and the null reply this sends back.
  static const _channel = BasicMessageChannel<String?>(
    'g_launcher/home_press',
    StringCodec(),
  );

  @override
  void initState() {
    super.initState();
    _channel.setMessageHandler((message) async {
      // Native sends one word today. Ignoring anything else means a later
      // message ("search", "assist") cannot accidentally read as a home press
      // before its own handler exists.
      if (message == 'home' && mounted) _goHome();
      return null;
    });
  }

  @override
  void dispose() {
    // REPLACES rather than stacks, per BasicMessageChannel semantics, so this
    // clear only matters on a real teardown. Left in because a handler holding
    // a dead State is worse than no handler.
    _channel.setMessageHandler(null);
    super.dispose();
  }

  /// Back to the beginning, in the order the user perceives.
  ///
  /// The IME first, because a keyboard sliding away after the desktop has
  /// already appeared reads as a second, unrequested animation. Then routes,
  /// then the app list, then the workspace, which is outermost to innermost:
  /// closing the drawer under a still-mounted search page would reveal nothing
  /// and look like the press did nothing at all.
  void _goHome() {
    FocusManager.instance.primaryFocus?.unfocus();

    // rootNavigator, and `isFirst` rather than a count. Everything pushed is on
    // this one navigator: the four drawers' search route, the palette, the
    // themed sheets and dialogs. `_Root` is the first route and is never popped.
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);

    // Through the shared helper, not `activitiesOpenProvider = false`. On a
    // distro whose apps are a workspace page there is no flag to clear and the
    // page itself is what has to be left, which is the branch that helper owns.
    closeApps(ref);

    // And workspace one. Not redundant with the line above: closeApps only
    // resets the pager on a workspace-apps distro, so on every overlay distro,
    // which is all of them shipping today, this is the line that actually
    // lands the user on the first desktop.
    ref.read(activeWorkspaceProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
