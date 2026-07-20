import 'package:collection/collection.dart';

import '../../platform/launcher_api.g.dart';
import 'drawer_layout.dart';
import 'launcher_prefs.dart';

/// Auto-grouping SUGGESTIONS for the drawer.
///
/// Pure functions over the app list plus prefs, for the same reason
/// [DrawerLayout] is pure: grouping decides where apps live, and "the launcher
/// swallowed my banking app into a folder" is the sort of bug that has to be
/// provable without a phone.
///
/// **A suggestion is never an action.** Nothing here writes; [accept] and
/// [dismiss] return a new [LauncherPrefs] for the caller to persist, and until
/// the user picks one the drawer is untouched. That is deliberate: a launcher
/// that silently rearranges your apps on first run is a launcher people
/// uninstall, however good its guesses were.
///
/// **What we will and will not guess.** Games are a real signal — Android
/// actually tells us, via the manifest category and the legacy game flag.
/// Publisher clusters are a real signal too: `com.google.android.*` is Google's
/// by construction, not by inference. Banking, "social", "productivity" and the
/// rest have NO system category behind them; guessing those means a curated
/// package list that is wrong for half the world and stale in six months, so we
/// do not promise them. A user who wants a Banking folder drags two apps
/// together, which already works.
enum SuggestionKind {
  /// Everything Android considers a game.
  games,

  /// Apps sharing a publisher prefix — the Google block, the Samsung block.
  publisher,
}

/// One proposed folder. Inert until accepted.
class FolderSuggestion {
  const FolderSuggestion({
    required this.id,
    required this.name,
    required this.kind,
    required this.componentKeys,
  });

  /// Stable across rebuilds, because it is what [LauncherPrefs.dismissedSuggestions]
  /// remembers. Derived from the GROUP, not from its current membership: install
  /// one more Google app and it is still `pub:google`, still dismissed.
  final String id;

  /// The folder's name if accepted. The user can rename it afterwards like any
  /// other folder.
  final String name;

  final SuggestionKind kind;

  /// Members, in drawer order.
  final List<String> componentKeys;

  int get size => componentKeys.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderSuggestion &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          const ListEquality<String>()
              .equals(other.componentKeys, componentKeys);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        kind,
        const ListEquality<String>().hash(componentKeys),
      );
}

class FolderSuggestions {
  const FolderSuggestions._();

  /// `ApplicationInfo.CATEGORY_GAME`. Mirrored rather than imported because the
  /// constant lives in the Android SDK and this file is pure Dart.
  static const int categoryGame = 0;

  /// Below this a folder costs more than it saves: opening a folder to reach one
  /// of three apps is worse than scrolling past three apps.
  static const int gamesThreshold = 3;

  /// Publisher groups need to be bigger to earn their place, because they are
  /// the ones that can go wrong in bulk — a "Google" folder of four is a tidy
  /// win, a "Google" folder of two is just hiding Maps.
  static const int publisherThreshold = 4;

  /// Vendor segments that are never worth grouping.
  ///
  /// `com.android.*` is the AOSP core — Phone, Contacts, Camera, Clock. They
  /// share a prefix but nothing else, and they are exactly the apps people
  /// launch individually, so folding them into a "System" folder makes the
  /// drawer worse. This is the one place a prefix lies about intent.
  static const Set<String> _skipVendors = {'android'};

  /// Package vendor segment → the name a human would recognise. Anything not
  /// here is title-cased from the segment itself, which handles the long tail
  /// ("com.spotify.*" → "Spotify") without a list to maintain.
  static const Map<String, String> _vendorNames = {
    'google': 'Google',
    'samsung': 'Samsung',
    // Samsung ships most of its stock apps under com.sec.*, so both prefixes
    // have to land in the same folder or a Galaxy user gets two.
    'sec': 'Samsung',
    'microsoft': 'Microsoft',
    'facebook': 'Meta',
    'amazon': 'Amazon',
    'adobe': 'Adobe',
    'transsion': 'Transsion',
    'infinix': 'Infinix',
    'tecno': 'Tecno',
    'xiaomi': 'Xiaomi',
    'miui': 'Xiaomi',
  };

