/// The pickers a settings row opens: shape, grid, stepper, slider.
///
/// Separate from the rows for one reason worth stating: a row is a thing on
/// screen and a sheet is a thing that happens over it, and mixing them meant
/// half the file's height was modal code that nothing on the page could see.
///
/// Every one of these dresses itself from [SettingsSkin] and lands through
/// `ThemedSheet`, so a picker cannot arrive in Material's default clothes over
/// a distro-themed page.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/data/update/update_repository.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../engine/font_catalogue.dart';
import 'settings_rows.dart';

/// [scrollControlled] is OPT-IN and off by default, which keeps every existing
/// sheet behaving exactly as it did.
///
/// Without it `showModalBottomSheet` caps the sheet at nine sixteenths of the
/// screen, and a child taller than that does not scroll or shrink: it overflows
/// and paints the yellow-and-black stripes. That is fine for the pickers here
/// that offer four to seven fixed rows and cannot grow. It is not fine for a
/// list of eighty-five families, which is why the font picker passes true and
/// bounds its own height instead.
Future<T?> settingsSheet<T>(
  BuildContext context,
  Widget child, {
  bool scrollControlled = false,
}) {
  final data = ChromeScope.of(context);
  final s = SettingsSkin.fromData(data);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.card,
    isScrollControlled: scrollControlled,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ChromeScope(data: data, child: SafeArea(child: child)),
  );
}

