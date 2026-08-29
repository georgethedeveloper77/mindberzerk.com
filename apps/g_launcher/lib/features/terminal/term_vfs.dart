/// The one place that knows which namespace a path is in.
///
/// Every file verb goes through here, so a verb cannot half work in the wrong
/// namespace. `cp notes.txt /apps/` does not silently fail and does not just
/// refuse: it says apps are installed rather than copied, and points at the
/// verb that does work. A shell that answers "permission denied" to something
/// that was never a permission question teaches the user nothing.
library;

import 'term_host.dart';
import 'term_path.dart';

/// Why a path could not be used, in the words the shell prints.
class TermVfsError {
  const TermVfsError(this.message, {this.hint});
  final String message;

  /// A second, dimmer line naming the verb that would have worked.
  final String? hint;
}

class TermListing {
  const TermListing(this.entries, {this.error});
  final List<TermEntry> entries;
  final TermVfsError? error;

  bool get failed => error != null;
}

class TermVfs {
  TermVfs(this.host);

  final TermHost host;

  /// Has the user already declined the folder grant during THIS typed line?
  ///
  /// ─── THE BUG: ONE `find` COULD OPEN THE PICKER TWENTY TIMES ──────────────
  ///
  /// [_requireGrant] fires `ACTION_OPEN_DOCUMENT_TREE` whenever storage is
  /// touched without a grant, and `find`, `tree` and `du` touch storage once per
  /// folder they walk. Decline the first picker and every recursion opened
  /// another one, because nothing remembered the answer. `ls ~` was fine, which
  /// is exactly why it would have survived a casual test and shown up on a
  /// device as the launcher jamming a system sheet on screen in a loop.
  ///
  /// Scoped to the line, not to the session: the honest moment to ask again is
  /// the next time the user deliberately types a storage verb, not the next
  /// folder a walk happens to reach.
  bool _declinedThisLine = false;

  /// Called by the engine before each typed line.
  void beginLine() => _declinedThisLine = false;

  /// `/` is not backed by anything. It holds exactly the two roots, so `ls /`
  /// is the whole mental model in two lines.
  static const List<TermEntry> _slashEntries = <TermEntry>[
    TermEntry(
      name: 'apps',
      kind: TermEntryKind.directory,
      subtitle: 'every app you can launch',
    ),
    TermEntry(
      name: 'sdcard',
      kind: TermEntryKind.directory,
      subtitle: 'the granted folder, shown as ~',
    ),
  ];

  Future<TermListing> list(TermPath path) async {
    if (path.isSlash) return const TermListing(_slashEntries);

    switch (path.root) {
      case null:
        return TermListing(const <TermEntry>[], error: _noSuch(path));

      case TermRoot.apps:
        {
          if (path.rest.isEmpty) {
            final List<TermApp> apps = await host.apps();
            return TermListing(apps.map(entryForApp).toList());
          }
          // An app is a leaf. `ls /apps/firefox` is `cat` with extra steps, and
          // pretending an app has children would be the first invented thing
          // in the shell.
          final TermApp? app = await appAt(path);
          if (app == null) {
            return TermListing(const <TermEntry>[], error: _noSuchApp(path));
          }
          return TermListing(<TermEntry>[entryForApp(app)]);
        }

      case TermRoot.files:
        {
          final TermVfsError? gate = await _requireGrant();
          if (gate != null) {
            return TermListing(const <TermEntry>[], error: gate);
          }
          final List<TermEntry>? entries = await host.list(path);
          if (entries == null) {
            return TermListing(const <TermEntry>[], error: _noSuch(path));
          }
          return TermListing(entries);
        }
    }
  }

  static TermEntry entryForApp(TermApp app) => TermEntry(
        name: app.slug,
        kind: TermEntryKind.app,
        sizeBytes: app.sizeBytes,
        subtitle: app.packageName,
      );

  /// The app a path names, by slug first and then by the same loose matching
  /// the prompt already does, so `cat /apps/firefox` still works when the entry
  /// had to become `firefox-2`.
  Future<TermApp?> appAt(TermPath path) async {
    if (path.root != TermRoot.apps || path.rest.length != 1) return null;
    return appNamed(path.rest.first);
  }

