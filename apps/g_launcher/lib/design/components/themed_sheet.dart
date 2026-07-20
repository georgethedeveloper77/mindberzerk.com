import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'chrome_theme.dart';

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

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: c.surface,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: GRadius.lg),
      ),
      builder: (ctx) => Theme(
        // CRITICAL FIX: Override the bottomSheetTheme specifically
        data: Theme.of(context).copyWith(
          bottomSheetTheme: const BottomSheetThemeData(
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: ChromeScope(
          data: data,
          child: _SheetBody(title: title, child: Builder(builder: builder)),
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
