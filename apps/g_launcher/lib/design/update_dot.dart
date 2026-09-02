/// One dot, for one fact.
///
/// ─── THIS WIDGET TAKES NO CONDITION, AND THAT IS THE POINT ──────────────────
///
/// It reads `appUpdateProvider` directly rather than accepting a `show:` flag or
/// a `count:`, so there is no way to point it at anything other than a waiting
/// Play update. A badge that takes a boolean is a general-purpose nag surface
/// with one caller today, and the second caller is always something the home
/// screen should not have been interrupting anyone about.
///
/// If a second kind of indicator is ever genuinely wanted, it gets its own
/// widget and its own argument about whether the desktop is allowed to carry it.
/// Adding a parameter here is how that argument gets skipped.
///
/// ─── WHERE IT IS ALLOWED TO APPEAR ──────────────────────────────────────────
///
/// Exactly the surfaces that are already menus someone opened on purpose: the
/// desktop long-press bar and the drawer's settings entry. NOT the desktop
/// itself, NOT the top bar, and NOT the terminal shell, where a dot beside a
/// typed command means nothing. Six places construct `SettingsScreen`; four of
/// them must not have this.
///
/// ─── THE SELECT IS NOT DECORATION ───────────────────────────────────────────
///
/// `appUpdateProvider` emits on every transition, including checking and the
/// `lastCheckedAt` stamp moving. Selecting down to the one boolean means the
/// menu bar rebuilds when the dot appears or disappears and at no other time.
/// Same technique, and the same reason, as the selector in `crash_context.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/update/update_repository.dart';
import 'components/components.dart';

class UpdateDot extends ConsumerWidget {
  const UpdateDot({super.key, required this.child});

  /// The glyph or label being marked. Returned UNWRAPPED when there is nothing
  /// to say, so a menu with no update pays no Stack and no repaint.
  final Widget child;

  /// Small enough to read as a mark rather than as a control.
  static const double _size = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate =
        ref.watch(appUpdateProvider.select((u) => u.hasUpdate));
    if (!hasUpdate) return child;

    final d = ChromeScope.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: d.colors.accent,
              shape: BoxShape.circle,
              // A RING IN THE SURFACE COLOUR, not a shadow.
              //
              // This sits on a glyph that is itself over a tinted bar over a
              // wallpaper, and Ubuntu's accent is close in luminance to the warm
              // surface it mixes into, which `_Surface.tint` in desktop_menu
              // documents at length. Without separation the dot disappears into
              // the bar on exactly one distro and looks fine on thirteen.
              border: Border.all(color: d.colors.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