  Future<TermApp?> appNamed(String query) async {
    final String needle = query.toLowerCase();
    final List<TermApp> apps = await host.apps();
    for (final TermApp app in apps) {
      if (app.slug.toLowerCase() == needle) return app;
    }
    for (final TermApp app in apps) {
      if (app.label.toLowerCase() == needle) return app;
    }
    for (final TermApp app in apps) {
      if (app.slug.toLowerCase().startsWith(needle)) return app;
    }
    for (final TermApp app in apps) {
      if (app.label.toLowerCase().startsWith(needle)) return app;
    }
    for (final TermApp app in apps) {
      if (app.label.toLowerCase().contains(needle) ||
          app.packageName.toLowerCase().contains(needle)) {
        return app;
      }
    }
    return null;
  }

  /// Whether [path] can be stood in. Used by `cd`, which must not walk into a
  /// leaf and must not walk into a namespace that does not exist.
  Future<TermVfsError?> canEnter(TermPath path) async {
    if (path.isSlash) return null;
    switch (path.root) {
      case null:
        return _noSuch(path);
      case TermRoot.apps:
        if (path.rest.isEmpty) return null;
        return const TermVfsError(
          'not a directory',
          hint: 'an app is a leaf. cat it to read it, open it to launch it',
        );
      case TermRoot.files:
        {
          final TermVfsError? gate = await _requireGrant();
          if (gate != null) return gate;
          final TermEntry? entry = await host.stat(path);
          if (entry == null) return _noSuch(path);
          if (!entry.isDirectory) return const TermVfsError('not a directory');
          return null;
        }
    }
  }

  Future<TermEntry?> stat(TermPath path) async {
    if (path.isSlash) {
      return const TermEntry(name: '/', kind: TermEntryKind.directory, childCount: 2);
    }
    switch (path.root) {
      case null:
        return null;
      case TermRoot.apps:
        {
          if (path.rest.isEmpty) {
            final List<TermApp> apps = await host.apps();
            return TermEntry(
              name: 'apps',
              kind: TermEntryKind.directory,
              childCount: apps.length,
            );
          }
          final TermApp? app = await appAt(path);
          return app == null ? null : entryForApp(app);
        }
      case TermRoot.files:
        if (!host.filesGranted) return null;
        return host.stat(path);
    }
  }

  Future<int?> sizeOf(TermPath path) async {
    if (path.root == TermRoot.apps) {
      if (path.rest.isEmpty) {
        final List<TermApp> apps = await host.apps();
        var total = 0;
        var measured = false;
        for (final TermApp app in apps) {
          final int? size = app.sizeBytes;
          if (size == null) continue;
          measured = true;
          total += size;
        }
        return measured ? total : null;
      }
      final TermApp? app = await appAt(path);
      return app?.sizeBytes;
    }
    if (path.root == TermRoot.files) {
      if (!host.filesGranted) return null;
      return host.sizeOf(path);
    }
    return null;
  }

  /// The gate every mutation passes.
  ///
  /// Returns the error to print, or null when the verb may proceed. [verb] is
  /// named in the refusal so the message is about what the user typed.
  Future<TermVfsError?> guardWrite(TermPath path, String verb) async {
    if (path.isSlash || path.root == null) {
      return TermVfsError(
        '$verb: / holds the two namespaces and nothing else',
        hint: 'try ~ for files or /apps to browse apps',
      );
    }
    if (path.root == TermRoot.apps) {
      return TermVfsError(
        '$verb: apps are installed, not written',
        hint: verb == 'rm'
            ? 'pm uninstall <app> opens the system prompt'
            : 'open <app> launches it, cat <app> reads its details',
      );
    }
    return _requireGrant();
  }

  /// `~` needs a folder before it means anything.
  ///
  /// Not an error the first time: the grant is a one tap system sheet, so the
  /// honest response to `cd ~` on a fresh install is to ASK, and to say so if
  /// the user declines.
  Future<TermVfsError?> _requireGrant() async {
    if (host.filesGranted) return null;
    if (_declinedThisLine) return _noGrant;
    final bool granted = await host.requestFilesAccess();
    if (granted) return null;
    _declinedThisLine = true;
    return _noGrant;
  }

  static const TermVfsError _noGrant = TermVfsError(
    'no folder granted yet',
    hint: 'grant one folder once and every file verb works inside it',
  );

  TermVfsError _noSuch(TermPath path) =>
      TermVfsError('${path.display}: no such file or directory');

  TermVfsError _noSuchApp(TermPath path) => TermVfsError(
        '${path.display}: no app by that name',
        hint: 'ls /apps lists them',
      );
}
