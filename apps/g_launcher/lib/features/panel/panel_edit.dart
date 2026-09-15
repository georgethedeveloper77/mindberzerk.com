/// The writes behind panel edit mode.
///
/// ─── DATA OPS, NOT THE UI ──────────────────────────────────────────────────
///
/// The edit bar, the Add sheet and the app picker are still shells' own for
/// now. These four functions are not: `PanelBar` calls the remove and the
/// reorder from the slot badges, and the edit bar calls the add and the height
/// from its own controls, so leaving them inside one shell would mean the bar
/// every shell draws depending on the KDE file.
///
/// ─── EVERY EDIT IS A REWRITE ───────────────────────────────────────────────
///
/// The whole list goes to prefs, never a diff. `LauncherPrefs.panelModules`
/// explains why: an instruction that says "swap slots two and three" means
/// something different after the distro republishes its panel, and a list does
/// not. The same argument covers removal and insertion, so all three write the
/// full list and read back through the resolver.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show PanelItem, PanelModule;
import 'panel_skin.dart';

/// Plasma's panel when the theme authors none.
///
/// The exact order the hardcoded Row had, kept as a constant rather than
/// written into the KDE theme.json alone, because EVERY plasma-shell distro
/// falls back here: Manjaro and Garuda both use this shell and neither should
/// need to restate the obvious to get a working panel.
///
/// No spacer. [PanelModule.tasks] is the flexible one, so the fixed modules
/// pack to both ends on their own.
///
/// ─── EXPANDED, BECAUSE THIS LIST NEVER MEETS THE PARSER ────────────────────
///
/// Every other panel in the app arrives through `PanelItem.parseAll`, which is
/// where `tray` becomes these three. This one is a literal in Dart and would
/// have been the single panel in the app still carrying the old cluster, on
/// exactly the distros that author no panel and are least likely to be checked.
const List<PanelModule> defaultPanelModules = [
  PanelModule.kickoff,
  PanelModule.tasks,
  PanelModule.pager,
  PanelModule.wifi,
  PanelModule.volume,
  PanelModule.battery,
  PanelModule.clock,
];

/// What is on the panel right now, authored or fallen back to.
///
/// ─── ONE READING, BECAUSE THREE CALLERS ASK ────────────────────────────────
///
/// The bar draws from this, the Add sheet decides what is already present from
/// it, and every edit writes back over it. Three copies of the same walk would
/// drift the first time either fallback changed.
///
/// ─── IT MATCHES THE RESOLVED EDGE, NOT `bottom` ────────────────────────────
///
/// This asked for the panel on the BOTTOM edge, hardcoded, which was true while
/// the KDE shell was the only thing with a panel and it never moved. It made
/// every edit on a top-edge distro a no-op, and silently: Garuda draws its
/// panel at the top, so this fell through to the default list, the bar rendered
/// THAT, a removal wrote a list derived from it, and the next read fell through
/// to the default list again. Modules could be reordered and removed all day
/// and the panel never changed, because nothing was ever reading what was
/// written.
///
/// `theme.panelSide` is the resolved edge, which is what `PanelBar` already
/// draws at, so matching on it is also the only way this function and the bar
/// can agree about which panel they are talking about.
///
/// The single-panel fallback catches a theme whose one authored panel sits on
/// an edge `panelSide` does not name. Its modules are still the right answer;
/// the defaults never are when a real panel exists.
List<PanelItem> currentPanelItems(EffectiveTheme theme) {
  for (final p in theme.panels) {
    if (p.side == theme.panelSide) return p.items;
  }
  if (theme.panels.length == 1) return theme.panels.single.items;
  return defaultPanelModules.map(PanelItem.new).toList();
}

/// Drop the module at [index].
void removePanelModule(
  WidgetRef ref,
  EffectiveTheme theme,
  List<PanelItem> items,
  int index,
) {
  HapticFeedback.mediumImpact();
  final kept = [
    for (var i = 0; i < items.length; i++)
      if (i != index) items[i].toStorage(),
  ];
  // ─── NO UNDO ──────────────────────────────────────────────────────────
  //
  // There was a `panelUndoProvider` and a strip on the panel's edge, and both
  // existed to cover a mis-tap on a 16dp badge. Removal now happens on a 56dp
  // row that names the module, and the row it removes reappears one tap away in
  // the group below, so the recovery is the list itself.
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => p.copyWith(panelModules: kept));
}

/// Append [add] to the panel.
///
/// APPENDED, never inserted. The panel is reorderable by drag, so an insertion
/// point would be a second way to say the same thing, and the sheet has no
/// obvious place to ask for one.
void addPanelModule(
  WidgetRef ref,
  EffectiveTheme theme,
  List<PanelItem> items,
  PanelItem add,
) {
  HapticFeedback.mediumImpact();
  final next = [for (final e in items) e.toStorage(), add.toStorage()];
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => p.copyWith(panelModules: next));
}

/// Move one module from [from] to [to].
void reorderPanelModule(
  WidgetRef ref,
  EffectiveTheme theme,
  List<PanelItem> items,
  int from,
  int to,
) {
  if (from == to) return;
  HapticFeedback.mediumImpact();

  final next = [...items];
  final moved = next.removeAt(from);
  // Removing first shifts everything after it, so a rightward move needs the
  // index it left behind. This is the off-by-one `onReorderItem` exists to
  // absorb elsewhere; here the drag reports a target SLOT, so it is corrected
  // once, in the one place that does the move.
  next.insert(from < to ? to - 1 : to, moved);

  ref.read(prefsProvider(theme.spec.id).notifier).edit(
        (p) => p.copyWith(
          panelModules: [for (final e in next) e.toStorage()],
        ),
      );
}

/// Set the panel's thickness, clamped to the stepper's range.
void setPanelHeight(WidgetRef ref, EffectiveTheme theme, double dp) {
  HapticFeedback.selectionClick();
  ref.read(prefsProvider(theme.spec.id).notifier).edit(
        (p) => p.copyWith(
          panelHeight: dp.clamp(minPanelHeight, maxPanelHeight),
        ),
      );
}
