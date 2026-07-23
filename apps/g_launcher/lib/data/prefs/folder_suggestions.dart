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
/// by construction, not by inference.
///
/// **Social is the one exception, and it is a narrow one.** Android DOES have
/// `CATEGORY_SOCIAL`, so unlike Banking there is a system signal to start from.
/// It is just a weak one: declaring a category is optional and most of the apps
/// people actually mean by "social" declare nothing, so the category alone
/// produces a folder with three apps in it and everyone's chat apps left
/// outside. The category is therefore backed by an EXPLICIT package list of
/// apps that are unambiguously social — see [socialPackages] — and nothing
/// else is inferred. That list is a liability we accept for one folder; it is
/// not a precedent for guessing the rest.
///
/// Banking, "productivity", "finance" and the rest still have no system
/// category and no defensible list, so we do not promise them. A user who wants
/// a Banking folder drags two apps together, which already works.
enum SuggestionKind {
  /// Everything Android considers a game.
  games,

  /// Messaging and social apps. See [FolderSuggestions.socialPackages] for
  /// exactly how far we are willing to guess.
  social,

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

  /// `ApplicationInfo.CATEGORY_SOCIAL`. Same mirroring, same reason.
  ///
  /// Do not "tidy" these into an enum ordered by name: the values are the
  /// platform's, and getting one wrong files every photo app under Social with
  /// no error anywhere.
  static const int categorySocial = 4;

  /// Below this a folder costs more than it saves: opening a folder to reach one
  /// of three apps is worse than scrolling past three apps.
  static const int gamesThreshold = 3;

  /// Social uses the same floor as games: two chat apps in a folder is worse
  /// than two chat apps in the list.
  static const int socialThreshold = 3;

  /// Apps that ARE social, listed rather than inferred.
  ///
  /// **Package names, not labels.** Labels are localised, renamed by OEMs and
  /// duplicated ("Messages" is four different apps), so matching on them would
  /// be wrong in a different language every time. Package names are stable.
  ///
  /// Deliberately absent: YouTube and YouTube Kids (video, and filing them under
  /// Social means someone's kid's app moves on first run for no reason), Gmail
  /// and every SMS app (they are the phone's own furniture, and hiding Messages
  /// in a folder is exactly the "the launcher swallowed my app" complaint), and
  /// anything dating — a Tinder icon appearing inside a folder called Social on
  /// a shared phone is a consequence this feature should not be able to cause.
  ///
  /// This list will go stale. That is fine and expected: staleness here means a
  /// new app is not auto-filed, which is the harmless direction. It should
  /// eventually ship as CDN data next to the brand pack so it can be corrected
  /// without a release — until then, additive edits here are cheap.
  static const Set<String> socialPackages = {
    // Messaging
    'org.telegram.messenger',
    'org.telegram.plus',
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.thoughtcrime.securesms', // Signal
    'com.facebook.orca', // Messenger
    'com.facebook.mlite',
    'jp.naver.line.android',
    'com.viber.voip',
    'com.imo.android.imoim',
    'com.imo.android.imoimbeta',
    'com.tencent.mm', // WeChat
    'com.kakao.talk',
    'com.discord',
    'com.skype.raider',

    // Networks
    'com.instagram.android',
    'com.instagram.barcelona', // Threads
    'com.zhiliaoapp.musically', // TikTok
    'com.ss.android.ugc.trill', // TikTok, some regions
    'com.zhiliaoapp.musically.go',
    'com.twitter.android', // X
    'com.facebook.katana',
    'com.facebook.lite',
    'com.snapchat.android',
    'com.pinterest',
    'com.reddit.frontpage',
    'com.linkedin.android',
    'com.tumblr',
    'com.vkontakte.android',
    'tv.twitch.android.app',
    'org.joinmastodon.android',
    'xyz.blueskyweb.app',
  };

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

    // ── Social ───────────────────────────────────────────────────────────────
    // The curated list OR the system category, and the list first: a phone
    // whose OEM tags nothing still gets a correct Social folder, and a phone
    // whose OEM tags generously does not get its camera in one.
    //
    // Games are excluded before we look. Discord is arguably both, and a game
    // that also chats belongs with the games — that is the folder its owner
    // opens.
    final gameKeys = games.toSet();
    final social = [
      for (final a in loose)
        if (!gameKeys.contains(a.componentKey) &&
            (socialPackages.contains(a.packageName) ||
                a.category == categorySocial))
          a.componentKey,
    ];
    if (social.length >= socialThreshold) {
      out.add(FolderSuggestion(
        id: 'social',
        name: 'Social',
        kind: SuggestionKind.social,
        componentKeys: social,
      ));
    }

    // ── Publisher clusters ───────────────────────────────────────────────────
    // A game or a social app already proposed is not offered again under its
    // publisher; one app, one suggestion, or accepting both would fight. This
    // matters more with Social in play: without it Meta's block would try to
    // claim WhatsApp, Instagram and Messenger back out of the Social folder.
    final claimed = {...gameKeys, ...social};
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

  /// The folders a fresh install should simply HAVE.
  ///
  /// ─── WHY THIS IS NOT `acceptAll(propose(...))` ─────────────────────────────
  ///
  /// Auto-creating publisher folders on first run is the exact failure the rest
  /// of this file is written to avoid: a stranger's phone opening with its
  /// Google apps already swept into a folder nobody asked for. Games and Social
  /// are different — they are the two folders people make by hand within the
  /// first week, they are named the same way in every launcher, and both are
  /// backed by something better than a prefix. So those two are created, the
  /// rest are still only ever offered.
  ///
  /// Called once, at the end of initial setup, where it is visible and
  /// reversible: the setup step says what it is about to do and the user can
  /// ungroup either folder in two taps afterwards. Do NOT call it on every
  /// launch — a folder the user dissolved must stay dissolved, and the only
  /// thing stopping this from rebuilding it is that it is never asked again.
  static const Set<SuggestionKind> defaultKinds = {
    SuggestionKind.games,
    SuggestionKind.social,
  };

  static LauncherPrefs createDefaults(
    LauncherPrefs p,
    List<AppEntry> apps, {
    required String Function() newFolderId,
  }) {
    final wanted = [
      for (final s in propose(apps, p))
        if (defaultKinds.contains(s.kind)) s,
    ];
    return acceptAll(p, wanted, newFolderId: newFolderId);
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
