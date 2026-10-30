import 'package:flutter/widgets.dart';

/// Turns on the new-app dot for every [AppIcon] beneath it.
///
/// ─── A SCOPE, NOT A PARAMETER ───────────────────────────────────────────────
///
/// There are eleven drawers, and each draws its own cells. Threading a flag
/// through every one is eleven places to forget it. `ShellDrawer` wraps
/// whichever drawer it routes to in this, once, so a new drawer inherits the
/// dot without knowing it exists.
///
/// And a scope rather than "AppIcon always does it": the dock, the home grid
/// and the setup wizard are not where a newly installed app is looked for, and
/// a dot on a dock icon reads as a notification.
class NewAppDotScope extends InheritedWidget {
  const NewAppDotScope({super.key, required super.child});

  static bool enabledOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NewAppDotScope>() != null;

  @override
  bool updateShouldNotify(NewAppDotScope oldWidget) => false;
}
