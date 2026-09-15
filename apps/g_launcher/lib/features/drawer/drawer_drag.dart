/// What a drawer tile carries while it is being dragged.
///
/// ─── WHY THIS IS NOT A `String` ─────────────────────────────────────────────
///
/// It was. `DragTarget<String>` carried a componentKey, which was fine while
/// only apps could be dragged. The moment folders became draggable the payload
/// had to answer a second question — "is this an app or a folder?" — and a bare
/// String cannot.
///
/// The tempting shortcut is to lean on the id prefix, since [newDrawerFolderId]
/// already stamps `df` on the front. Do not. A componentKey is
/// `package/class`, and nothing stops a package being named `df.something`, so
/// the check is a heuristic that is correct on every phone you own and wrong on
/// one you have never seen. A drag that files the wrong thing into the wrong
/// folder is unrecoverable by the user, because they cannot see what the
/// launcher thought it was holding.
///
/// Sealed, like [DrawerItem], and for the same reason: the drop handler
/// switches on it exhaustively, so a third draggable thing stops the build
/// until every target decides what it does with one.
///
/// ─── IT LEFT THE DRAWER ────────────────────────────────────────────────────
///
/// The name is now the only drawer-shaped thing about it. Three surfaces hold
/// app icons and all three had their own payload type: the drawer had this, the
/// home grid dragged a bare `int` slot index, and the GNOME dock dragged a
/// `String` entry id. Flutter matches drop targets BY TYPE, so a desktop icon
/// dropped on the dock never even reached `onWillAccept`. The three surfaces
/// were not refusing each other; they could not see each other.
///
/// One type fixes that, and [origin] is what lets a target tell a reorder from
/// an arrival without a second payload class per direction.
sealed class DrawerDrag {
  const DrawerDrag({this.from = DragOrigin.drawer, this.page, this.index});

  /// Which surface the gesture started on.
  ///
  /// Defaults to [DragOrigin.drawer] so every existing construction keeps
  /// working unchanged. That is deliberate rather than lazy: the drawer sites
  /// were written before there was anything else to be, and making them all
  /// restate it would be four files of churn saying what the default says.
  final DragOrigin from;

  /// The workspace the tile came from, when [from] is [DragOrigin.grid].
  ///
  /// Null everywhere else. A dock has no pages and the drawer's own position is
  /// held in its slot store rather than on the drag.
  final int? page;

  /// Where on that surface it came from: a grid slot, or a dock position.
  ///
  /// The grid used to send this as the WHOLE payload, which is why it could
  /// only ever talk to itself: an int means nothing without knowing which
  /// surface is counting.
  final int? index;
}

/// Which surface a drag started on.
///
/// ─── THE TARGET DECIDES, NOT THE SOURCE ────────────────────────────────────
///
/// A source says where it came from and nothing else. Whether that is allowed,
/// and whether it is a move or a copy, is the receiving surface's decision, so
/// adding a fourth surface never means editing the three that already exist.
enum DragOrigin {
  /// The app list. The only true SOURCE: dragging from a list of everything
  /// installed copies rather than moves, because the list is not a place an app
  /// can be absent from.
  drawer,

  /// The desktop grid.
  grid,

  /// The dock.
  dock,

  /// Inside an open folder.
  folder,
}

/// A real app, identified by its component key.
class AppDrag extends DrawerDrag {
  const AppDrag(
    this.componentKey, {
    super.from,
    super.page,
    super.index,
  });

  final String componentKey;
}

/// A drawer folder, identified by its folder id.
class FolderDrag extends DrawerDrag {
  const FolderDrag(
    this.folderId, {
    super.from,
    super.page,
    super.index,
  });

  final String folderId;
}
