/// The folder icon picker, opened from the folder overlay's third button.
///
/// ─── WHY A SHEET AND NOT A ROW OF SWATCHES ON THE PANEL ─────────────────────
///
/// Forty glyphs is eight rows on a phone, and the folder overlay's panel
/// already carries the title, the member grid, the page dots and three buttons.
/// Putting the catalogue inline would push the members off a short screen to
/// show a control most people touch once. A sheet costs one tap and gives the
/// grid the whole width, which is what makes forty answers scannable rather
/// than a horizontal scroll nobody discovers the end of.
///
/// ─── THE CONTEXT THIS IS CALLED WITH IS LOAD-BEARING ────────────────────────
///
/// [ThemedSheet.show] reads [ChromeScope] BEFORE it pushes, because the sheet's
/// route is not a descendant of the calling screen and a primitive built inside
/// `builder` would otherwise fall back to [ChromeData.bootstrap] and render in
/// house colours over a themed panel.
///
/// The folder overlay BUILDS its own scope, so its State's `context` sits ABOVE
/// that scope rather than below it, and calling this from there would hit
/// exactly the fallback the sheet is careful to avoid. So the overlay hands
/// down the context of a widget INSIDE the scope, which is why `_Actions.onIcon`
/// takes a [BuildContext] rather than being a plain [VoidCallback].
///
/// ─── CANCELLED AND CLEARED ARE DIFFERENT ANSWERS ────────────────────────────
///
/// Dismissing this returns null and MUST leave the folder alone. Choosing
/// Default returns [kFolderGlyphCleared], which the caller turns into a stored
/// null. Collapsing the two into one nullable would mean every accidental
/// backswipe silently wiped an icon somebody chose, and that is unrecoverable
/// from the user's side because they cannot tell it happened until later.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components/chrome_theme.dart';
import '../../design/components/themed_list_row.dart';
import '../../design/components/themed_sheet.dart';
import '../../design/tokens/radii.dart';
import '../../design/tokens/spacing.dart';
import 'folder_glyphs.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Open the picker. Null means dismissed, [kFolderGlyphCleared] means "use the
/// default", anything else is a catalogue id.
///
/// [context] must sit BELOW the caller's [ChromeScope]. See the library doc.
Future<String?> showFolderGlyphPicker(
  BuildContext context, {
  String? current,
}) {
  return ThemedSheet.show<String>(
    context,
    title: context.t('drawer.folderIcon'),
    isScrollControlled: true,
    builder: (_) => _GlyphPicker(current: current),
  );
}

class _GlyphPicker extends StatelessWidget {
  const _GlyphPicker({this.current});

  final String? current;

  /// Five across leaves 60dp cells on a 360dp screen once the sheet's own
  /// margin is taken, which clears the 48dp minimum with room for the selection
  /// plate. Six would not, and four would push the catalogue to ten rows.
  static const _columns = 5;

  /// The grid's ceiling.
  ///
  /// `ThemedSheet` wraps its body in a min-height Column with the content in a
  /// [Flexible], so an unbounded grid sizes to all eight of its rows and the
  /// sheet covers the folder it is editing. Capping it scrolls instead and
  /// leaves the panel visible behind, which is what makes the choice feel like
  /// it applies to something.
  static const _maxGridHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final ids = kFolderGlyphs.keys.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A ROW, not the first cell of the grid.
        //
        // "Use the default" is a different KIND of answer from "use this
        // symbol": it is the absence of a choice, and a tile sitting among
        // forty tiles reads as a forty-first symbol. A labelled row above the
        // grid says what it does without the label having to fit in 60dp.
        ThemedListRow(
          title: context.t('drawer.defaultIcon'),
          icon: kFolderGlyphFallback,
          trailing: folderGlyphFor(current) == null
              ? Icon(Icons.check, size: 20, color: c.accent)
              : null,
          onTap: () => Navigator.of(context).pop(kFolderGlyphCleared),
        ),
        Divider(height: 0.5, thickness: 0.5, color: c.line),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxGridHeight),
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                GSpace.lg,
                GSpace.md,
                GSpace.lg,
                GSpace.lg,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                mainAxisSpacing: GSpace.sm,
                crossAxisSpacing: GSpace.sm,
              ),
              itemCount: ids.length,
              itemBuilder: (context, i) {
                final id = ids[i];
                return _Cell(
                  icon: kFolderGlyphs[id]!,
                  selected: id == current?.trim(),
                  onTap: () => Navigator.of(context).pop(id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceAlt,
          borderRadius: GRadius.smAll,
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: selected ? c.onAccent : c.text,
        ),
      ),
    );
  }
}
