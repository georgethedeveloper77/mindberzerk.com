import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import 'chrome_theme.dart';

/// The root of every chrome screen — the ONE widget that bridges
/// [effectiveThemeProvider] (async, Riverpod) to [ChromeScope] (sync,
/// inherited). Every other primitive is a plain widget that reads the scope, so
/// only this one carries the Riverpod + provider dependency.
///
/// Use it in place of a bare `Scaffold(appBar: AppBar(...))`. Step 3 of Phase B
/// migrates `settings_screen.dart` and `wallpaper_screen.dart` onto it; after
/// that no chrome screen constructs its own `AppBar` or reads the house theme.
///
/// While the theme future is resolving (cold start) or if it errors, the scope
/// carries [ChromeData.bootstrap] — house chrome, the floor. It flips to the
/// real derived palette the instant the future lands, and because the whole
/// screen is under the scope, that single rebuild repaints everything.
class ThemedScaffold extends ConsumerWidget {
  const ThemedScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;

  /// When null, no app bar is built at all (full-bleed screens).
  final String? title;

  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive chrome from the live theme; bootstrap while it loads / on error.
    // maybeWhen keeps the loading + error cases collapsed onto the same floor
    // so there is never an un-themed flash of a different kind.
    final data = ref.watch(effectiveThemeProvider).maybeWhen(
          // ─── THE OPACITY WAS BEING DROPPED HERE ──────────────────
          //
          // Every other builder of ChromeData passes it; this one did not, so
          // a sheet opened from a settings screen rendered fully solid while
          // the identical sheet opened from the desktop honoured the user's
          // setting. Same widget, two looks, depending only on where you
          // opened it from, which reads as a rendering fault rather than as a
          // setting that does not reach here.
          //
          // The panel material rides along for the same reason: a blur turned
          // off to stop a budget phone stuttering must be off in the sheets
          // this screen opens too, or the setting has a hole in it exactly
          // where the person went looking for it.
          data: (t) => ChromeData.fromPalette(
            t.palette,
            typography: t.typography,
            textScale: t.textScale,
            family: t.chromeFamily,
            opacity: t.surfaceOpacity,
            panelBlur: t.panelBlur,
            panelTint: t.panelTint,
            panelRadius: t.panelRadius,
          ),
          orElse: () => ChromeData.bootstrap,
        );
    final c = data.colors;

    return ChromeScope(
      data: data,
      child: Scaffold(
        backgroundColor: c.bg,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: title == null ? null : _AppBar(data: data, title: title!, actions: actions, leading: leading, implyLeading: automaticallyImplyLeading),
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}

/// A themed app bar wired entirely from [ChromeData] — it never reads the host
/// `ThemeData`, so it looks like the distro's bar, not Material's default.
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({
    required this.data,
    required this.title,
    required this.actions,
    required this.leading,
    required this.implyLeading,
  });

  final ChromeData data;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool implyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = data.colors;
    return AppBar(
      backgroundColor: c.bar,
      // A HEADER BAR, NOT AN APP BAR.
      //
      // Adwaita centres its title and separates the bar from the content with a
      // hairline rather than with elevation or a shadow. Material's default is
      // a left-aligned title on a raised surface, and left-aligned was the
      // third thing making these screens read as Android rather than as a
      // desktop settings app.
      centerTitle: true,
      // `Border` is a ShapeBorder, so the hairline rides the bar's own shape
      // and needs no `bottom:` PreferredSize wrapper eating toolbar height.
      shape: Border(bottom: BorderSide(color: c.line, width: 0.5)),
      // Kill Material 3's surface tint + elevation overlay so the bar is
      // exactly the palette's bar colour, not bar-plus-a-lavender-wash.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.text,
      iconTheme: IconThemeData(color: c.text),
      leading: leading,
      automaticallyImplyLeading: implyLeading,
      title: Text(title, style: data.text.title),
      actions: actions,
    );
  }
}
