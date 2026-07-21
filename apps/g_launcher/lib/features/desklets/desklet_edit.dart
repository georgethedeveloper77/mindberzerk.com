import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop edit mode. PHASE D4.
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
class DeskletEditState {
  const DeskletEditState({this.active = false, this.selected});

  final bool active;

  /// The desklet showing its resize handle and remove badge. Null means edit
  /// mode is on but nothing is picked, which is a real state: it is what you
  /// see immediately after entering, and it is when tapping an empty cell adds
  /// something there.
  final String? selected;

  DeskletEditState copyWith({bool? active, String? selected, bool clear = false}) =>
      DeskletEditState(
        active: active ?? this.active,
        selected: clear ? null : (selected ?? this.selected),
      );
}

final deskletEditProvider =
    NotifierProvider<DeskletEdit, DeskletEditState>(DeskletEdit.new);

class DeskletEdit extends Notifier<DeskletEditState> {
  @override
  DeskletEditState build() => const DeskletEditState();

  /// Not persisted, and never restored on launch, deliberately. Edit mode is a
  /// transient posture, not a preference — coming back to a phone that is still
  /// in edit mode two days later, with handles on everything, reads as a bug.
  void enter() => state = const DeskletEditState(active: true);

  void exit() => state = const DeskletEditState();

  void select(String? id) => state = id == null
      ? state.copyWith(clear: true)
      : state.copyWith(selected: id);
}