  /// What we would propose right now, best first.
  ///
  /// Skips apps that are already in a folder (accepting one suggestion shrinks
  /// the next), and skips whole groups the user has dismissed. Returns empty
  /// when there is nothing worth saying, which is the common case on a tidy
  /// phone and is a fine answer.
  static List<FolderSuggestion> propose(
    List<AppEntry> apps,
    LauncherPrefs prefs,
  ) {
    final folded = DrawerLayout.foldedKeys(prefs);
    final loose = [
      for (final a in apps)
        if (!folded.contains(a.componentKey)) a,
    ];

    final out = <FolderSuggestion>[];

    // ── Games ────────────────────────────────────────────────────────────────
    final games = [
      for (final a in loose)
        if (a.isGame || a.category == categoryGame) a.componentKey,
    ];
    if (games.length >= gamesThreshold) {
      out.add(FolderSuggestion(
        id: 'games',
        name: 'Games',
        kind: SuggestionKind.games,
        componentKeys: games,
      ));
    }

    // ── Publisher clusters ───────────────────────────────────────────────────
    // A game already proposed for the Games folder is not offered again under
    // its publisher; one app, one suggestion, or accepting both would fight.
    final claimed = games.toSet();
    final byVendor = <String, List<String>>{};
    for (final a in loose) {
      if (claimed.contains(a.componentKey)) continue;
      final vendor = _vendorOf(a.packageName);
      if (vendor == null) continue;
      byVendor.putIfAbsent(vendor, () => <String>[]).add(a.componentKey);
    }

    for (final e in byVendor.entries) {
      if (e.value.length < publisherThreshold) continue;
      out.add(FolderSuggestion(
        id: 'pub:${e.key}',
        name: _vendorNames[e.key] ?? _titleCase(e.key),
        kind: SuggestionKind.publisher,
        componentKeys: e.value,
      ));
    }

    out.removeWhere((s) => prefs.dismissedSuggestions.contains(s.id));

    // Biggest first: the suggestion that tidies the most is the one worth
    // reading. Ties break by name so the order is stable between rebuilds
    // rather than wandering with map iteration.
    out.sort((a, b) {
      final bySize = b.size.compareTo(a.size);
      return bySize != 0 ? bySize : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Turn a suggestion into an ordinary drawer folder.
  ///
  /// Ordinary is the point: it lands in [LauncherPrefs.drawerFolders] exactly
  /// like one built by dragging two apps together, so rename, ungroup, add and
  /// remove all work on it with no special cases. The user cannot tell later
  /// which folders were suggested, and should not have to.
  static LauncherPrefs accept(
    LauncherPrefs p,
    FolderSuggestion suggestion, {
    required String Function() newFolderId,
  }) {
    // Members already filed elsewhere are dropped rather than moved: the
    // suggestion may be a rebuild behind the user's last drag.
    final folded = DrawerLayout.foldedKeys(p);
    final members = [
      for (final k in suggestion.componentKeys)
        if (!folded.contains(k)) k,
    ];
    // Below two it is not a folder. Refuse by returning the input unchanged,
    // the same contract as DrawerLayout.
    if (members.length < 2) return p;

    return p.copyWith(
      drawerFolders: [
        ...p.drawerFolders,
        AppFolder(
          id: newFolderId(),
          name: suggestion.name,
          members: members,
        ),
      ],
    );
  }

  /// Accept every suggestion in one go.
  ///
  /// Applied left to right so each accept sees the folders the previous one
  /// made — which is what stops two suggestions claiming the same app when a
  /// game also belongs to a publisher cluster.
  static LauncherPrefs acceptAll(
    LauncherPrefs p,
    List<FolderSuggestion> suggestions, {
    required String Function() newFolderId,
  }) {
    var next = p;
    for (final s in suggestions) {
      next = accept(next, s, newFolderId: newFolderId);
    }
    return next;
  }

  /// Never offer this group again.
  static LauncherPrefs dismiss(LauncherPrefs p, FolderSuggestion suggestion) {
    if (p.dismissedSuggestions.contains(suggestion.id)) return p;
    return p.copyWith(
      dismissedSuggestions: {...p.dismissedSuggestions, suggestion.id},
    );
  }

  /// Let a dismissed group be offered again — for a "reset suggestions" row.
  static LauncherPrefs clearDismissals(LauncherPrefs p) =>
      p.dismissedSuggestions.isEmpty
          ? p
          : p.copyWith(dismissedSuggestions: const {});

  /// The vendor segment of a package name: `com.google.android.youtube` →
  /// `google`. Null when the package has no usable vendor segment, or when it
  /// is one we refuse to group.
  ///
  /// Second segment, not first: the first is nearly always the TLD (`com`,
  /// `org`, `io`), which would put the entire drawer in one folder.
  static String? _vendorOf(String packageName) {
    final parts = packageName.split('.');
    if (parts.length < 2) return null;
    final vendor = parts[1].toLowerCase();
    if (vendor.isEmpty) return null;
    if (_skipVendors.contains(vendor)) return null;
    return vendor;
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
