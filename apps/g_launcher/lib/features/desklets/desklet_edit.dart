import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop edit mode. PHASE D4, widened for panels in P2.
///
/// ─── WHY THIS IS GLOBAL AND NOT LOCAL TO THE SURFACE ────────────────────────
///
/// Three things outside the desklet grid have to know about it, and none of
/// them are children of it:
///
///   * the workspace PageView, which must STOP SCROLLING while a drag is live
///     (see [DeskletEdit] below and workspace_canvas)
///   * the desktop long-press bar, which opens edit mode from its Widgets action
///   * the shells' back handling, where back should leave edit mode rather than
///     do nothing
///
/// A `setState` inside the surface could not reach any of them.

/// ─── ONE MODE, NOT TWO PROVIDERS ──────────────────────────────────────────
///
/// Panel edit could have been its own provider, and that would have been worse
/// in two specific ways. Both modes would have been able to run at once, which
/// is a state with no meaning and no UI. And back would have needed two
/// handlers, raising the question of which exits first: a question with no good
/// answer that would have had to be re-answered in every shell.
///
/// One enum makes both impossible by construction. Exactly one thing is being
/// edited, or nothing is.
enum EditMode {
  none,

  /// Desklets show resize handles and remove badges; tapping an empty cell adds.
  desklets,

  /// The panel shows remove badges on its modules, and an edit bar sits above.
  panel,

  /// The home grid jiggles: every app wobbles and carries an X.
  ///
  /// ─── A THIRD ARM RATHER THAN A SECOND PROVIDER ──────────────────────────
  ///
  /// `library_view` runs its own jiggle as LOCAL state, and its doc gives the
  /// right reason: nothing outside that view needs to know, and a drawer that
  /// reopened still jiggling would read as a bug. The home grid is the opposite
  /// case on both counts. Three things outside the grid have to know, and they
  /// are the same three this enum already exists for: the workspace pager must
  /// freeze, the desktop long press must not fire, and back must exit.
  ///
  /// So this arm buys all three for nothing. [active] is already read at nine
  /// sites and answers true here, which is correct at every one of them.
  apps,
}

class DeskletEditState {
  const DeskletEditState({this.mode = EditMode.none, this.selected});

  final EditMode mode;

  /// The desklet showing its resize handle and remove badge. Null means edit
  /// mode is on but nothing is picked, which is a real state: it is what you
  /// see immediately after entering, and it is when tapping an empty cell adds
  /// something there.
  final String? selected;

  /// ─── KEPT, AND NOW DERIVED ──────────────────────────────────────────────
  ///
  /// This was the field. Nine sites read it and NONE of them constructs this
  /// class, so turning it into a getter over [mode] left every one of them
  /// compiling and, in eight cases, doing exactly the right thing for free:
  /// freezing the pager, suppressing the desktop long press and exiting on back
  /// are all correct in EITHER mode.
  ///
  /// The ninth is `desklet_surface`, which wants [editingDesklets]. Without
  /// that distinction, editing the panel would have put resize handles on every
  /// widget on the desktop.
  bool get active => mode != EditMode.none;

  bool get editingDesklets => mode == EditMode.desklets;
  bool get editingPanel => mode == EditMode.panel;

  /// Read by `home_grid`, and by nothing else. The same narrowing
  /// `editingDesklets` exists for: without it, entering panel edit would set
  /// every app on the desktop wobbling.
  bool get editingApps => mode == EditMode.apps;

  DeskletEditState copyWith({
    EditMode? mode,
    String? selected,
    bool clear = false,
  }) =>
      DeskletEditState(
        mode: mode ?? this.mode,
        selected: clear ? null : (selected ?? this.selected),
      );
}

final deskletEditProvider =
    NotifierProvider<DeskletEdit, DeskletEditState>(DeskletEdit.new);

class DeskletEdit extends Notifier<DeskletEditState> {
  @override
  DeskletEditState build() => const DeskletEditState();

  /// Not persisted, and never restored on launch, deliberately. Edit mode is a
  /// transient posture, not a preference: coming back to a phone that is still
  /// in edit mode two days later, with handles on everything, reads as a bug.
  void enter() => state = const DeskletEditState(mode: EditMode.desklets);

  /// Entering either mode CLEARS the other, because the state can only hold
  /// one. That is the point of the enum, and it is why neither of these has to
  /// check what the other was doing first.
  void enterPanel() => state = const DeskletEditState(mode: EditMode.panel);

  /// Jiggle the apps. Nothing is [DeskletEditState.selected] in this mode: the
  /// X is on every icon at once, so there is no single thing being picked.
  void enterApps() => state = const DeskletEditState(mode: EditMode.apps);

  void exit() => state = const DeskletEditState();

  void select(String? id) => state = id == null
      ? state.copyWith(clear: true)
      : state.copyWith(selected: id);
}
