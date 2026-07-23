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
sealed class DrawerDrag {
  const DrawerDrag();
}

/// A real app, identified by its component key.
class AppDrag extends DrawerDrag {
  const AppDrag(this.componentKey);

  final String componentKey;
}

/// A drawer folder, identified by its folder id.
class FolderDrag extends DrawerDrag {
  const FolderDrag(this.folderId);

  final String folderId;
}
