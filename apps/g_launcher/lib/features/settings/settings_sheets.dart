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
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import 'settings_rows.dart';

Future<T?> settingsSheet<T>(BuildContext context, Widget child) {
  final data = ChromeScope.of(context);
  final s = SettingsSkin.fromData(data);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.card,
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

class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? s.acc : s.tx,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: s.acc),
          ],
        ),
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// The two stateful cards
// ─────────────────────────────────────────────────────────────────────────────