Widget settingsSheetHead(BuildContext context, String title) {
  final s = SettingsSkin.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: s.card2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: s.tx,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

void showShapeSheet(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) {
  const shapes = <String, String>{
    '_theme': 'Distro default',
    'roundedSquare': 'Rounded square',
    'circle': 'Circle',
    'squircle': 'Squircle',
    'square': 'Square',
    'teardrop': 'Teardrop',
    'original': 'Original (unthemed)',
  };
  final current = theme.prefs.iconTreatment ?? '_theme';

  settingsSheet<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsSheetHead(context, 'Icon shape'),
        for (final e in shapes.entries)
          SheetOption(
            label: e.value,
            selected: e.key == current,
            onTap: () {
              notifier.edit(
                (p) => e.key == '_theme'
                    // copyWith can't null a field — that's what clearing is for.
                    ? p.clearing(iconTreatment: true, cornerRadius: true)
                    : p.copyWith(iconTreatment: e.key),
              );
              Navigator.pop(context);
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

void showGridSheet(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) {
  settingsSheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            settingsSheetHead(context, 'Desktop grid'),
            StepRow(
              label: context.t('settings.rows'),
              value: theme.rows,
              min: 3,
              max: 8,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(rows: v));
                setSheet(() {});
              },
            ),
            StepRow(
              label: context.t('settings.columns'),
              value: theme.cols,
              min: 3,
              max: 7,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(cols: v));
                setSheet(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    ),
  );
}

void showStepperSheet(
  BuildContext context, {
  required String title,
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) {
  settingsSheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        var v = value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            settingsSheetHead(context, title),
            StepRow(
              label: title,
              value: v,
              min: min,
              max: max,
              onChanged: (next) {
                v = next;
                onChanged(next);
                setSheet(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    ),
  );
}

/// Slider sheet. Tracks the thumb at 60fps locally; commits ONLY on release —
/// every commit rewrites prefs and, for icons, invalidates the native cache, so
/// committing per drag-frame would re-render every icon dozens of times a second.
void showSliderSheet(
  BuildContext context, {
  required String title,
  required double value,
  required double min,
  required double max,
  required String Function(double) format,
  required ValueChanged<double> onCommit,
}) {
  var live = value.clamp(min, max).toDouble();

  settingsSheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final s = SettingsSkin.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              settingsSheetHead(context, title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  format(live),
                  style: TextStyle(
                    color: s.acc,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: s.acc,
                  thumbColor: s.acc,
                  inactiveTrackColor: s.card2,
                  overlayColor: s.acc.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: live,
                  min: min,
                  max: max,
                  onChanged: (v) => setSheet(() => live = v),
                  onChangeEnd: onCommit,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// The font picker, for either the display family or the mono one.
///
/// ─── SCROLLABLE, UNLIKE EVERY OTHER SHEET HERE ──────────────────────────────
///
/// The others offer four to seven options and fit. This one offers eighty-five,
/// so the option list is a [ListView] inside a height-constrained box rather
/// than a Column that would overflow off the bottom of the screen.
///
/// ─── THE ROWS ARE NOT SET IN THE FAMILY THEY NAME, AND THAT IS A CHOICE ─────
///
/// Showing each name in its own face is the obviously better picker, and it was
/// left out of this cut deliberately. Rendering it requires REGISTERING the
/// family, `FontLoader` has no unregister, and scrolling this list would stack
/// eighty-five families into the process for the life of it. On the budget
/// phones this ships for that is not a preview, it is a leak.
///
/// The honest version fetches on demand for the visible window and holds a
/// bounded set. Worth building; not worth blocking the feature on.
///
/// ─── WHY MONO GETS A DIFFERENT LIST AND A DIFFERENT SYSTEM ROW ──────────────
///
/// `terminal_screen.dart` computes the PTY column count by measuring a run of
/// glyphs in the mono family and sends that number to the remote host. A
/// proportional face there makes the count too generous and the host formats
/// for a width the screen does not have. So the mono list is filtered to
/// monospace, and its system row offers Android's `monospace` alias rather than
/// the platform default, which is proportional.
void showFontSheet(
  BuildContext context,
  PrefsNotifier notifier, {
  required String title,
  required bool mono,
  required String? current,
  required List<FontEntry> catalogue,
}) {
  // '_theme' never reaches storage. It is the sheet's way of spelling the null
  // that means "no preference", exactly as showShapeSheet does.
  const distroKey = '_theme';
  final selected = current ?? distroKey;
  final systemKey = mono ? systemMonoChoice : systemChoice;

  settingsSheet<void>(
    context,
    scrollControlled: true,
    // ─── WHY THIS SHEET SIZES ITSELF AND THE OTHERS DO NOT ─────────────────
    //
    // The default sheet is capped at nine sixteenths of the screen and does not
    // scroll, so a fixed 360 of list under a head and two rows overflowed the
    // bottom by about seventy pixels on a normal phone. Raising or lowering that
    // constant only moves which phone it happens on.
    //
    // So: scroll-controlled, which lets the sheet be as tall as it asks for, and
    // a ceiling expressed as a FRACTION of the screen rather than a number of
    // pixels. Flexible then gives the list whatever is left after the fixed rows
    // above it, on any screen, with no arithmetic that can drift.
    ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingsSheetHead(context, title),
          SheetOption(
            label: "The distro's own font",
            selected: selected == distroKey,
            onTap: () {
              notifier.edit(
                // copyWith cannot write null; clearing is what reaches the
                // distro default.
                (p) => mono
                    ? p.clearing(monoFont: true)
                    : p.clearing(displayFont: true),
              );
              Navigator.pop(context);
            },
          ),
          SheetOption(
            label: mono ? 'System monospace' : 'System font',
            selected: selected == systemKey,
            onTap: () {
              notifier.edit(
                (p) => mono
                    ? p.copyWith(monoFont: systemKey)
                    : p.copyWith(displayFont: systemKey),
              );
              Navigator.pop(context);
            },
          ),
          if (catalogue.isNotEmpty)
            // Flexible, not a fixed height: it takes whatever the ConstrainedBox
            // above has left after the head and the two rows, so the list ends
            // exactly at the sheet's bottom on any screen. ListView still builds
            // its rows lazily inside it.
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: catalogue.length,
                itemBuilder: (context, i) {
                  final entry = catalogue[i];
                  return SheetOption(
                    label: entry.family,
                    previewFamily: entry.family,
                    previewText: entry.sampleFor(mono: mono),
                    selected: selected == entry.family,
                    onTap: () {
                      notifier.edit(
                        (p) => mono
                            ? p.copyWith(monoFont: entry.family)
                            : p.copyWith(displayFont: entry.family),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.previewFamily,
    this.previewText,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Draw [previewText] in this family instead of drawing [label] in the
  /// interface font. Null for every non-font sheet, which is all of them but
  /// one.
  final String? previewFamily;

  /// Null falls back to [label]. The font picker passes a longer string for
  /// monospace families; see [FontEntry.sampleText].
  final String? previewText;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    final colour = selected ? s.acc : s.tx;
    final family = previewFamily;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: family == null
                  ? Text(
                      label,
                      style: TextStyle(
                        color: colour,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    )
                  : _FontPreview(
                      family: family,
                      text: previewText ?? label,
                      colour: colour,
                      fallback: label,
                      bold: selected,
                    ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: s.acc),
          ],
        ),
      ),
    );
  }
}

/// One row of the font picker, set in the family it names.
///
/// ─── PREVIEWS ARE THE POINT, NOT A GARNISH ──────────────────────────────────
///
/// Eighty-five family names in one typeface is a quiz, not a picker: nobody
/// chooses between Manrope and Figtree from the words. And for monospace it is
/// strictly impossible, because Fira Code and Fira Mono differ in exactly one
/// thing, the coding ligatures, so a list that cannot draw `=>` cannot tell
/// them apart at all.
///
/// ─── WHY THIS IS A Text AND NOT AN Image ────────────────────────────────────
///
/// It was an image, briefly, rasterised natively to avoid registering eighty-five
/// families with `FontLoader`, which has no unregister. That was a real concern
/// and the wrong trade: it needed a Pigeon round trip, a native renderer, a
/// certificate array and a bitmap cache, to render text that `google_fonts`
/// draws in one line.
///
/// The leak is real and bounded. A user who scrolls the whole list leaves every
/// family they passed resident for the life of the process, a few megabytes on
/// a screen almost nobody opens twice. If that ever shows up in a memory
/// profile the answer is to cap the list, not to rebuild the renderer.
///
/// ─── LIGATURES COME FREE ────────────────────────────────────────────────────
///
/// Flutter shapes through HarfBuzz, which applies `calt` by default, so Fira
/// Code's arrows render as arrows without anything being asked for.
class _FontPreview extends StatelessWidget {
  const _FontPreview({
    required this.family,
    required this.text,
    required this.colour,
    required this.fallback,
    required this.bold,
  });

  final String family;
  final String text;
  final Color colour;
  final String fallback;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: colour,
      fontSize: 15,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    );

    TextStyle style;
    try {
      // Returns immediately with a fallback face and fetches in the background.
      // Registering the font relayouts the text that uses it, so the row corrects
      // itself when the bytes land with no listener and no rebuild of ours.
      style = GoogleFonts.getFont(family, textStyle: base);
    } catch (e) {
      // A family the package does not know, which means the catalogue and the
      // package's manifest have drifted. The row still names the font and is
      // still selectable; it just cannot show it.
      debugPrint('Font preview unavailable for $family: $e');
      return Text(fallback, style: base, maxLines: 1);
    }

    return Text(
      text,
      style: style,
      maxLines: 1,
      // Cut at the right edge rather than squeezed. The mono samples are long,
      // and scaling them down would misrepresent the very letterforms the row
      // exists to show.
      overflow: TextOverflow.clip,
      softWrap: false,
    );
  }
}

Future<void> confirmReset(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) async {
  // ThemedDialog captures + re-provides the chrome across the route boundary and
  // pops on the dialog's own context — the two things the old hand-rolled
  // AlertDialog got right only by luck of a single navigator.
  // ─── THE COPY USED TO OVERSTATE WHAT THIS DID ─────────────────────────
  //
  // It promised icon shape would go back to the distro default and called
  // `resetAll`, which clears one theme's file. Icon shape is a PROMOTED
  // field, so it lived in the global bucket and was re-applied the instant
  // the provider rebuilt. `resetEverything` clears both, which is what this
  // message has always described.
  //
  // And it said "hidden apps", which is content. A reset does not un-hide
  // apps; the drawer's own screen does that.
  final ok = await ThemedDialog.confirm(
    context,
    title: context.t('settings.resetSettings'),
    message:
        'Every setting for ${theme.spec.name}, and the settings shared by all '
        'distros, go back to their defaults. Other distros keep their own '
        'layouts. Nothing you made is removed: your folders, pinned apps, '
        'hidden apps, widgets and photos are untouched.',
    confirmLabel: context.t('settings.reset'),
    cancelLabel: context.t('common.cancel'),
  );
  if (ok == true) notifier.resetEverything();
}

/// Asked before an update restart, never after.
///
/// ─── WHY IT LIVES HERE AND NOT AT EITHER CALL SITE ──────────────────────────
///
/// Two surfaces offer the restart: the banner on the Settings landing and the
/// About row one page deeper. They are never on screen together, which is
/// exactly the condition under which two copies of a warning drift apart, and a
/// warning that says something different in two places is worse than one that
/// says it badly in one. Next to [confirmReset] because it is the same kind of
/// thing: the sentence said before an irreversible-looking action.
///
/// `completeFlexibleUpdate` restarts the process, and this process is drawing
/// the home screen. Naming that before the tap is the whole difference between
/// an update and something indistinguishable from a crash.
Future<void> confirmUpdateRestart(
  BuildContext context,
  AppUpdateNotifier notifier,
) async {
  final ok = await ThemedDialog.confirm(
    context,
    title: context.t('settings.update.restartTitle'),
    message: context.t('settings.update.restartBody'),
    confirmLabel: context.t('settings.update.restart'),
    cancelLabel: context.t('common.cancel'),
  );
  if (ok == true) await notifier.completeUpdate();
}

// ─────────────────────────────────────────────────────────────────────────────
// The two stateful cards
// ─────────────────────────────────────────────────────────────────────────────
