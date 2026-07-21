import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/desklet_spec.dart';
import '../../engine/effective_theme.dart';
import 'desklet_edit.dart';

/// Add a desklet. PHASE D4.
///
/// ─── THE THEME DECIDES WHAT IS ON THE MENU ──────────────────────────────────
///
/// The list comes from `spec.desklets.offers`, not from [DeskletKinds.all], and
/// that is the visible payoff of the three-layer model: switching to Arch
/// genuinely changes what you can put on the desktop, not merely how it looks.
/// A terminal theme offers `free -h` and `df -h`; a GNOME theme does not, and
/// no code branch says so.
///
/// [DeskletKinds.resolveOffers] drops ids this build has never heard of, so a
/// theme authored against a newer app degrades to a shorter menu rather than a
/// crash. That filtering happens HERE, in the picker path only — never against
/// stored placements, which must survive untouched.
///
/// A theme that authored no offers falls back to the shipping set, because an
/// empty picker on a theme that predates this block would look like a broken
/// feature rather than a deliberate one.
Future<void> showDeskletPicker(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  required int page,
  int? col,
  int? row,
}) async {
  final fallback = const [
    'clock',
    'monitor',
    'fastfetch',
    'network',
    'storage',
    'battery',
    'notes',
    'search',
  ];

  final offers = DeskletKinds.resolveOffers(
    theme.spec.desklets.offersOr(fallback),
  );

  // Pane-only kinds never appear in a graphical picker: `df -h` on a GNOME
  // desktop would be a file manager, not a desklet. On the terminal shell they
  // are added by TYPING the command (D6), which is the authentic gesture and
  // needs no sheet at all.
  final shown = offers.where((k) => !k.paneOnly).toList();

  if (shown.isEmpty) {
    context.showMessage('This theme offers no desklets');
    return;
  }

  await ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in shown)
          ThemedListRow(
            icon: _iconFor(kind.id),
            title: kind.label,
            subtitle: _sizeLabel(kind),
            onTap: () {
              Navigator.pop(sheet);
              _add(context, ref, theme, kind, page: page, col: col, row: row);
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

void _add(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  DeskletKind kind, {
  required int page,
  int? col,
  int? row,
}) {
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  final before = ref.read(prefsProvider(theme.spec.id)).value;
  if (before == null) return;

  // Minted here, and time-based: two installs of the same theme pack must not
  // end up sharing desklet ids, which is also why theme.json's starter entries
  // carry no id of their own.
  String newId() => 'dk${DateTime.now().microsecondsSinceEpoch}';

  // An exact cell when the user tapped an empty one, otherwise wherever it
  // fits. placeAt REFUSES rather than relocating, which is right for a tap on a
  // specific square: putting the tile somewhere else would ignore the gesture.
  final after = (col != null && row != null)
      ? DeskletLayout.placeAt(
          before,
          kindId: kind.id,
          page: page,
          col: col,
          row: row,
          cols: theme.cols,
          rows: theme.rows,
          newId: newId,
        )
      : DeskletLayout.place(
          before,
          kindId: kind.id,
          page: page,
          cols: theme.cols,
          rows: theme.rows,
          newId: newId,
        );

  if (identical(after, before)) {
    // The engine refused. Say so: a picker that closes with nothing appearing
    // is the single worst outcome here, and it is exactly what a silently
    // dropped placement looks like.
    context.showMessage('No room on this workspace');
    return;
  }

  HapticFeedback.selectionClick();
  notifier.edit((_) => after);

  // Select the new tile so its handles are already showing. You added it in
  // order to place it; making you tap it again first is a wasted step.
  final added = after.desklets.last;
  ref.read(deskletEditProvider.notifier).select(added.id);
}

/// Size as cells, e.g. "2 x 1". Shown because the grid is small on a phone and
/// "System monitor" landing as a 2x3 block is worth knowing BEFORE it displaces
/// something.
String _sizeLabel(DeskletKind k) =>
    '${k.defaultSpanX} x ${k.defaultSpanY} cells';

/// Material glyphs, deliberately, and only in the picker.
///
/// Everywhere a desklet actually DRAWS, the look is the theme's. This is a
/// chrome list living inside a themed sheet, the same as Settings' rows, and
/// Settings already uses Material icons there. A per-theme picker iconography
/// would be a lot of art for a sheet people see for two seconds.
IconData _iconFor(String kindId) => switch (kindId) {
      'clock' => Icons.schedule,
      'monitor' => Icons.monitor_heart_outlined,
      'fastfetch' => Icons.terminal,
      'network' => Icons.swap_vert,
      'storage' => Icons.pie_chart_outline,
      'battery' => Icons.battery_charging_full_outlined,
      'notes' => Icons.sticky_note_2_outlined,
      'search' => Icons.search,
      _ => Icons.widgets_outlined,
    };
