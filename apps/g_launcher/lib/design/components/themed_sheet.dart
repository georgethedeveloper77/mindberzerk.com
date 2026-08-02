import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import 'chrome_theme.dart';
import 'glass_panel.dart';

/// A themed modal bottom sheet.
///
/// The important detail is the route boundary: `showModalBottomSheet` pushes a
/// route that is NOT a descendant of the calling screen's [ChromeScope], so a
/// primitive built inside `builder` would read [ChromeData.bootstrap] and the
/// sheet would render in house colours over a themed screen. So [show] reads
/// the data BEFORE pushing and re-wraps the sheet body in a fresh
/// [ChromeScope]. Any new modal must do the same.
class ThemedSheet {
  const ThemedSheet._();

  /// Show a themed sheet. Returns whatever the sheet pops with.
  ///
  /// [title] renders a header row with a grab handle above [builder]'s content.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    bool isScrollControlled = false,
  }) {
    // Capture the live chrome from the screen that's opening the sheet.
    final data = ChromeScope.of(context);
    final c = data.colors;

    // TOP CORNERS ONLY, from the shared setting. The sheet cannot pass the
    // radius straight to GlassPanel because its bottom two corners run off the
    // screen and rounding them would cut a notch out of the display edge; so it
    // builds its own shape from the same number rather than keeping a literal
    // that the setting would silently fail to move.
    final top = BorderRadius.vertical(top: Radius.circular(data.panelRadius));

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      // TRANSPARENT, because the sheet paints itself below. Leaving the colour
      // here would put an opaque slab behind the translucent one and the blur
      // would have nothing to blur.
      backgroundColor: Colors.transparent,
      // Lighter than it was. The sheet is now see-through, so a heavy scrim
      // behind it darkens the very wallpaper the translucency exists to show.
      barrierColor: Colors.black.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(borderRadius: top),
      builder: (ctx) => Theme(
        // CRITICAL FIX: Override the bottomSheetTheme specifically
        data: Theme.of(context).copyWith(
          bottomSheetTheme: const BottomSheetThemeData(
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: ChromeScope(
          data: data,
          child: GlassPanel(
            borderRadius: top,
            // Top edge only: the other three run off the screen, and a full
            // border would draw two hairlines down the sides of the display.
            border: Border(top: BorderSide(color: c.lineStrong)),
            child: _SheetBody(title: title, child: Builder(builder: builder)),
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle.
          Padding(
            padding: const EdgeInsets.only(top: GSpace.md, bottom: GSpace.sm),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.lg,
                GSpace.sm,
                GSpace.lg,
                GSpace.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title!, style: d.text.title),
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

