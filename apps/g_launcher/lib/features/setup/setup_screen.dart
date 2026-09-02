import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../data/cdn/distro_packs.dart';
import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/setup_state.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../design/device_stage.dart';
import '../../design/drawer_transition.dart';
import '../../design/setting_previews.dart';
import '../../engine/desklet_spec.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_registry.dart';
import '../../engine/theme_spec.dart';
import '../../i18n/i18n.dart';
// AppEntry, for resolving a suggestion's componentKeys into icons.
import '../../platform/launcher_api.g.dart';
import '../../system/notification_badges.dart';
import '../../system/wallpaper_source.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import '../desklets/desklet_preview.dart';
import '../drawer/folder_glyph.dart';
import 'setup_chrome.dart';

/// **Initial setup, as a distro installer.** T1.
///
/// The previous version was a live full-bleed desktop with a translucent panel
/// of controls floating over it. It read as vibe-coded for a reason that is
/// worth writing down rather than re-litigating: it had no chrome, so it had no
/// identity. A preview of the product is not the product, and a panel with no
/// frame is a form.
///
/// This is an installer. [SetupInstallerFrame] owns the window, the step rail
/// and the footer; [SetupSkin] decides which installer, keyed by SHELL, so
/// choosing the terminal distro at step 3 turns the remaining steps into a
/// console and choosing Aqua turns them into a centred assistant. That live
/// re-skin is the single best demonstration the launcher has, and it costs
/// nothing extra because the theme already applies the moment it is picked.
///
/// ─── WHAT SETUP DELIBERATELY DOES NOT DO ───────────────────────────────────
///
/// **No "try it first".** Android cannot preview a home screen without the app
/// holding the home role, so the option would be a promise the launcher cannot
/// keep. It is shown, disabled, with the reason, rather than hidden: someone
/// who expects the choice should see that it was considered.
///
/// **No fiction about destroying anything.** The frame, the rail, the progress
/// and the language of an install are all here. The words "erase", "format" and
/// "partition" are not, and must not be added. A budget-phone user who
/// half-reads a screen that says "erase disk" will uninstall in a panic, and
/// they will be right to.
///
/// **The install step runs once, ever.** It is the first-run payoff, not a
/// loading screen: it is not on the theme-switch path, and switching distro in
/// Settings later shows only the boot log or the splash. See [_stepsFor].
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

/// The distros offered during setup: whatever is bundled.
///
/// There is no curated list here any more, and that is the point. Bundled
/// implies free (see theme_registry), so the set setup may offer and the set
/// that ships in the APK are the same set by construction, and a fourth
/// bundled distro appears in setup with no edit to this file.
///
/// The tier is still checked on load rather than assumed. It costs one string
/// compare and it means a paid theme accidentally left in the APK does not
/// quietly become free at first run.
/// One line describing what the desktop looks like, keyed by SHELL.
///
/// Keyed by shell for the same reason every other default in the theme layer
/// is: a new GNOME distro should inherit "top bar, dock down the left" without
/// authoring anything, and only override where it genuinely differs.
///
/// It belongs in theme.json eventually, as a `tagline` beside `name` and
/// `version`. It is here because adding a ThemeSpec field to ship one sentence
/// per shell is the wrong order to do things in.
/// Returns a KEY, not a sentence.
///
/// The strings were extracted into en.json a while ago and this switch kept
/// returning the English ones, so a French install read every distro's
/// description in English. Returning the key and resolving at the call site is
/// what lets a switch like this be translated at all: `ref.t` needs a WidgetRef
/// and a switch on an enum has no business taking one.
String _taglineKeyFor(ShellKind shell) => switch (shell) {
      ShellKind.gnome => 'setup.topBarDockDown',
      ShellKind.plasma => 'setup.bottomPanelKickoffMenu',
      ShellKind.tiling => 'setup.noDockAStatus',
      ShellKind.tui => 'setup.noDesktopAtAll',
      ShellKind.aqua => 'setup.menuBarAcrossThe',
    };

/// The specs behind [bundledThemes], loaded from their assets.
///
/// Reads the REAL [ThemeSpec] rather than a catalogue card, because the rows
/// need `name`, `version`, `tier` and `palette`, and those already exist in
/// data. A row that says "Ubuntu 24.04 LTS" should be reading 24.04 out of the
/// theme, not out of a table in Dart that will disagree with it by Christmas.
final setupDistrosProvider = FutureProvider<List<ThemeSpec>>((ref) async {
  final out = <ThemeSpec>[];
  for (final bundled in bundledThemes.values) {
    try {
      final raw = await rootBundle.loadString(bundled.assetPath);
      final spec = ThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (spec.tier != 'free') continue;
      out.add(spec);
    } catch (_) {
      // A distro that will not parse is simply not offered. The floor is
      // guaranteed elsewhere: activeThemeSpecProvider always lands on Ubuntu.
    }
  }
  return out;
});

class _SetupScreenState extends ConsumerState<SetupScreen>
    with WidgetsBindingObserver {
  /// The CURRENT step, held as the enum rather than as an index.
  ///
  /// Load-bearing. The step list is derived from the shell and SHRINKS when the
  /// user picks the terminal at the distro step, so an index would suddenly
  /// point at a different screen (or off the end) the moment they tapped. The
  /// enum survives the list changing under it.
  _SetupStep _step = _SetupStep.welcome;

  /// Folders step: ON BY DEFAULT. The suggested folders (Games first among
  /// them) are created when the user advances past the step unless they
  /// untick it — creation is the default outcome, not a button they must
  /// find. Cleared folders remain available later in Settings > Folders.
  /// Suggested folders the user has UNTICKED.
  ///
  /// ─── SKIPPED, NOT CHOSEN, AND THE DIRECTION MATTERS ─────────────────────
  ///
  /// A set of chosen names would have to be seeded from a list that is proposed
  /// asynchronously, so an empty set on the first frame would read as "the user
  /// wants none" and the step would default to off. Recording the EXCEPTIONS
  /// keeps the default at all-on with no seeding at all, which is the behaviour
  /// the old boolean had and the one the copy still promises.
  final Set<String> _skippedFolders = <String>{};

  /// Desklet kind ids to place on the first desktop.
  ///
  /// CHOSEN, not skipped, which is the opposite of [_skippedFolders] and is
  /// right for the opposite reason. Folder suggestions are proposed
  /// asynchronously, so an empty set could not be told apart from "not loaded
  /// yet". Desklet kinds are a compile-time list, so the default can simply BE
  /// the default, and unticking everything is a meaningful answer rather than
  /// an unresolved one.
  ///
  /// ─── SEEDED FROM THE DISTRO'S OWN STARTER, ONCE ───────────────────────
  ///
  /// It was a hardcoded `{fastfetch, monitor}`, which was a reasonable pair and
  /// the wrong SOURCE. `theme.json` already says what desktop a distro lays out
  /// for you (`desklets.starter`), and that is the desktop someone gets if this
  /// step does not exist. Seeding from anything else means the default answer
  /// and the no-answer outcome differ, so unticking is not a subtraction, it is
  /// a swap for an arrangement nobody chose.
  ///
  /// Ubuntu starts a clock and a conky; KDE starts a clock, a conky and a `df`
  /// that is silently dropped for being pane-only. So the ticks are what that
  /// distro would have furnished, minus what it could never draw.
  ///
  /// Null until the first build that has a theme, because the seed needs one.
  /// See [_seedWidgetChoice], and note that a distro SWIPE deliberately does
  /// not re-seed: an answer already given belongs to the person who gave it.
  Set<String>? _widgets;

  /// Suffix, because this loop mints several ids in one synchronous pass.
  int _deskletSeq = 0;

  /// Matches `terminal_commands.dart`: `dk` plus a microsecond stamp. That one
  /// mints ONE id per command and needs no more; this places up to six inside
  /// a single loop, where a repeated microsecond would give two desklets the
  /// same id and deleting either would take both.
  String _newDeskletId() =>
      'dk${DateTime.now().microsecondsSinceEpoch}${_deskletSeq++}';

  /// 'top' | 'middle' | 'bottom'. Where the chosen desklets land on page 0.
  String _widgetSpot = 'top';

  /// Badges step: ON BY DEFAULT, and it is a WANT rather than a grant.
  ///
  /// ─── WHY A TOGGLE AND NOT A ROW THAT OPENS SETTINGS ───────────────────
  ///
  /// The first version was a row with a chevron: tap it, leave the app, find
  /// the checkbox on Android's notification-access page, come back. Almost
  /// nobody takes that trip during setup, and the ones who do not are not
  /// declining badges, they are declining a detour. The wizard then moves on
  /// and the feature is silently off forever.
  ///
  /// So the step asks the question it actually wants answered, in the language
  /// the rest of the wizard already uses: a tick, exactly like the folders
  /// step's "Create 8 folders". Saying yes here costs one tap, and the system
  /// screen is opened on the way OUT of the step rather than in the middle of
  /// it, which is when the user has finished deciding.
  bool _wantBadges = true;

  /// Whether the badges step has already sent the user to the system screen.
  ///
  /// ONE ASK, and this is what stops the step becoming a trap. Continue opens
  /// the grant page when badges are wanted and not yet granted; if the user
  /// comes back having said no, pressing Continue again ADVANCES rather than
  /// sending them round the loop a second time. A wizard that cannot be left
  /// except by granting a permission is a wizard people uninstall.
  bool _badgeAsked = false;

  /// The distro whose packs have already been asked for.
  ///
  /// Entering the step and swiping the deck both want to fire this, and on a
  /// rebuild-heavy screen the build itself fires it again. One field makes all
  /// three idempotent without any of them having to know about the others.
  String? _packsAskedFor;

  /// Start (or re-start) the pack sweep for [themeId].
  ///
  /// ─── FROM THE FIRST BUILD, NOT FROM THE DISTRO STEP ───────────────────
  ///
  /// The welcome step is a language list and a home-role button, which is
  /// twenty seconds of reading during which the phone is doing nothing. The
  /// index is a couple of kilobytes behind an ETag and a distro pack is around
  /// 140KB, so starting here usually means the deck on the NEXT screen is
  /// already drawing the current copy rather than the one baked into the APK.
  ///
  /// Ubuntu is what it fetches first, because that is what
  /// `activeThemeSpecProvider` resolves to before anybody picks anything. A
  /// swipe supersedes it inside the notifier.
  ///
  /// ─── themeOnly, AND THAT IS THE WHOLE POINT OF THE SCOPE ──────────────
  ///
  /// A distro's icon pack is 491 bytes that `requires` 10.58 MB of shared
  /// drawings, and this runs before anybody has been asked anything. The icon
  /// step is where that question gets put; see [_commitIcons].
  void _ensurePacksFor(String themeId) {
    if (_packsAskedFor == themeId) return;
    _packsAskedFor = themeId;
    unawaited(
      ref.read(distroPacksProvider.notifier).ensure(
            themeId,
            scope: DistroPackScope.themeOnly,
          ),
    );
  }

  /// Fill [_widgets] from this distro's authored starter, once.
  ///
  /// ─── ONCE, AND NOT ON A SWIPE ─────────────────────────────────────────
  ///
  /// Re-seeding when the distro changes would look tidy and would throw away an
  /// answer. Someone who unticks the conky, goes back to compare KDE, and comes
  /// forward again has not changed their mind about the conky.
  ///
  /// What a swipe DOES do is change which kinds exist, so the set is intersected
  /// against the new distro's offers at render time rather than rewritten here.
  /// See [_chosenWidgets].
  void _seedWidgetChoice(EffectiveTheme theme) {
    if (_widgets != null) return;
    final offered = {for (final k in offeredDesklets(theme)) k.id};
    final starter = {
      for (final s in theme.spec.desklets.starter)
        if (offered.contains(s.kind)) s.kind,
    };
    // A distro authoring no starter, or one made entirely of pane-only kinds,
    // still gets a demonstration rather than an empty desktop. Two, because one
    // is not a demonstration and three fills a phone.
    _widgets = starter.isNotEmpty
        ? starter
        : {
            for (final id in const ['fastfetch', 'monitor'])
              if (offered.contains(id)) id,
          };
  }

  /// The ticked kinds that THIS distro can actually draw.
  ///
  /// Intersected rather than trimmed in place, so switching distro and back
  /// does not lose a choice: KDE offers no `fastfetch`, and someone who ticked
  /// it on Ubuntu, looked at KDE, and returned should still find it ticked.
  Set<String> _chosenWidgets(EffectiveTheme theme) {
    final chosen = _widgets ?? const <String>{};
    final offered = {for (final k in offeredDesklets(theme)) k.id};
    return {
      for (final id in chosen)
        if (offered.contains(id)) id,
    };
  }

  /// Does the user want the distro's own icons, or their apps' own artwork?
  ///
  /// TRUE BY DEFAULT, which is what a null pref already resolves to, so leaving
  /// the step untouched writes nothing and behaves exactly as the app did
  /// before this step existed.
  bool _distroIcons = true;

  /// Write the icon answer into THIS distro's prefs bucket, and start the
  /// download if one was agreed to.
  ///
  /// ─── ON THE WAY OUT, LIKE FOLDERS AND DESKLETS ────────────────────────
  ///
  /// Not on tap. `iconPackId` and `iconBrandPackId` are per-theme, so the
  /// answer belongs to whichever distro is selected when the step is LEFT.
  /// Someone who goes back, picks KDE and comes forward again has answered for
  /// KDE, and committing on advance is what makes that true without this widget
  /// having to track which buckets it has already written.
  ///
  /// ─── AND THE DOWNLOAD IS THE CONSENT ──────────────────────────────────
  ///
  /// Choosing the distro's icons is the moment the ten megabytes become
  /// something the user asked for. Choosing app icons fetches nothing at all,
  /// which on a metered connection is a real saving and is worth the step
  /// existing even for someone who would have taken the default.
  Future<void> _commitIcons(EffectiveTheme theme) async {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    if (_distroIcons) {
      // `clearing`, not `copyWith(x: null)`. copyWith reads a null argument as
      // "leave it alone", so a reset would silently do nothing. Clearing is
      // also righter than writing the distro's pack id: null means "whatever
      // this distro names", which keeps following a republish.
      await notifier.edit(
        (p) => p.clearing(iconPackId: true, iconBrandPackId: true),
      );
      unawaited(
        ref.read(distroPacksProvider.notifier).ensure(
              theme.spec.id,
              scope: DistroPackScope.iconsOnly,
            ),
      );
      return;
    }

    // BOTH tiers. Setting only the brand one would leave a hero pack resolving,
    // so "app icons" would mean hand-drawn art for whatever a hero pack covers
    // and generated icons for the rest. See [kNoIconPack].
    await notifier.edit(
      (p) => p.copyWith(
        iconPackId: kNoIconPack,
        iconBrandPackId: kNoIconPack,
      ),
    );
  }

  bool _isDefault = false;

  /// How many times Continue has been pressed on the home-role step.
  ///
  /// Deliberately NOT persisted: it counts presses within this wizard, and a
  /// user who reinstalls deserves the same three chances rather than inheriting
  /// a grudge from a previous install.
  int _homeAttempts = 0;
  bool _showHomeWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDefaultLauncher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// THE ONLY MOMENT THE ANSWER CAN HAVE CHANGED.
  ///
  /// This fixes a real bug: the launcher kept insisting it was not the home app
  /// after the user had just made it the home app.
  ///
  /// `requestDefaultLauncher` is a void Pigeon method. It fires an intent and
  /// returns immediately, NOT when the user finishes choosing. So the old
  /// `await request(); await refresh();` asked the question while Android's
  /// picker was still on screen, got `false`, and kept the nag for the rest of
  /// the session. The detection was always correct; the timing was not.
  ///
  /// Coming back from the picker is an app RESUME, so that is where the
  /// re-check belongs. Anywhere else in the app that shows this nag needs the
  /// same observer for the same reason.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDefaultLauncher();
  }

  Future<void> _refreshDefaultLauncher() async {
    final ok = await ref.read(launcherHostApiProvider).isDefaultLauncher();
    if (mounted) setState(() => _isDefault = ok);
  }

  /// Fire and forget, deliberately.
  ///
  /// No re-check here on purpose: see [didChangeAppLifecycleState]. Asking
  /// straight after this call is what caused the bug, so the call site is left
  /// with a comment rather than a tempting blank line.
  Future<void> _openHomePicker() async {
    await ref.read(launcherHostApiProvider).requestDefaultLauncher();
  }

  /// The three-strike gate. Returns true when the wizard may advance.
  Future<bool> _homeGate() async {
    if (_isDefault) return true;

    _homeAttempts++;
    Analytics.homeRolePrompt(attempt: _homeAttempts, granted: false);

    if (_homeAttempts == 1) {
      // Straight to Android's picker. No dialog of ours in front of it: an
      // interstitial explaining that a prompt is coming is one more thing to
      // dismiss before the thing that matters.
      await _openHomePicker();
      return _isDefault;
    }

    if (_homeAttempts == 2) {
      setState(() => _showHomeWarning = true);
      return false;
    }

    // Third press: their phone, their call.
    return true;
  }

  Future<void> _next() async {
    if (_step == _SetupStep.welcome) {
      final mayPass = await _homeGate();
      if (!mayPass) return;
    }

    // Leaving the folders step with the toggle still on creates the suggested
    // folders. On advance, not on a button: the default outcome should not
    // require finding a button, and unticking the row is the opt-out.
    // Best-effort like the desktop seeding — a grouping failure must never
    // block setup.
    if (_step == _SetupStep.folders) {
      try {
        final theme = ref.read(effectiveThemeProvider).asData?.value;
        if (theme != null) {
          final apps = ref.read(shellAppsProvider(theme));
          // FILTERED, not gated. `acceptAll` has always taken a list, so a
          // partial selection needs no new engine call: the folders the user
          // unticked simply are not in the list handed to it. Everything about
          // ids, membership and ordering stays where it already lives.
          final suggestions = FolderSuggestions.propose(apps, theme.prefs)
              .where((sg) => !_skippedFolders.contains(sg.name))
              .toList();
          if (suggestions.isNotEmpty) {
            await ref.read(prefsProvider(theme.spec.id).notifier).edit(
                  (p) => FolderSuggestions.acceptAll(
                    p,
                    suggestions,
                    newFolderId: newDrawerFolderId,
                  ),
                );
          }
        }
      } catch (e, s) {
        debugPrint('setup: creating suggested folders failed: $e\n$s');
      }
    }

    // ── DESKLETS, PLACED ON THE WAY OUT ───────────────────────────────
    //
    // Same shape as folders above and for the same reason: the default outcome
    // should not require finding a button, and advancing IS the commit.
    //
    // ─── placeAt REFUSES RATHER THAN RELOCATING ───────────────────────
    //
    // That is correct for an authored starter, where a silently reflowed tile
    // makes the whole desktop look like a mistake. It is a trap here: two
    // desklets asked for the same row collide, the second call returns the
    // prefs UNCHANGED, and a widget the user ticked simply never appears with
    // nothing reported anywhere.
    //
    // So each one is tried at its computed row, and if the prefs come back
    // identical the same kind is handed to `place`, which packs it wherever it
    // fits. Position is a preference; being present is not.
    if (_step == _SetupStep.widgets) {
      try {
        final theme = ref.read(effectiveThemeProvider).asData?.value;
        if (theme != null) {
          // THE DESKLET GRID, not the icon grid. `deskletCols` is finer:
          // `search` spans 8 of it while the home grid is 4 or 5 wide, and
          // `_clampSpanX` would have squashed every kind against the wrong
          // number. This is what `desklet_picker` passes and there is exactly
          // one right answer.
          final cols = theme.deskletCols;
          final rows = theme.deskletRows;
          var next = theme.prefs;

          // ── AN EXISTING PLACEMENT IS LEFT WHERE THE DISTRO PUT IT ──────
          //
          // `EffectiveTheme.resolve` lays out the authored `desklets.starter`
          // the first time a distro is worn, which happens at the DISTRO step,
          // before this one. So by the time the user answers, Ubuntu's clock is
          // already at (0,0) spanning 3x1, which is the arrangement its
          // screenshot shows and the reason the block is authored at all.
          //
          // This used to remove every offered kind and re-place the ticked ones
          // at their DEFAULT spans, packed left to right. Ubuntu's clock came
          // back as 4x2 at (0,0) and its conky as 4x3 at (4,0): a generic
          // arrangement, written over the authored one, on every run, even when
          // the user changed nothing at all.
          //
          // It went unnoticed because the old hardcoded shortlist happened not
          // to name `clock`, so the one authored tile that survived made the
          // result look intentional. Reading the offers list properly is what
          // exposed it.
          //
          // ─── SO THE RULE IS SUBTRACTIVE ────────────────────────────────
          //
          // Remove what was UNTICKED. Leave what was ticked and is already
          // placed exactly as it is. Place only what was ticked and is not
          // there yet. Unticking still works, which is the whole reason this
          // block exists, and ticking nothing new is now genuinely a no-op
          // rather than a silent reflow.
          //
          // Scoped to what this step OFFERED, so anything the starter placed
          // that was never asked about, and anything the user added by hand,
          // is untouched. This owns the question it asked and nothing more.
          final offeredIds = {for (final k in offeredDesklets(theme)) k.id};
          final picked = _chosenWidgets(theme);

          // Captured BEFORE the removals below, or a kind removed and re-added
          // in the same pass would read as absent and be re-placed at its
          // default, which is the bug this whole comment is about.
          final alreadyPlaced = {
            for (final dk in next.desklets)
              if (dk.page == 0) dk.kind,
          };

          for (final dk in [...next.desklets]) {
            if (dk.page != 0) continue;
            if (!offeredIds.contains(dk.kind)) continue;
            if (picked.contains(dk.kind)) continue;
            next = DeskletLayout.remove(next, dk.id);
          }

          // Ticked, offered, and not on the desktop yet, in the DISTRO'S OWN
          // offer order rather than tap order, so two people who chose the same
          // set get the same desktop. Ordering by `DeskletKinds.all` would have
          // been the shipping order rather than the one the distro authored,
          // which is the order its picker shows.
          final chosen = [
            for (final k in offeredDesklets(theme))
              if (picked.contains(k.id) && !alreadyPlaced.contains(k.id)) k,
          ];

          // ── TWO ACROSS WHERE THEY FIT ──────────────────────────────────
          //
          // `free`, `ls`, `uptime` and `df` span 2 of a grid that is 8 wide, so
          // stacking them one per row wastes three quarters of the desktop and
          // looks like a column of ribbons. Pack left to right, wrap when the
          // next one will not fit, and advance the row by the TALLEST tile in
          // the row just finished rather than by the last one placed.
          var col = 0;
          var rowTall = 0;
          final rowsUsed = <int>[];
          for (final k in chosen) {
            if (col + k.defaultSpanX > cols && col > 0) {
              rowsUsed.add(rowTall);
              col = 0;
              rowTall = 0;
            }
            col += k.defaultSpanX;
            if (k.defaultSpanY > rowTall) rowTall = k.defaultSpanY;
          }
          if (rowTall > 0) rowsUsed.add(rowTall);
          final tall = rowsUsed.fold<int>(0, (n, h) => n + h);

          // Where the block starts. Bottom subtracts the whole height so the
          // last row ENDS at the last row rather than starting there and being
          // refused off the edge.
          final spare = rows - tall;
          var cursorRow = switch (_widgetSpot) {
            'bottom' => spare,
            'middle' => spare ~/ 2,
            _ => 0,
          };
          if (cursorRow < 0) cursorRow = 0;

          col = 0;
          rowTall = 0;
          for (final k in chosen) {
            if (col + k.defaultSpanX > cols && col > 0) {
              cursorRow += rowTall;
              col = 0;
              rowTall = 0;
            }

            final before = next;
            next = DeskletLayout.placeAt(
              next,
              kindId: k.id,
              page: 0,
              col: col,
              row: cursorRow,
              cols: cols,
              rows: rows,
              newId: _newDeskletId,
            );
            // placeAt REFUSES rather than relocating, and returns the prefs
            // unchanged when it does. Correct for an authored starter, a trap
            // here: a tile the user ticked would silently never appear.
            // Position is a preference; being present is not.
            if (identical(next, before)) {
              next = DeskletLayout.place(
                next,
                kindId: k.id,
                page: 0,
                cols: cols,
                rows: rows,
                newId: _newDeskletId,
              );
            }

            col += k.defaultSpanX;
            if (k.defaultSpanY > rowTall) rowTall = k.defaultSpanY;
          }

          if (!identical(next, theme.prefs)) {
            await ref
                .read(prefsProvider(theme.spec.id).notifier)
                .edit((_) => next);
          }
        }
      } catch (e, st) {
        debugPrint('setup: placing desklets failed: $e\n$st');
      }
    }

    // ── ICONS, WRITTEN ON THE WAY OUT ─────────────────────────────────
    //
    // Same shape as folders and desklets above and for the same reason: the
    // prefs bucket belongs to whichever distro is selected as the step is left,
    // so committing here is what makes going back and choosing a different
    // distro answer for that one instead.
    //
    // Best-effort like its neighbours. An icon preference that failed to write
    // is a desktop wearing the distro default, which is recoverable from the
    // icons screen; a setup that cannot be finished is not.
    if (_step == _SetupStep.icons) {
      try {
        final theme = ref.read(effectiveThemeProvider).asData?.value;
        if (theme != null) await _commitIcons(theme);
      } catch (e, s) {
        debugPrint('setup: writing the icon choice failed: $e\n$s');
      }
    }

    // ── BADGES: THE ASK HAPPENS ON THE WAY OUT ────────────────────────
    //
    // Not on tapping the toggle. The toggle records what the user wants; this
    // is the moment they have finished deciding and are leaving, which is the
    // only point where handing them off to a system screen is not an
    // interruption.
    //
    // Skipped entirely when the permission is already granted, and skipped
    // after the first time either way. See `_badgeAsked` for why the second
    // press must advance rather than ask again.
    if (_step == _SetupStep.notifications && _wantBadges && !_badgeAsked) {
      final granted =
          ref.read(notificationAccessProvider).asData?.value ?? false;
      if (!granted) {
        _badgeAsked = true;
        await openNotificationAccessSettings();
        // STAYS on this step. The user is now looking at Android's page; when
        // they come back, the step re-reads the permission on resume and shows
        // the result, and Continue takes them onward whatever they chose.
        return;
      }
    }

    final steps = _stepsFor(_shell);
    final i = steps.indexOf(_step);
    if (i >= 0 && i < steps.length - 1) {
      setState(() => _step = steps[i + 1]);
    }
  }

  void _back() {
    final steps = _stepsFor(_shell);
    final i = steps.indexOf(_step);
    if (i > 0) setState(() => _step = steps[i - 1]);
  }

  ShellKind? get _shell => ref.read(effectiveThemeProvider).asData?.value.shell;

  /// Called by the install step when its progress completes, never by a button.
  Future<void> _finish() async {
    final themeId =
        ref.read(selectedThemeIdProvider).asData?.value ?? fallbackThemeId;
    Analytics.setupComplete(themeId: themeId, granted: _isDefault);

    // ── _seedFirstDesktop WAS HERE, AND IT NEVER PLACED ANYTHING ────────
    //
    // Its docblock called itself the only place `StarterDesktop.apply` is
    // wired in. That was not true: `EffectiveTheme.resolve` applies the starter
    // the first time a theme resolves, guarded by `deskletsInitialized`, which
    // during setup happens at the DISTRO step. By the time this ran, every
    // authored placement was already down.
    //
    // So this was a second, unguarded application, and it passed `theme.cols`
    // and `theme.rows` where resolve correctly passes `deskletCols` and
    // `deskletRows`, which are twice and three times larger. Every placement it
    // attempted therefore either collided with the one resolve had already made
    // and was refused, or would have landed at the wrong scale if it had not.
    // A device dump confirmed the first: Ubuntu's stored clock and monitor are
    // resolve's, at resolve's coordinates, and this call changed nothing.
    //
    // Removing it also fixes the ordering the widgets step depends on. Resolve
    // seeds BEFORE that step, which is what makes the step's sweep able to
    // overrule it; a second application afterwards would have put back exactly
    // what the user unticked, had it ever succeeded.

    // ── THE ICON DOWNLOAD USED TO BE HERE, AND IT WAS THE WRONG PLACE ────
    //
    // `_installDistroIcons` ran at this exact point: after the install
    // animation had reached 100%, awaited, with two sequential downloads behind
    // it. On a slow connection that is a progress bar sitting full while
    // nothing happens, on the one screen whose entire job is to say the work is
    // finished.
    //
    // It also could not work on a fresh device. It looked its packs up in
    // `catalogueProvider`, which reads the cached index, which is null until
    // something fetches one, and nothing in this wizard ever did. So both
    // lookups returned null and both `continue`d, silently, every time.
    //
    // Both are now [DistroPacks], started from the first build of this screen
    // and re-started on every swipe of the deck. By the time anyone reaches
    // this line the packs are normally already on disk, and if they are not,
    // the sweep is still running and will finish over the desktop.

    // Hand-off flag first, then the completion that swaps this screen out: the
    // desktop mounts fresh and reads the flag on that very build.
    ref.read(firstRunBootPendingProvider.notifier).state = true;
    await ref.read(setupCompletedProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    // hasValue, not asData: asData is null through a RELOAD, and every prefs
    // write is a reload. See home_screen.dart.
    final themeAsync = ref.watch(effectiveThemeProvider);
    final theme = themeAsync.hasValue ? themeAsync.requireValue : null;

    // ChromeScope is normally installed by ThemedScaffold. This screen builds
    // its own frame, so it has to provide the chrome itself, otherwise every
    // ChromeScope.of below throws. Bootstrap while the theme loads, exactly as
    // ThemedScaffold does, so there is no un-themed flash.
    final chrome = theme == null
        ? ChromeData.bootstrap
        : ChromeData.fromPalette(
            theme.palette,
            typography: theme.typography,
            textScale: theme.textScale,
            family: theme.chromeFamily,
            opacity: theme.surfaceOpacity,
          );

    final skin = theme == null
        ? SetupSkin.defaultForShell(ShellKind.gnome)
        : SetupSkin.defaultForShell(theme.shell);

    // The pack sweep, watched for its STATE (the footer reads it) and started
    // as a side effect below.
    final packs = ref.watch(distroPacksProvider);

    // ── POST-FRAME, BECAUSE STARTING WORK INSIDE build IS NOT ALLOWED ────
    //
    // `ensure` writes to a notifier, and a provider write during a build throws
    // in Riverpod. The guard inside [_ensurePacksFor] makes the repeat calls
    // free, so this costs one comparison per rebuild and needs no lifecycle of
    // its own.
    //
    // Here rather than in `initState` because it needs the RESOLVED theme, and
    // on a cold start that has not landed by the time initState runs.
    if (theme != null) {
      final id = theme.spec.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensurePacksFor(id);
      });
      // Synchronous and idempotent, so it belongs in build rather than behind a
      // post-frame callback: it writes no provider, only a field this widget
      // owns, and the widgets step several screens later needs it settled.
      _seedWidgetChoice(theme);
    }

    return ChromeScope(
      data: chrome,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // ─── THE INSTALLER RUNS OVER THE LIVE SESSION'S WALLPAPER ────────
        //
        // It used to be a flat two-stop gradient of the palette, and that is
        // the single biggest reason the wizard read as a phone form rather than
        // a desktop. You do not install Ubuntu on a purple rectangle; you
        // install it from a live session, with the distro's own wallpaper
        // behind the window and the installer floating on top. The frame was
        // ALREADY drawing a floating window over this; there was just nothing
        // underneath worth floating over.
        //
        // The gradient stays as the layer beneath, so a theme with no
        // wallpaper, or one whose image has not decoded yet, looks exactly as
        // it does today rather than flashing black.
        //
        // `spec.asset` is what knows whether this distro's files are in the APK
        // or in `packs/<id>/`, and it is the only thing that does. Handing the
        // raw string to an AssetImage works for a bundled theme and silently
        // renders nothing for a downloaded one, which is the same trap
        // `wallpaper_source.dart` documents at length.
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: theme == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.palette.bgTop, theme.palette.bgBottom],
                  ),
            image: _wallpaperFor(theme),
          ),
          child: SafeArea(
            child: theme == null
                ? const SizedBox.shrink()
                : Builder(
                    builder: (_) {
                      final steps = _stepsFor(theme.shell);
                      // The list can shrink under the user (terminal drops four
                      // steps), so never trust a stale enum: fall back to the
                      // first step rather than rendering nothing.
                      final i =
                          !steps.contains(_step) ? 0 : steps.indexOf(_step);
                      final current = steps[i];

                      return SetupInstallerFrame(
                        skin: skin,
                        steps: [
                          for (final st in steps) ref.t('setup.step.${st.name}')
                        ],
                        step: i,
                        windowTitle: _windowTitle(theme, skin),
                        title: _title(current),
                        subtitle: _subtitle(current),
                        // ── NULL WHEN THERE IS NOTHING TO SAY ──────────
                        //
                        // The frame gives this slot to the status line when it
                        // is non-null and to the progress dots otherwise, so a
                        // step counter passed unconditionally here would delete
                        // the dots from every wizard on every skin that has
                        // them. It used to fall back to `setup.status` for
                        // exactly that reason and the ordering in the frame
                        // made it dead code instead.
                        //
                        // The count is not lost: the console skin prints it in
                        // its title bar, and the dot row IS the count on the
                        // skins that draw one. What the slot is borrowed for is
                        // the one thing neither of those can say, which is what
                        // the machine is currently doing.
                        status: _packLine(packs, theme),
                        nextEnabled: _mayAdvance(current, packs, theme),
                        footerNote:
                            !_isDefault && i > steps.indexOf(_SetupStep.welcome)
                                ? _NagLine(onFix: _openHomePicker)
                                : null,
                        onBack: i == 0 || current == _SetupStep.install
                            ? null
                            : _back,
                        onNext: _next,
                        nextLabel: switch (current) {
                          _SetupStep.welcome => ref.t('setup.next.getStarted'),
                          // The step before install, whichever it is: on the
                          // terminal that is the distro step, not folders.
                          final st when st == steps[steps.length - 2] =>
                            ref.t('setup.next.install'),
                          _ => ref.t('setup.next.continue'),
                        },
                        body: _body(theme, skin, current),
                        stage: _stage(theme, skin, current),
                        // The welcome step is the one built around a LIST, so
                        // it is the one that should grow into the window. The
                        // rest are a handful of rows and look wrong stretched.
                        fills: current == _SetupStep.welcome,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// What the pack sweep is doing, or null when it is not worth saying.
  ///
  /// ─── ONLY FOR THE DISTRO THIS SCREEN IS SHOWING ───────────────────────
  ///
  /// A swipe supersedes the pass in flight, so for a frame or two the state
  /// still describes the distro the user just left. Reporting that would put
  /// another distro's name in the footer of the one on screen, which is worse
  /// than silence.
  ///
  /// LITERALS, not `ref.t`. The i18n migration has not run over the strings
  /// added in this pass, and `ref.t` against a key that does not exist renders
  /// the key itself, which is worse on screen than English is. Same call the
  /// widgets step already makes.
  String? _packLine(DistroPackState packs, EffectiveTheme? theme) {
    if (theme == null || packs.themeId != theme.spec.id) return null;
    return switch (packs.phase) {
      DistroPackPhase.refreshing => 'Fetching package lists',
      DistroPackPhase.installing when packs.total > 1 =>
        'Installing ${packs.label}, ${packs.done + 1} of ${packs.total}',
      DistroPackPhase.installing => 'Installing ${packs.label}',
      _ => null,
    };
  }

  /// May Continue be pressed?
  ///
  /// ─── IT BLOCKS IN ONE PLACE, ON ONE THING, BRIEFLY ────────────────────
  ///
  /// Only the distro step, only while THIS distro's own theme pack is still
  /// transferring. Everything else is allowed through: an icon pack landing
  /// four seconds late means four seconds of generated icons, and holding a
  /// wizard for that would make a slow connection look like a hang on the one
  /// screen where nobody can tell what is being waited for.
  ///
  /// It also fails OPEN. An unstarted sweep, a superseded one, a theme that has
  /// not resolved, a crash inside `ensure`: all of them advance. The app has a
  /// guaranteed floor either way, because `activeThemeSpecProvider` resolves
  /// bundled when nothing is installed, so the worst case of advancing early is
  /// the APK's copy of a distro rather than the CDN's. The worst case of
  /// failing closed is a wizard nobody can leave.
  bool _mayAdvance(
    _SetupStep step,
    DistroPackState packs,
    EffectiveTheme? theme,
  ) {
    if (step != _SetupStep.distro) return true;
    if (theme == null || packs.themeId != theme.spec.id) return true;
    if (packs.phase != DistroPackPhase.installing) return true;
    return packs.themeReady;
  }

  /// The live desktop above the step, or null where one would be dishonest.
  ///
  /// ─── THREE STEPS GET NO STAGE, AND EACH FOR ITS OWN REASON ──────────────
  ///
  /// [_SetupStep.welcome] asks for a language and the home role. Both are facts
  /// about ANDROID rather than about the desktop, and at that point no distro
  /// has been chosen, so the stage would have to invent one to draw. A preview
  /// of a decision the user has not made yet is decoration.
  ///
  /// THE CONSOLE SKIN, because a TTY installer that drew a picture of a desktop
  /// would give the whole thing away. The frame refuses it there too, so this
  /// is belt and braces on the one rule the mono branch exists to keep.
  ///
  /// [_SetupStep.install] draws its own full-screen version, which is the
  /// payoff the rest of the wizard is building toward. A 260dp stage above it
  /// would be the same picture, smaller, twice.
  ///
  /// ─── THE MODE FOLLOWS THE QUESTION ──────────────────────────────────────
  ///
  /// Asking about drawer columns while showing a desktop means the answer
  /// changes something off screen, which is the failure the per-step previews
  /// were built to avoid and which a single fixed stage would reintroduce. So
  /// the stage switches what it is a picture OF, while remaining the same
  /// desktop: the drawer step shows the drawer, the folders step shows a
  /// folder, everything else shows the desktop. [DeviceStage] cross-fades
  /// between them for free, because `mode` is part of its signature.
  Widget? _stage(EffectiveTheme? theme, SetupSkin skin, _SetupStep step) {
    if (theme == null) return null;
    if (skin.kind == SetupFrameKind.console) return null;
    if (step == _SetupStep.welcome || step == _SetupStep.install) return null;

    // ── AND THE ICONS STEP, WHICH IS THE ONE THE STAGE CANNOT ANSWER ─────
    //
    // Every other step asks a question the stage can show: move the dock, watch
    // the dock move. This one asks which icon set you want, and only ONE icon
    // style can be live at a time (`setIconTheme` pushes one to native and
    // `IconCache` keys every bitmap by it). The distro's pack is also not on
    // the device yet, which is the thing being agreed to.
    //
    // So the stage could only ever draw the App icons answer, permanently,
    // including while Ubuntu icons was selected. The biggest element on screen
    // showing the option the user did not pick is worse than no picture, and on
    // a 260dp stage it read as a broken grid: eight oversized icons, no labels,
    // cropped mid-row.
    //
    // The comparison moved into the step itself, where both answers can sit
    // side by side at a size where the difference is visible. See [_StepIcons].
    if (step == _SetupStep.icons) return null;

    // ── THE DISTRO STEP OWNS THE STAGE RATHER THAN WATCHING IT ─────────────
    //
    // Every other step ASKS A QUESTION and the stage answers it: pick a dock
    // side, watch the dock move. The distro step is the one where the stage IS
    // the question, so it becomes a deck the user swipes rather than a picture
    // that follows a list of rows underneath.
    //
    // That also removes the duplication the old screen had. A card list of
    // three distros under a stage showing the selected one drew the same
    // desktop twice, once at 62dp inside a row and once at 260dp above it.
    if (step == _SetupStep.distro) {
      return _DistroDeck(
        active: theme.spec.id,
        onSelected: _ensurePacksFor,
      );
    }

    final mode = switch (step) {
      _SetupStep.drawer => DevicePreviewMode.drawer,
      _SetupStep.folders => DevicePreviewMode.folder,
      _ => DevicePreviewMode.desktop,
    };

    return DeviceStage(
      // The palette's identity, and the switcher's key. See DeviceStage: a
      // stale id here is a stage that stops repainting when the distro changes,
      // which is the one failure that looks like the setting being broken.
      themeId: theme.spec.id,
      palette: theme.palette,
      mode: mode,
      // Straight off EffectiveTheme, which is where the RESOLVED answers live:
      // distro default, then the user's override, already merged. Reading
      // `theme.spec` here instead would draw the distro's opinion rather than
      // the choice the previous step just made, so the stage would ignore the
      // very answers it exists to show.
      dock: theme.dock,
      // The drawer is denser than home by convention and carries its own
      // count, so a stage previewing the DRAWER must use it or the columns
      // step would move a number the picture does not respond to.
      cols: mode == DevicePreviewMode.drawer ? theme.drawerCols : theme.cols,
      // ── THE TWO VALUES THE PER-STEP PREVIEW CARRIED ────────────────────
      //
      // The stage replaces `_Preview`, so it has to answer everything that
      // widget answered. It did not, at first: `gridButton` and `rows` were
      // left at DevicePreview's defaults, which would have made the dock
      // step's app-grid rows and the folder step's row count move a picture
      // that never responded. That is the exact failure DeviceStage's own
      // signature note warns about, one layer up.
      //
      // Both come from `prefs` rather than from the resolved theme because
      // neither is promoted onto EffectiveTheme: `dockGridButton` and
      // `folderRows` live on LauncherPrefs and are read here the same way
      // `_Preview` read them.
      gridButton: theme.prefs.dockGridButton ?? 'end',
      rows: theme.prefs.folderRows ?? 3,
      framed: false,
      background: _stageWallpaper(theme),
      tiles: _stageTiles(mode),
      // Only the widgets step draws these. Everywhere else the desktop canvas
      // stays empty, which is what it looks like before anything is placed.
      overlay: step == _SetupStep.widgets ? _widgetGhosts(theme) : null,
    );
  }

  /// Blocks where the chosen desklets will land, over the desktop stage.
  ///
  /// ─── GHOSTS, NOT THE REAL DESKLETS ──────────────────────────────────────
  ///
  /// Rendering the actual widgets here would mean running the stats poller and
  /// the conky skin inside a 240dp preview during setup, and every one of them
  /// is a ConsumerWidget with its own stream. The question this step asks is
  /// WHERE and HOW MANY, not what the numbers say, and a labelled block answers
  /// both. The real thing appears one screen later, on the desktop itself,
  /// which is the payoff the install step exists for.
  ///
  /// Proportions come from `defaultSpanY` against the theme's row count, so a
  /// block is the height the desklet will actually occupy rather than a
  /// decorative bar.
  Widget? _widgetGhosts(EffectiveTheme theme) {
    final picked = _chosenWidgets(theme);
    final kinds = [
      for (final k in offeredDesklets(theme))
        if (picked.contains(k.id)) k,
    ];
    if (kinds.isEmpty) return null;

    // The DESKLET grid, matching the packing in `_next` and the starter in
    // `_seedFirstDesktop`. This read `theme.rows`, the icon grid, so a block
    // drawn here was a third of the height of the tile it stood for and the
    // Top / Middle / Bottom strip moved it by the wrong amount.
    final rows = theme.deskletRows < 1 ? 1 : theme.deskletRows;
    final tall = kinds.fold<int>(0, (n, k) => n + k.defaultSpanY);
    // The PALETTE's own colours, not a constructed ChromeData. Building one
    // here would mean matching the four named arguments the screen's own
    // bootstrap passes, and `DevicePreview` already draws from exactly these
    // two for the same reason: the ghosts sit inside the picture, so they
    // should take the picture's colours rather than the chrome's.
    final accent = theme.palette.accent;
    final ink = theme.palette.onDark;

    final stack = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in kinds)
          Expanded(
            flex: k.defaultSpanY,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  border: Border.all(color: accent, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  k.id == 'monitor' ? 'conky' : k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: ink),
                ),
              ),
            ),
          ),
      ],
    );

    // The remaining rows, split above and below according to the chosen spot.
    final spare = rows - tall;
    final above = switch (_widgetSpot) {
      'bottom' => spare,
      'middle' => spare ~/ 2,
      _ => 0,
    };

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (above > 0) Expanded(flex: above, child: const SizedBox()),
          Expanded(flex: tall, child: stack),
          if (spare - above > 0)
            Expanded(flex: spare - above, child: const SizedBox()),
        ],
      ),
    );
  }

  /// The user's OWN apps, for the drawer stage.
  ///
  /// ─── ONLY THE DRAWER, AND ONLY BECAUSE THAT IS THE HONEST ONE ───────────
  ///
  /// The drawer stage is a picture of a grid of every installed app, so filling
  /// it with the first N installed apps is the same thing at a smaller size.
  /// The DESKTOP stage is not: its grid is the home layout, which does not
  /// exist yet during setup, so putting real apps there would show a home
  /// screen arrangement the user is never going to get. The folder stage is
  /// the same objection, one level in.
  ///
  /// So the picture is real exactly where being real is true, and stays
  /// abstract everywhere it would be a guess dressed up as a promise.
  ///
  /// ─── NO SORT, AND NO USAGE DATA ─────────────────────────────────────────
  ///
  /// The drawer's own order is the resolved one and it is not available here.
  /// Taking `appListProvider` in its natural order gives the same apps the
  /// drawer will show, in an order that is merely not yet the final one, which
  /// is a smaller lie than ranking them by a usage history that on a fresh
  /// install does not exist.
  ///
  /// An empty or still-loading list falls through to the placeholders, so a
  /// slow query during setup degrades to what this screen drew yesterday
  /// rather than to a blank grid.
  List<Widget> _stageTiles(DevicePreviewMode mode) {
    if (mode != DevicePreviewMode.drawer) return const <Widget>[];
    final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
    if (apps.isEmpty) return const <Widget>[];

    // Enough for the widest grid the columns step offers (6) at the rows the
    // stage can show. Asking for more would render icons that are clipped away
    // and pay the native icon pipeline for every one of them.
    const budget = 6 * 5;
    return [
      for (final app in apps.take(budget))
        // Sized by the grid cell rather than by a number here: a fixed size
        // inside a GridView tile is how the same widget ends up correct at
        // 260dp and overflowing at 120dp, which is the bug the folder sheet
        // above already paid for once.
        LayoutBuilder(
          builder: (context, c) {
            final cell = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
            return Center(
              // NOT the full cell. The real drawer puts a label under every
              // icon, so an icon that fills its cell edge to edge is DENSER
              // than the thing being previewed, and at stage size that reads
              // as a wall of artwork rather than as an app grid. Holding back
              // roughly the share a label line occupies makes the preview's
              // rhythm match the drawer it is a picture of.
              child: AppIcon(entry: app, size: cell * 0.78),
            );
          },
        ),
    ];
  }

  /// The distro's wallpaper as a plain provider, or null.
  ///
  /// The sibling of [_wallpaperFor] and deliberately NOT the same thing. That
  /// one returns a [DecorationImage] dimmed hard, because it is a BACKDROP
  /// behind a translucent installer window and an undimmed photo there makes
  /// the text unreadable. This is the desktop ITSELF, seen through the stage,
  /// so dimming it would be previewing a wallpaper the user will never get.
  ///
  /// The guard is the same and has to be: `isThemeAssetRef` is what keeps a
  /// path that is not a theme reference out of `spec.asset`, and duplicating
  /// the resolution rule rather than the guard is how the app previously ended
  /// up with four copies of the wallpaper decision.
  ImageProvider? _stageWallpaper(EffectiveTheme theme) {
    final source =
        theme.spec.wallpapers.isNotEmpty ? theme.spec.wallpapers.first : null;
    if (source == null || !isThemeAssetRef(source)) return null;
    return theme.spec.asset(source).image;
  }

  /// The distro's own wallpaper, dimmed, as the installer's backdrop.
  ///
  /// Null whenever there is nothing safe to show: no theme yet, no wallpaper
  /// authored, or a source that is not a theme reference (a user photo cannot
  /// exist during setup, but the predicate is the one place that rule lives and
  /// reusing it beats reimplementing it here).
  ///
  /// Dimmed hard, because this is a BACKDROP. An undimmed photo behind a
  /// translucent window makes the installer text unreadable, and the real live
  /// session dims the desktop behind its installer for exactly that reason.
  DecorationImage? _wallpaperFor(EffectiveTheme? theme) {
    if (theme == null) return null;

    final source =
        theme.spec.wallpapers.isNotEmpty ? theme.spec.wallpapers.first : null;
    if (source == null || !isThemeAssetRef(source)) return null;

    return DecorationImage(
      image: theme.spec.asset(source).image,
      fit: BoxFit.cover,
      // The SPEC's palette, not the resolved one, for the same reason the
      // splash uses it: this is a scrim over a photograph, and dimming a
      // photograph with a near-white wash does not dim it, it bleaches it.
      // Light mode made `theme.palette.bgBottom` pale, so the installer's
      // backdrop went from a dark aubergine veil to a white haze.
      //
      // A live session dims the desktop behind its installer whichever theme
      // the session is running.
      colorFilter: ColorFilter.mode(
        theme.spec.palette.bgBottom.withValues(alpha: 0.72),
        BlendMode.srcOver,
      ),
    );
  }

  /// "Install Ubuntu". Reads the distro's own name, so a CDN pack titles its
  /// own installer with no code change.
  String _windowTitle(EffectiveTheme theme, SetupSkin skin) {
    if (skin.kind == SetupFrameKind.console) {
      return ref
          .t('setup.window.console', {'name': theme.spec.name.toLowerCase()});
    }
    // The reference titles its first page "Welcome to Ubuntu" and only later
    // pages "Install ...", so the window title tracks the step.
    return _step == _SetupStep.welcome
        ? ref.t('setup.window.welcome', {'name': theme.spec.name})
        : ref.t('setup.window.install', {'name': theme.spec.name});
  }

  String _title(_SetupStep step) => switch (step) {
        _SetupStep.welcome => ref.t('setup.welcome.chooseLanguage'),
        _SetupStep.distro => ref.t('setup.title.distro'),
        // LITERAL, not a key, matching the widgets step below: the i18n
        // migration has not run over this step, and `ref.t` against a missing
        // key renders the key itself, which is worse on screen than English is.
        _SetupStep.icons => 'Icons',
        _SetupStep.appearance => ref.t('setup.title.appearance'),
        _SetupStep.dock => ref.t('setup.title.dock'),
        _SetupStep.drawer => ref.t('setup.title.drawer'),
        _SetupStep.folders => ref.t('setup.title.folders'),
        // LITERAL, not a key. The i18n migration has not run over this step
        // yet, and a `ref.t` against a key that does not exist renders the key
        // itself, which is worse on screen than English is.
        _SetupStep.widgets => 'Desktop widgets',
        _SetupStep.notifications => ref.t('setup.title.notifications'),
        _SetupStep.install => ref.t('setup.title.install'),
      };

  String? _subtitle(_SetupStep step) => switch (step) {
        // The reference has no line under "Choose your language:".
        _SetupStep.welcome => null,
        _SetupStep.distro => ref.t('setup.subtitle.distro'),
        _SetupStep.icons => 'How your apps should look.',
        _SetupStep.appearance => ref.t('setup.subtitle.appearance'),
        _SetupStep.dock => ref.t('setup.subtitle.dock'),
        _SetupStep.drawer => ref.t('setup.subtitle.drawer'),
        _SetupStep.folders => ref.t('setup.subtitle.folders'),
        _SetupStep.widgets => 'Conky and fastfetch, on your home screen.',
        _SetupStep.notifications => ref.t('setup.subtitle.notifications'),
        _SetupStep.install => ref.t('setup.subtitle.install'),
      };

  Widget _body(EffectiveTheme theme, SetupSkin skin, _SetupStep step) =>
      switch (step) {
        _SetupStep.welcome => _StepWelcome(
            mono: skin.mono,
            isDefault: _isDefault,
            showWarning: _showHomeWarning,
            onRequest: _openHomePicker,
          ),
        _SetupStep.distro => _StepDistro(mono: skin.mono),
        _SetupStep.icons => _StepIcons(
            theme: theme,
            mono: skin.mono,
            distroIcons: _distroIcons,
            onChanged: (v) => setState(() => _distroIcons = v),
          ),
        _SetupStep.appearance => _StepAppearance(theme: theme, mono: skin.mono),
        _SetupStep.dock => _StepDock(theme: theme, mono: skin.mono),
        _SetupStep.drawer => _StepDrawer(theme: theme, mono: skin.mono),
        _SetupStep.folders => _StepFolders(
            theme: theme,
            mono: skin.mono,
            skipped: _skippedFolders,
            onToggle: (name) => setState(() {
              if (!_skippedFolders.remove(name)) _skippedFolders.add(name);
            }),
          ),
        _SetupStep.widgets => _StepWidgets(
            theme: theme,
            mono: skin.mono,
            chosen: _chosenWidgets(theme),
            spot: _widgetSpot,
            onToggle: (id) => setState(() {
              final set = _widgets ??= <String>{};
              if (!set.remove(id)) set.add(id);
            }),
            onSpot: (v) => setState(() => _widgetSpot = v),
          ),
        _SetupStep.notifications => _StepNotifications(
            theme: theme,
            mono: skin.mono,
            want: _wantBadges,
            onWantChanged: (v) => setState(() => _wantBadges = v),
          ),
        _SetupStep.install =>
          _StepInstall(theme: theme, skin: skin, onDone: _finish),
      };
}

/// Every step this wizard can show. Which of them it DOES show is
/// [_stepsFor].
enum _SetupStep {
  welcome('Welcome'),
  distro('Desktop'),
  icons('Icons'),
  appearance('Appearance'),
  dock('Dock'),
  drawer('App drawer'),
  folders('Folders'),
  widgets('Widgets'),
  notifications('Badges'),
  install('Install');

  const _SetupStep(this.label);

  /// The rail label. On the enum so the rail and the switch cannot drift.
  final String label;
}

/// The steps that make sense for a shell.
///
/// ─── THE TERMINAL HAS NO GUI, SO IT HAS NO GUI QUESTIONS ────────────────────
///
/// The TUI shell has no dock, no app-grid button, no drawer columns, no scroll
/// style and no folder grid. Asking about any of them would be asking the user
/// to configure things that will never appear, and then showing a rail that
/// counts them. So the terminal installs in four steps and the wizard is
/// honest about its own length.
///
/// Keyed by SHELL, like every other default in the theme layer. A future
/// GUI-less distro inherits this without authoring anything, and a new
/// graphical one inherits the full list.
///
/// [_SetupStep.welcome] and [_SetupStep.install] are in every list: the first
/// is language plus the home role (both about Android rather than the desktop),
/// and the third is the hand-off to the boot sequence.
List<_SetupStep> _stepsFor(ShellKind? shell) {
  if (shell == ShellKind.tui) {
    return const [
      _SetupStep.welcome,
      _SetupStep.distro,
      _SetupStep.install,
    ];
  }
  return const [
    _SetupStep.welcome,
    _SetupStep.distro,
    // ── STRAIGHT AFTER THE DISTRO, BECAUSE IT IS THE DISTRO'S QUESTION ──
    //
    // Which icons you get is a fact about the distro you just chose: the pack
    // is named by its theme.json and derived from its id. Asking here means the
    // answer sits beside the choice that produced it, and it means the ten
    // megabytes are agreed to before the wizard spends five more screens
    // implying they are already on their way.
    //
    // NOT in the terminal list below. The TUI shell has no app grid, so there
    // is no surface for an icon pack to appear on and offering one would be
    // offering a place that does not exist. Its line pack is still fetched if
    // the user ever switches to a graphical distro.
    _SetupStep.icons,
    // BEFORE the layout steps, deliberately. Dock and drawer both preview
    // themselves, and a preview painted in the mode you are about to leave is
    // worse than no preview. After distro because the preview needs a palette.
    _SetupStep.appearance,
    _SetupStep.dock,
    _SetupStep.drawer,
    _SetupStep.folders,
    // ── WIDGETS SIT BESIDE FOLDERS, AND BEFORE NOTIFICATIONS ──────────
    //
    // Folders and desklets are the same question asked twice: what is on your
    // screens. Adjacent, so someone answering one is already in that frame of
    // mind.
    //
    // It cannot come earlier, because a desklet is SKINNED BY THE DISTRO and
    // the picker would be showing an Ubuntu conky to someone about to choose
    // Terminal. And it cannot come later, because notifications has to stay
    // last: see the note below, which is the one rule this list has.
    //
    // NOT in the terminal list, and not an oversight: the TUI shell has no
    // desktop to put a desklet on, so offering one would be offering a place
    // that does not exist.
    _SetupStep.widgets,
    // ─── AFTER THE ICONS EXIST, BEFORE THE INSTALL ────────────────────
    //
    // Late on purpose. This is the only step that asks for a PERMISSION, and
    // Android is about to show a full page warning that the launcher can read
    // every notification on the phone. Someone who has just watched their dock
    // and drawer take shape has a picture of what a badge would sit on and can
    // weigh that warning; someone three screens into a wizard has nothing to
    // weigh it against and will refuse by default.
    //
    // NOT in the terminal list above, and that is not an oversight: the tui and
    // tiling shells resolve to BadgeStyle.none, so asking for notification
    // access there would be asking for a sensitive permission the shell can
    // never use. The same honesty that gives the terminal four steps.
    _SetupStep.notifications,
    _SetupStep.install,
  ];
}

// ── Steps ────────────────────────────────────────────────────────────────────

/// Welcome: the whole opening screen, matching the modern Ubuntu installer's
/// first page — the distro mark, then "Choose your language:" over a bordered
/// SCROLLABLE list of native language names, active one in the accent colour.
///
/// The list scrolls inside a fixed-height box (like the reference) rather than
/// growing the page, because the language count is data: `kBundledLocales` can
/// grow to dozens of Google-Translate-backed languages without this screen
/// changing shape. Selection applies LIVE, so the wizard re-titles itself in
/// the chosen language under the finger.
///
/// Below the box sits the one thing a launcher must settle before anything
/// else works: the home role. The three-strike gate still lives on the state
/// and fires from the footer's action; this widget only renders the control.
class _StepWelcome extends ConsumerWidget {
  const _StepWelcome({
    required this.mono,
    required this.isDefault,
    required this.showWarning,
    required this.onRequest,
  });

  final bool mono;
  final bool isDefault;
  final bool showWarning;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    // hasValue, not asData: asData is null through a RELOAD, and every prefs
    // write is a reload. See home_screen.dart.
    final themeAsync = ref.watch(effectiveThemeProvider);
    final theme = themeAsync.hasValue ? themeAsync.requireValue : null;
    final i18n = ref.watch(i18nProvider);
    // Preselect what is on screen: the explicit choice, else the device
    // language the app booted with.
    final activeCode = i18n.selectedCode ?? i18n.translations.code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The distro's REAL mark, centred like the reference's Ubuntu wordmark.
        //
        // This used to be a typeset stand-in: an accent-coloured square beside
        // the distro's name, with a comment saying the SVG was not wired
        // because app_icon.dart was not in hand. It looked exactly like what it
        // was, a placeholder, and it was the first thing on the first screen.
        //
        // LauncherBrandIcon reads `spec.logo` and picks the variant that reads
        // on this surface, so a CDN distro shipping its own logo gets it here
        // with no code change, and a distro shipping none falls back to the
        // Mindhunter mark rather than to a coloured rectangle.
        if (theme != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LauncherBrandIcon(theme: theme, size: 34),
                  const SizedBox(width: 10),
                  Text(
                    theme.spec.name,
                    style: d.text.display.copyWith(fontSize: 30),
                  ),
                ],
              ),
            ),
          ),

        // The language box: bordered, rounded, SCROLLABLE, and it now GROWS.
        //
        // It was a fixed 288, which is what left a third of the window empty
        // beneath the home-role button. The frame gives this step the full
        // height (SetupInstallerFrame.fills), so the box takes whatever the
        // header and the rows below do not, on every screen size, instead of
        // being right on one phone and wrong on the rest.
        //
        // Plain text rows: the reference has no radios and no cards, just
        // names, with the active one in the accent colour.
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: d.colors.line),
              borderRadius: BorderRadius.circular(9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  for (final l in localesForDisplay())
                    _LanguageLine(
                      label: l.nativeName,
                      active: l.code == activeCode,
                      mono: mono,
                      onTap: () => ref.read(i18nProvider.notifier).select(l),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (isDefault)
          SetupRow(
            title: ref.t('setup.welcome.homeSet'),
            subtitle: ref.t('setup.welcome.homeSetSub'),
            selected: true,
            marker: SetupMarker.check,
            mono: mono,
            onTap: () {},
          )
        else ...[
          if (showWarning) ...[
            Text(
              ref.t('setup.welcome.homeWarn'),
              softWrap: true,
              style: d.text.caption.copyWith(color: d.colors.warn),
            ),
            const SizedBox(height: 12),
          ],
          ThemedButton(
            label: showWarning
                ? ref.t('setup.welcome.setHome')
                : ref.t('setup.welcome.chooseHome'),
            icon: Icons.home_outlined,
            expand: true,
            onPressed: onRequest,
          ),
          const SizedBox(height: 8),
          Text(
            ref.t('setup.welcome.homeHelper'),
            softWrap: true,
            style: d.text.caption.copyWith(color: d.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// One language name in the welcome box. Text-only, the reference's idiom:
/// active = accent + a shade heavier, everything else = plain text colour.
/// The console skin keeps its cursor: a `>` at the active line.
class _LanguageLine extends StatelessWidget {
  const _LanguageLine({
    required this.label,
    required this.active,
    required this.mono,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final base = mono ? d.text.label : d.text.body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Text(
          mono ? '${active ? '> ' : '  '}$label' : label,
          style: base.copyWith(
            color: active ? d.colors.accent : d.colors.text,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// The distro step. Rows, real specs, Ubuntu preselected.
///
/// Selecting applies the theme LIVE, which re-skins this screen underneath the
/// finger: pick the terminal and the wizard becomes a console before the row
/// has finished highlighting. That is the demo, and it is why this step is
/// third rather than last.
/// The distro chooser, as a deck of full-width desktops.
///
/// ─── SWIPE, NOT A LIST OF ROWS ──────────────────────────────────────────────
///
/// The old step was three rows carrying a 62dp thumbnail each, under a stage
/// that already showed the selected distro at 260dp. So the same desktop was
/// drawn twice on one screen, the big copy was the one nobody was choosing
/// from, and the small copies were too small to show what a desktop is: at 62dp
/// a dock and a grid are four grey pips.
///
/// One picture, at the size that makes the difference legible, and the gesture
/// that changes it is the same one the drawer uses.
///
/// ─── THE PAGE IS THE SELECTION, AND IT COMMITS ON SETTLE ────────────────────
///
/// `onPageChanged` fires once the page has settled, not during the drag, so a
/// swipe that is released half way and springs back does not write anything.
/// Writing during the drag would mean the theme resolving, the whole chrome
/// rebuilding and the palette changing under a finger that has not chosen yet.
///
/// ─── AND WHY IT DOES NOT WATCH THE SELECTION ────────────────────────────────
///
/// [active] seeds the initial page and nothing more. Watching it would make the
/// deck jump to whatever the controller just wrote, which is where it already
/// is, and on a slow write it would fight the user's own drag. The page is the
/// source of truth while this widget is alive; the selection is the record of
/// it.
class _DistroDeck extends ConsumerStatefulWidget {
  const _DistroDeck({required this.active, required this.onSelected});

  /// The currently selected distro id, used ONCE to pick the opening page.
  final String active;

  /// Fired when a page settles, alongside the selection write.
  ///
  /// The deck is where a distro is CHOSEN, so it is the only place that knows
  /// the moment a different distro's packs became the ones worth having. The
  /// screen holds the idempotence guard; this just reports.
  final ValueChanged<String> onSelected;

  @override
  ConsumerState<_DistroDeck> createState() => _DistroDeckState();
}

class _DistroDeckState extends ConsumerState<_DistroDeck> {
  PageController? _controller;
  int _page = 0;

  @override
  void dispose() {
    // Captured, never read through `ref`: reading a provider in dispose throws
    // in Riverpod, and a controller is not a provider anyway.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specs = ref.watch(setupDistrosProvider).asData?.value ?? const [];
    if (specs.isEmpty) return const SizedBox.expand();

    // Built on the first frame that HAS specs, not in initState, because the
    // opening page depends on a list that is loaded asynchronously. An
    // initState controller would always open on page zero and then have
    // nothing to correct it with that would not also animate in front of the
    // user.
    if (_controller == null) {
      final start = specs.indexWhere((sp) => sp.id == widget.active);
      _page = start < 0 ? 0 : start;
      _controller = PageController(initialPage: _page);
    }

    return PageView.builder(
      controller: _controller,
      itemCount: specs.length,
      onPageChanged: (i) {
        setState(() => _page = i);
        final spec = specs[i];
        Analytics.themeSelected(spec.id);
        ref.read(selectedThemeIdProvider.notifier).select(spec.id);
        // AFTER the select, so `activeThemeSpecProvider` is already resolving
        // toward this distro when the sweep asks it what icon packs to fetch.
        widget.onSelected(spec.id);
      },
      itemBuilder: (context, i) {
        final spec = specs[i];
        return DevicePreview(
          palette: spec.palette,
          mode: DevicePreviewMode.desktop,
          dock: spec.layout.dock,
          cols: spec.layout.cols,
          rows: spec.layout.rows,
          framed: false,
          // The SPEC's own wallpaper, so each page is that distro rather than
          // the selected one wearing a different palette. Guarded the same way
          // the backdrop is: see _stageWallpaper.
          background: spec.wallpapers.isNotEmpty &&
                  isThemeAssetRef(spec.wallpapers.first)
              ? spec.asset(spec.wallpapers.first).image
              : null,
        );
      },
    );
  }
}

class _StepDistro extends ConsumerWidget {
  const _StepDistro({required this.mono});

  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = ref.watch(setupDistrosProvider).asData?.value ?? const [];
    final active =
        ref.watch(selectedThemeIdProvider).asData?.value ?? fallbackThemeId;

    // The console skin keeps the text list: a TTY installer does not draw
    // pictures of desktops, and a preview thumbnail there would be the one
    // detail that gives the whole thing away.
    if (mono) {
      return Column(
        children: [
          for (final spec in specs)
            SetupRow(
              title: spec.name,
              subtitle: ref.t(_taglineKeyFor(spec.shell)),
              trailing: spec.version.isEmpty ? null : spec.version,
              selected: spec.id == active,
              mono: true,
              marker: SetupMarker.chevron,
              onTap: () {
                Analytics.themeSelected(spec.id);
                ref.read(selectedThemeIdProvider.notifier).select(spec.id);
              },
            ),
        ],
      );
    }

    // ── THE CAPTION FOR THE DECK ABOVE ─────────────────────────────────────
    //
    // The cards are gone. They drew the same three desktops the deck now draws
    // full width, at 62dp, where a dock and a grid are four grey pips, and they
    // drew them a second time under a stage already showing the selected one.
    //
    // What is left is the part a picture cannot say: the name, the release, the
    // one line about the shell, and which icon pack comes with it. Everything
    // here follows the SELECTION, which the deck writes when a page settles, so
    // the caption and the picture can never disagree.
    // ── EMPTY IS A REAL STATE, AND IT IS THE FIRST FRAME ───────────────────
    //
    // `setupDistrosProvider` reads three theme.json files off the bundle, so
    // the first build of this step ALWAYS has an empty list. The mono branch
    // above happens to survive it, because a `for` over nothing draws nothing;
    // this branch did not, and `specs.first` threw "Bad state: No element" on
    // the frame before the assets landed.
    //
    // Nothing rather than a spinner, matching the deck above and `_Root`: a
    // wizard that flashes a progress indicator between its own steps reads as
    // broken, and this resolves within a frame or two.
    if (specs.isEmpty) return const SizedBox.shrink();

    // A plain loop rather than `firstOrNull`, which is a package:collection
    // extension this file does not import and would not be worth importing for
    // one lookup over a list of three.
    var spec = specs.first;
    for (final sp in specs) {
      if (sp.id == active) {
        spec = sp;
        break;
      }
    }
    final d = ChromeScope.of(context);
    final c = d.colors;
    final heroPack = spec.icons.heroPack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(spec.name, style: d.text.display),
            const SizedBox(width: 8),
            if (spec.version.isNotEmpty)
              Text(
                spec.version,
                style: d.text.caption.copyWith(color: c.textFaint),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.t(_taglineKeyFor(spec.shell)),
          style: d.text.body.copyWith(color: c.textMuted),
        ),
        if (heroPack != null && heroPack.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // Palette swatches rather than the pack's own art, and the copy
              // says ARRIVES rather than implying it is already here. The pack
              // is downloaded after setup, so at this moment the device does
              // not have it and a strip of its real icons would be a claim
              // this screen cannot back. Three colours from the distro's own
              // palette stand in without promising anything.
              for (final swatch in [c.accent, c.text, c.line])
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Arrives with $heroPack icons',
                  style: d.text.caption.copyWith(color: c.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        // Which of the three you are on, and how many there are. Without this
        // a deck is a screen with one desktop on it and no reason to swipe.
        Row(
          children: [
            for (final sp in specs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: sp.id == active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: sp.id == active ? c.accent : c.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              'Swipe the desktop above',
              style: d.text.caption.copyWith(color: c.textFaint),
            ),
          ],
        ),
      ],
    );
  }
}

/// Light, dark, or follow the phone.
///
/// ─── WHY THIS STEP EXISTS AT ALL, AND WHY IT IS NOT PER DISTRO ──────────────
///
/// Wanting a light phone is a fact about the person and the room they are in,
/// not about which desktop they are imitating. So [LauncherPrefs.themeMode] is
/// promoted to the global bucket, and this step and the Appearance section in
/// Settings write the SAME value. Setting it here and setting it later are the
/// same act, which is why the subtitle says so out loud.
///
/// ─── A DISTRO THAT SHIPS NO LIGHT PALETTE ───────────────────────────────────
///
/// It stays dark, and the step SAYS SO rather than hiding itself. Two reasons.
/// Hiding it would make the wizard change length when you go back and pick a
/// different distro, which is exactly the failure `_stepsFor` is built as an
/// enum to survive, and the preference is worth recording anyway: it applies
/// the moment any distro with a light block is installed.
/// One distro, with a picture of the desktop it gives you.
///
/// ─── WHY A PREVIEW AND NOT A ROW OF TEXT ────────────────────────────────────
///
/// "Top bar, dock down the left, activities overview" is an accurate sentence
/// and it is useless to the person it is aimed at. This is the screen where
/// someone decides what their phone will look like for the next year, and the
/// list gave them three taglines to imagine from. The dock step three screens
/// later drew them a picture for a decision an order of magnitude smaller.
///
/// [DevicePreview] costs almost nothing here, which is why this is a small
/// change rather than a project: it paints from six palette colours and four
/// layout scalars, all of which `setupDistrosProvider` has already loaded. No
/// wallpaper decode, no icon lookup, no EffectiveTheme to build. Three of them
/// on one screen is three gradients and some rectangles.
/// The distro's own icons, or each app's own artwork.
///
/// ─── TWO CARDS, BECAUSE THE ANSWER IS A PICTURE ─────────────────────────────
///
/// The first version was two rows with four coloured squares beside each. It
/// was honest and it communicated nothing: four flat orange plates do not tell
/// anyone what an outline icon set looks like, and four palette steps look even
/// less like app artwork than they do like icons.
///
/// So each option carries eight icons at a size where the difference is the
/// obvious thing on the screen, and the stage is gone: see `_stage`, which
/// could only ever have drawn one of the two answers while the user was
/// choosing between them.
///
/// ─── ONE SIDE IS REAL AND THE OTHER CANNOT BE, YET ──────────────────────────
///
/// `getIcon` needs no pack, so App icons genuinely shows this phone's own first
/// eight apps. The distro's set cannot: `previewIcons` renders from
/// `arcticons-line`, which is the 10.58 MB download this step exists to ask
/// about, so before the answer it returns eight nulls.
///
/// Rather than pick one, this ASKS and degrades. `previewIcons` is called every
/// time; when bytes come back the card shows the true thing, and when they do
/// not it falls back to outline glyphs in the distro's accent on its own plate.
/// Someone who already has the pack, or who backs into this step after choosing
/// it, sees the truth, and the card improves itself with no second code path.
///
/// It also drives the SIZE label. Real bytes mean the pack is installed, which
/// means there is nothing to download, so quoting ten megabytes at that point
/// would be quoting a cost the user has already paid.
class _StepIcons extends ConsumerWidget {
  const _StepIcons({
    required this.theme,
    required this.mono,
    required this.distroIcons,
    required this.onChanged,
  });

  final EffectiveTheme theme;
  final bool mono;
  final bool distroIcons;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DEVICE pixels, because native renders a bitmap and a logical number
    // produces a soft icon on every phone above 1x. The icons screen asks the
    // same way for the same reason.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sizePx = (40 * dpr).round();

    // The distro's own accent, which for the fourteen official packs IS the
    // pack's tint: `ubuntu-24-04-line` carries `#e95420` and so does Ubuntu's
    // palette. Read from the palette rather than the catalogue so this works
    // before an index has ever been fetched, which on a fresh device is the
    // only state this step ever runs in.
    final tint = _hexOf(theme.palette.accent);

    final shot = ref.watch(_iconPreviewProvider((tint: tint, sizePx: sizePx)));
    final drawn = [
      for (final b in shot.value ?? const <Uint8List?>[])
        if (b != null) b,
    ];
    final haveReal = drawn.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconOption(
          mono: mono,
          selected: distroIcons,
          onTap: () => onChanged(true),
          title: '${theme.spec.name} icons',
          // Absent, not "0 MB", once the pack is already here. A nullable fact
          // renders as no row rather than as a placeholder.
          trailing: haveReal ? null : 'About 10 MB',
          note: haveReal
              ? 'One outline set across every app, in this distro colour.'
              : 'One outline set across every app, in this distro colour. '
                  'Downloaded once and shared by every distro.',
          grid: _DistroIconGrid(theme: theme, drawn: drawn),
        ),
        const SizedBox(height: 10),
        _IconOption(
          mono: mono,
          selected: !distroIcons,
          onTap: () => onChanged(false),
          title: 'App icons',
          trailing: 'Nothing to download',
          note: "Each app's own artwork, in this distro shape.",
          grid: _AppIconGrid(sizePx: sizePx),
        ),
      ],
    );
  }
}

/// `#RRGGBB` for the native preview bridge, which parses a hex string.
///
/// Alpha is dropped rather than passed: a tint is a colour, the pack applies it
/// at full opacity, and handing native eight hex digits where it expects six is
/// the kind of thing that fails as a black icon rather than as an error.
String _hexOf(Color c) {
  final v = c.toARGB32() & 0x00FFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// Eight of the user's real apps, rendered in an arbitrary tint by native.
///
/// A RECORD as the family key, for the structural equality a key needs without
/// a hand-written `==` whose only failure mode is forgetting the next field.
///
/// Auto-disposing on purpose: these bitmaps describe a moment of choosing and
/// must not outlive the wizard. Native caches none of them either, because
/// `IconCache` keys by the APPLIED style and a previewed colour is not one.
final _iconPreviewProvider = FutureProvider.family<List<Uint8List?>,
    ({String tint, int sizePx})>((ref, key) async {
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  if (apps.isEmpty) return const [];

  final keys = [for (final a in apps.take(8)) a.componentKey];
  try {
    return await ref
        .read(launcherHostApiProvider)
        .previewIcons(keys, key.tint, key.sizePx);
  } catch (_) {
    // The pack is not installed, or the bridge is not there at all, which is
    // exactly the state of a widget test. Empty, and the card draws glyphs.
    return const [];
  }
});

/// What the distro's pack would give you: real bytes when they exist, outline
/// glyphs in the accent when they do not. See [_StepIcons] for why both.
class _DistroIconGrid extends StatelessWidget {
  const _DistroIconGrid({required this.theme, required this.drawn});

  final EffectiveTheme theme;
  final List<Uint8List> drawn;

  /// Eight generic shapes standing in for eight apps.
  ///
  /// Deliberately not the user's own apps recoloured. A line pack draws its OWN
  /// outline of a messaging app; silhouetting the installed artwork would be a
  /// different picture that happens to be per-app, which is a more convincing
  /// wrong answer than an obviously generic right one.
  static const _glyphs = <IconData>[
    Icons.chat_bubble_outline,
    Icons.photo_camera_outlined,
    Icons.public,
    Icons.music_note_outlined,
    Icons.mail_outline,
    Icons.place_outlined,
    Icons.calendar_today_outlined,
    Icons.shopping_bag_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final radius = 40 * theme.icons.cornerRadius.clamp(0.0, 0.5).toDouble();

    return _Eight(
      builder: (i, side) {
        if (i < drawn.length) {
          return Image.memory(drawn[i], fit: BoxFit.contain);
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: p.bgBottom,
            borderRadius: BorderRadius.circular(radius * side / 40),
          ),
          child: Center(
            child: Icon(_glyphs[i], size: side * 0.58, color: p.accent),
          ),
        );
      },
    );
  }
}

/// This phone's own first eight apps with NO PACK over them.
///
/// ─── AND NOT [AppIcon], WHICH IS WHAT THIS USED TO BE ───────────────────────
///
/// `AppIcon` goes through `getIcon`, which renders the APPLIED style. During
/// this step nothing has been written yet, so the applied style is still the
/// distro default with `brandPack` resolved through `defaultLinePackFor`. On a
/// device that already holds `arcticons-line` that is the distro's outline set,
/// so this card drew Ubuntu icons and the two options were identical.
///
/// Worse, it was identical only SOMETIMES: a device without the pack fell
/// through to the generator and looked correct. A comparison that depends on
/// what the phone happens to have installed is not a comparison.
///
/// `previewGeneratedIcons` renders the generator tier on its own, so this is
/// the same picture on every device regardless of what is on disk. See the
/// method's own note for why it is not [getIcon] with an argument.
class _AppIconGrid extends ConsumerWidget {
  const _AppIconGrid({required this.sizePx});

  final int sizePx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shot = ref.watch(_appIconPreviewProvider(sizePx));
    final bytes = shot.value ?? const <Uint8List?>[];

    return _Eight(
      builder: (i, side) {
        if (i >= bytes.length) return const SizedBox.shrink();
        final b = bytes[i];
        // Nothing could be extracted for this app, which is rare and not worth
        // a placeholder: an empty slot reads as loading, a grey box reads as
        // broken. The grid simply has a gap.
        if (b == null) return const SizedBox.shrink();
        return Image.memory(b, fit: BoxFit.contain);
      },
    );
  }
}

/// The generator tier for eight of this phone's apps. Sibling of
/// [_iconPreviewProvider], keyed only by size because there is no colour to
/// substitute: the artwork IS the app's own.
final _appIconPreviewProvider =
    FutureProvider.family<List<Uint8List?>, int>((ref, sizePx) async {
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  if (apps.isEmpty) return const [];

  final keys = [for (final a in apps.take(8)) a.componentKey];
  try {
    return await ref
        .read(launcherHostApiProvider)
        .previewGeneratedIcons(keys, sizePx);
  } catch (_) {
    // The bridge is not there at all, which is exactly the state of a widget
    // test. Empty, and the grid draws nothing rather than throwing.
    return const [];
  }
});

/// Four across, two down, sized from the width it is given.
///
/// A [LayoutBuilder] rather than a fixed number, because the two grids sit
/// inside cards whose padding differs by a pixel when one is selected, and a
/// hardcoded side is how the same widget ends up correct in one card and
/// overflowing in the other.
class _Eight extends StatelessWidget {
  const _Eight({required this.builder});

  final Widget Function(int index, double side) builder;

  @override
  Widget build(BuildContext context) {
    const cols = 4;
    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, box) {
        final side =
            ((box.maxWidth - gap * (cols - 1)) / cols).clamp(24.0, 56.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var col = 0; col < cols; col++)
                    SizedBox(
                      width: side,
                      height: side,
                      child: builder(row * cols + col, side),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One choosable card: radio, name, an optional right-aligned fact, the grid,
/// and a line of prose under it.
///
/// Shaped like [SetupRow] rather than reusing it, because that widget puts its
/// marker and text in a Row with a small optional `preview` on the right, and
/// this needs the picture to be the body of the card rather than an ornament
/// beside it. Same border weights, same selected treatment, same radius rule.
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.mono,
    required this.selected,
    required this.onTap,
    required this.title,
    required this.note,
    required this.grid,
    this.trailing,
  });

  final bool mono;
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String note;
  final String? trailing;
  final Widget grid;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(selected ? 10 : 11),
        decoration: BoxDecoration(
          color: selected ? c.surfaceAlt : null,
          borderRadius: BorderRadius.circular(mono ? 0 : 10),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Radio(on: selected, mono: mono),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: d.text.body.copyWith(color: c.text),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: d.text.caption.copyWith(color: c.textFaint),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            grid,
            const SizedBox(height: 8),
            Text(
              note,
              softWrap: true,
              style: d.text.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The console keeps brackets and no fill, like every other control there.
class _Radio extends StatelessWidget {
  const _Radio({required this.on, required this.mono});

  final bool on;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    if (mono) {
      return Text(
        on ? '[x]' : '[ ]',
        style: ChromeScope.of(context)
            .text
            .label
            .copyWith(color: on ? c.accent : c.textMuted),
      );
    }

    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? c.accent : c.line, width: on ? 4.5 : 1.5),
      ),
    );
  }
}

class _StepAppearance extends ConsumerWidget {
  const _StepAppearance({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final mode = theme.prefs.themeMode ?? 'system';
    final hasLight = theme.spec.paletteLight != null;

    // The dock preview, reused: it paints from EffectiveTheme.palette, which is
    // already the resolved variant, so it shows the choice rather than
    // describing it. No new preview widget, and no second idea of what a
    // desktop looks like.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetupChoice(
          mono: mono,
          selected: mode,
          options: const {
            'system': 'System',
            'light': 'Light',
            'dark': 'Dark',
          },
          // Written through the ordinary per-theme notifier even though the
          // value is global. `PrefsNotifier.edit` routes it; a call site that
          // knew which bucket a field lived in would be a call site that can
          // pick wrong.
          onChanged: (v) => notifier.edit((p) => p.copyWith(themeMode: v)),
        ),
        const SizedBox(height: 10),
        // The one subtitle worth keeping, as a caption under the strip rather
        // than as a line on every option. The other two never needed one:
        // "Light" and "Dark" explain themselves.
        Text(
          "Follows the phone's own light and dark switch.",
          softWrap: true,
          style: d.text.caption.copyWith(color: d.colors.textMuted),
        ),
        if (!hasLight) ...[
          const SizedBox(height: 10),
          Text(
            ref.t('setup.appearance.darkOnly', {'name': theme.spec.name}),
            softWrap: true,
            style: d.text.caption.copyWith(color: d.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _StepDock extends ConsumerWidget {
  const _StepDock({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final grid = theme.prefs.dockGridButton ?? 'end';

    final d = ChromeScope.of(context);
    final side = switch (theme.dock) {
      DockSide.left => 'left',
      DockSide.right => 'right',
      DockSide.bottom => 'bottom',
      DockSide.off => 'off',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MiniLabel(text: 'Where it sits'),
        const SizedBox(height: 8),
        SetupChoice(
          mono: mono,
          selected: side,
          // RIGHT IS ABSENT ON PURPOSE, as it was before. The three answers are
          // the ones the shells actually ship, and a fourth chip for a side no
          // bundled distro uses would cost a quarter of the strip's width to
          // offer a layout nobody asked for. A theme authoring `right` still
          // resolves and still draws; it simply is not offered here.
          options: const {
            'left': 'Left',
            'bottom': 'Bottom',
            'off': 'None',
          },
          onChanged: (v) => notifier.edit((p) => p.copyWith(dockSide: v)),
        ),
        const SizedBox(height: 10),
        Text(
          theme.dock == DockSide.off
              ? ref.t('setup.theDrawerIsStill')
              : ref.t('setup.dock.leftSub', {'name': theme.spec.name}),
          softWrap: true,
          style: d.text.caption.copyWith(color: d.colors.textMuted),
        ),
        if (theme.dock != DockSide.off) ...[
          const SizedBox(height: 16),
          _MiniLabel(text: ref.t('setup.appGridButton')),
          const SizedBox(height: 8),
          SetupChoice(
            mono: mono,
            selected: grid,
            options: const {
              'end': 'End',
              'start': 'Start',
              'off': 'Hidden',
            },
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(dockGridButton: v)),
          ),
        ],
      ],
    );
  }
}

class _StepDrawer extends ConsumerWidget {
  const _StepDrawer({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    // The RESOLVED style, so what Setup preselects is exactly what the
    // drawer will do, including a distro's own authored default. Setup
    // showing 'List' preselected while the drawer actually came up paged
    // was a lie the user would only catch after finishing.
    final style = theme.drawerScrollStyle;

    return Column(
      children: [
        const _MiniLabel(text: 'Columns'),
        Row(
          children: [
            for (final n in const [3, 4, 5, 6])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SetupRow(
                    title: '$n',
                    selected: theme.drawerCols == n,
                    mono: mono,
                    marker: mono ? SetupMarker.chevron : SetupMarker.radio,
                    onTap: () =>
                        notifier.edit((p) => p.copyWith(drawerCols: n)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const _MiniLabel(text: 'How it moves'),

        // ── THE NAMES COME FROM THE ENUM, NOT FROM HERE ─────────────────
        //
        // This held its own map of three styles and their blurbs, and Settings
        // held a different list of the same three with no blurbs at all. Two
        // hand-written lists is two chances to add a style to one and not the
        // other, which is the drift that left `pages || cube` in one file
        // disagreeing with `'vertical','pages','cube'` in another.
        //
        // [DrawerTransition.catalogue] is the six that ARE transitions, in the
        // order they should read: the default first, then the one people have
        // heard of, then its two variations, then the two that do not rotate.
        //
        // ─── AND THE ROWS PLAY WHAT THEY NAME ───────────────────────────
        //
        // A word cannot tell a cube from a cylinder, and neither can a still.
        // Each row carries the transition running beside its name, from the
        // same function the drawer itself applies, so nothing here can promise
        // a motion the drawer does not have.
        ScrollStylePlayer(
          // The style the distro or the user already chose demonstrates itself
          // once when the step opens, so the wizard shows what the preselected
          // answer means before anyone taps anything.
          initial: style,
          builder: (context, phase, playing, play) => Column(
            children: [
              for (final t in DrawerTransition.catalogue)
                SetupRow(
                  title: t.copy.$1,
                  subtitle: t.copy.$2,
                  selected: style == t.value,
                  mono: mono,
                  marker: mono ? SetupMarker.chevron : SetupMarker.radio,
                  onTap: () {
                    notifier
                        .edit((p) => p.copyWith(drawerScrollStyle: t.value));
                    // Every tap plays, including one on the row that is already
                    // selected. A picker whose second tap does nothing reads as
                    // broken rather than as already answered.
                    play(t.value);
                  },
                  preview: SizedBox(
                    width: 34,
                    height: 46,
                    child: ScrollStyleTile(
                      style: t.value,
                      palette: theme.palette,
                      // Only the row being demonstrated moves. The others hold
                      // the frozen pose that says what they do.
                      phase: playing == t.value
                          ? phase
                          : ScrollStyleTile.restPhase,
                    ),
                  ),
                ),
              // Last, and outside the catalogue, because it is the one answer
              // that is not a transition at all: it swaps the paged drawer for
              // a single scrolling grid.
              SetupRow(
                title: 'One long list',
                subtitle: 'Scrolls up and down. No pages at all.',
                selected: style == 'vertical',
                mono: mono,
                marker: mono ? SetupMarker.chevron : SetupMarker.radio,
                onTap: () => notifier
                    .edit((p) => p.copyWith(drawerScrollStyle: 'vertical')),
                preview: SizedBox(
                  width: 34,
                  height: 46,
                  child: ScrollStyleTile(
                    style: 'vertical',
                    palette: theme.palette,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepFolders extends ConsumerWidget {
  const _StepFolders({
    required this.theme,
    required this.mono,
    required this.skipped,
    required this.onToggle,
  });

  final EffectiveTheme theme;
  final bool mono;

  /// Names the user has unticked. Owned by the wizard state so that `_next`
  /// can read it when the user advances, which is the moment creation actually
  /// happens.
  final Set<String> skipped;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);

    if (suggestions.isEmpty) {
      return Text(
        ref.t('setup.nothingWorthGroupingYet'),
        softWrap: true,
        style: d.text.body.copyWith(color: d.colors.textMuted),
      );
    }

    // ─── THE FOLDERS ARE SHOWN, NOT COUNTED ──────────────────────────────
    //
    // This step used to be one checkbox reading "Create 8 folders", and the
    // comment here admitted the better screen needed FolderSuggestion's name
    // and members exposed. They always were: `name`, `componentKeys` and
    // `size` have been on the class the whole time.
    //
    // So it draws them. Eight folders with their real names and the apps
    // actually going into each is the difference between agreeing to a number
    // and seeing what you are about to get, and it is the one screen in the
    // wizard with the room to do it.
    final byKey = {for (final a in apps) a.componentKey: a};

    // GAMES FIRST, which is what the copy has always claimed.
    //
    // `propose` sorts biggest-first, so a Google block of twenty-five outranks
    // a Games folder of four and the promise was quietly false. Reordering here
    // rather than in the engine, because size-first is right for a settings
    // list and recognisability is right for a first run: this is the only place
    // someone has never seen any of these folders before.
    final ordered = [
      ...suggestions.where((s) => s.kind == SuggestionKind.games),
      ...suggestions.where((s) => s.kind != SuggestionKind.games),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── EACH FOLDER IS ITS OWN ANSWER NOW ─────────────────────────
        //
        // This was a grid of folders you could look at and ONE checkbox
        // underneath reading "create 8 folders". So the screen showed eight
        // decisions and offered one, and the only way to refuse the Google
        // block was to refuse the Games folder with it. Tapping a folder is
        // the obvious gesture and it was doing nothing.
        //
        // The tile itself is untouched: selection is drawn AROUND it, as a
        // ring and a mark, so a folder that will not be created is dimmed
        // rather than redrawn. `FolderTile` keeps knowing about folders and
        // this keeps knowing about choosing.
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final sg in ordered)
              _PickableFolder(
                name: sg.name,
                chosen: !skipped.contains(sg.name),
                mono: mono,
                onTap: () => onToggle(sg.name),
                child: FolderTile(
                  theme: theme,
                  name: sg.name,
                  size: 60,
                  // Resolved against the live app list, so a member that has
                  // been uninstalled between propose and paint is absent rather
                  // than a gap. whereType drops the nulls in one pass.
                  members: sg.componentKeys
                      .map((k) => byKey[k])
                      .whereType<AppEntry>()
                      .toList(),
                  labelColor: d.colors.text,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          // COUNTS WHAT IS TICKED, not what was proposed. A line reading
          // "8 folders" over six ticked ones is the kind of small lie that
          // makes someone stop trusting the rest of the screen.
          switch (ordered.length - skipped.length) {
            0 => 'No folders will be created.',
            1 => '1 folder will be created when you continue.',
            final n => '$n folders will be created when you continue.',
          },
          softWrap: true,
          style: d.text.body.copyWith(color: d.colors.text),
        ),
        const SizedBox(height: 6),
        Text(
          ref.t('setup.skippingLosesNothingThey'),
          softWrap: true,
          style: d.text.caption.copyWith(color: d.colors.textMuted),
        ),
      ],
    );
  }
}

/// The fake install.
///
/// ONCE, EVER. Not on the theme-switch path, not on cold start: this is the
/// first-run payoff and nothing else. Switching distro later in Settings shows
/// the boot log or the splash, which are the repeatable ones.
///
/// Roughly two and a half seconds. Long enough to land, short enough that it
/// does not become the third theatrical screen in a row before anyone has
/// touched the desktop, which is the failure mode: the boot log and the splash
/// still follow this.
///
/// The lines are keyed by SHELL, so a console install talks like pacstrap and a
/// wizard talks like Ubiquity. Nothing here mentions erasing, formatting or
/// partitioning, and nothing here ever should.
/// Selection chrome around a folder tile.
///
/// A ring and a mark, drawn AROUND the child rather than by it. `FolderTile` is
/// also used in Settings and in the drawer, where nothing is being chosen, so
/// teaching it about selection would put a concept in three screens to serve
/// one. Unticked is dimmed rather than hidden, because the point of the grid is
/// seeing what you are turning down.
class _PickableFolder extends StatelessWidget {
  const _PickableFolder({
    required this.name,
    required this.chosen,
    required this.mono,
    required this.onTap,
    required this.child,
  });

  final String name;
  final bool chosen;
  final bool mono;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color:
                    chosen && !mono ? c.accent.withValues(alpha: 0.12) : null,
                border: Border.all(
                  color: chosen ? c.accent : c.line,
                  width: chosen ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(mono ? 0 : 12),
              ),
              // Dimmed rather than greyed: a colour filter would fight every
              // icon inside the tile, and half opacity reads as "off" on any
              // wallpaper.
              child: Opacity(opacity: chosen ? 1 : 0.45, child: child),
            ),
            if (chosen)
              Positioned(
                top: -5,
                right: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 12, color: c.surface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepInstall extends StatefulWidget {
  const _StepInstall({
    required this.theme,
    required this.skin,
    required this.onDone,
  });

  final EffectiveTheme theme;
  final SetupSkin skin;
  final Future<void> Function() onDone;

  @override
  State<_StepInstall> createState() => _StepInstallState();
}

class _StepInstallState extends State<_StepInstall> {
  static const _tickMs = 380;

  Timer? _timer;
  int _line = 0;
  late final List<String> _lines = _linesFor(widget.theme.shell);

  static List<String> _linesFor(ShellKind shell) => switch (shell) {
        ShellKind.tui => const [
            'mounting /proc /sys /dev',
            'installing base packages',
            'reading installed applications',
            'writing profile',
            'enabling g-tty autologin',
            'done',
          ],
        ShellKind.aqua => const [
            'Preparing your desktop',
            'Applying appearance',
            'Reading your apps',
            'Setting up the Dock',
            'Almost there',
            'Done',
          ],
        _ => const [
            'Copying desktop files',
            'Applying theme and icons',
            'Reading installed applications',
            'Building the dock',
            'Configuring folders',
            'Done',
          ],
      };

  @override
  void initState() {
    super.initState();
    // Reduce-motion is honoured by the caller chain elsewhere; here the whole
    // step is short enough that the honest opt-out is to run it anyway and let
    // the boot gate behind it handle the long one.
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (t) {
      if (!mounted) return;
      if (_line >= _lines.length - 1) {
        t.cancel();
        widget.onDone();
        return;
      }
      setState(() => _line++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final progress = (_line + 1) / _lines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: c.line,
            valueColor: AlwaysStoppedAnimation<Color>(c.accent),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i <= _line; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _lines[i],
              softWrap: true,
              style: d.text.caption.copyWith(
                color: i == _line ? c.text : c.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

/// A small framed phone showing the setting being changed.
///
/// FRAMED, unlike the old full-bleed backdrop. Once the installer has a window
/// of its own, a second full-bleed surface behind it fights the frame: you
/// cannot tell which of the two things on screen you are configuring. A phone
/// inside the content area is unambiguous, and it is also how every real
/// installer shows a layout choice.
class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: d.text.label.copyWith(color: d.colors.textMuted),
        ),
      ),
    );
  }
}

/// One quiet line, not a card: by this point the user has already said no twice
/// and a second full-size plea would be nagging rather than reminding.
class _NagLine extends StatelessWidget {
  const _NagLine({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      onTap: onFix,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(Icons.home_outlined, size: 15, color: c.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t('settings.gLauncherIsNot'),
              softWrap: true,
              style: d.text.caption.copyWith(color: c.warn),
            ),
          ),
          Text(
            context.t('setup.fix'),
            style: d.text.caption
                .copyWith(color: c.warn, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Notification badges: the one step that asks for a permission.
///
/// ─── WHY IT ASKS HERE AND NOT SILENTLY LATER ────────────────────────────────
///
/// Notification access has no runtime prompt. Android gates it behind a full
/// settings page and a confirmation dialog warning that this app will be able
/// to read every notification, including personal content. That warning is
/// accurate about the API and wrong about this launcher, which counts
/// notifications per package and reads no title, body, sender or image.
///
/// A user who meets that dialog cold, with no idea why the launcher wants it,
/// makes a sensible decision on bad information and says no. So the ask happens
/// here, where there is room for a sentence, after the dock and the drawer have
/// already drawn the icons a badge would sit on.
///
/// ─── SKIPPING IS A REAL ANSWER ──────────────────────────────────────────────
///
/// There is no Skip button because there does not need to be one: the wizard's
/// own Continue is the skip. Nothing on this screen is required, nothing is
/// written unless the user acts, and the launcher works identically without it.
/// Adding a Skip beside Continue would imply the two do different things.
/// Which desklets land on the first desktop, and where.
///
/// ─── A SHORTLIST, NOT THE PICKER ────────────────────────────────────────────
///
/// `DeskletKinds.all` is the full catalogue and the long-press menu already
/// shows it. Repeating it here would make this the longest step in the wizard
/// and would ask someone who has never seen a desklet to evaluate a dozen. So
/// this offers the six that are legible with no explanation, and the caption
/// points at the menu for the rest.
///
/// ─── AND THE NAMES ARE THE LINUX ONES ───────────────────────────────────────
///
/// `df -h`, `free -h`, `uptime`, `fastfetch`, `conky`. Those labels already
/// live on the kinds; this only refuses to translate them into "Storage" and
/// "Memory" on the way past. They are the reason this launcher is not a Nova
/// clone, and the first screen a new user sees is the wrong place to hide it.
class _StepWidgets extends ConsumerWidget {
  const _StepWidgets({
    required this.theme,
    required this.mono,
    required this.chosen,
    required this.spot,
    required this.onToggle,
    required this.onSpot,
  });

  final EffectiveTheme theme;
  final bool mono;
  final Set<String> chosen;
  final String spot;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onSpot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // THE DISTRO'S OWN LIST. See [offeredDesklets]: the hardcoded seven this
    // used to carry offered `df`, `free` and `uptime`, all of which are
    // pane-only, so ticking one wrote a desklet that `renderable` drops from
    // every shell this step runs on. It also offered `glance`, which Ubuntu no
    // longer names, and missed the five Ubuntu does.
    final kinds = offeredDesklets(theme);
    if (kinds.isEmpty) return const SizedBox.shrink();

    // What is on workspace one right now, which the commit in `_next` leaves
    // alone. Read here rather than passed in, because it is derived from the
    // same `theme` this widget already has and a parameter would be a second
    // copy of a rule that has to match the commit exactly.
    final placed = {
      for (final dk in theme.prefs.desklets)
        if (dk.page == 0) dk.kind,
    };
    final willPlace =
        kinds.any((k) => chosen.contains(k.id) && !placed.contains(k.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── LIVE TILES, NOT NAMES ─────────────────────────────────────
        //
        // This was a Wrap of `_WidgetChoice` chips, and the argument for that
        // was real: a conky at 60dp is four grey bars, and the stage above is
        // where the picture goes. It answers the wrong question. The stage
        // shows WHERE the chosen ones land; this asks WHICH, and a name cannot
        // tell you whether you want a fastfetch on your home screen.
        //
        // `desklet_picker` has drawn nine of these live for a while, so both
        // the precedent and the budget exist. Two columns rather than the
        // picker's full-screen grid, because this sits inside an installer
        // window with a stage above it and a footer below.
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          // Swatch plus the label line beneath it. Fixed rather than measured,
          // because an intrinsic pass over live desklets would rebuild each one
          // twice on every scroll frame.
          childAspectRatio: 1.35,
          children: [
            for (final k in kinds)
              _WidgetTile(
                theme: theme,
                kind: k,
                // `conky` rather than `System monitor`. The kind's own label is
                // the settings-screen name and this is the shop window.
                label: k.id == 'monitor' ? 'conky' : k.label,
                chosen: chosen.contains(k.id),
                mono: mono,
                onTap: () => onToggle(k.id),
              ),
          ],
        ),
        // ─── THE POSITION STRIP IS ABSENT, NOT DISABLED ──────────────────
        //
        // Nothing to PLACE means no question left to ask, and that is no longer
        // the same as nothing ticked. An existing placement stays where the
        // distro's authored starter put it, so on a fresh Ubuntu, whose default
        // ticks are exactly what the starter already laid out, this strip would
        // move nothing at all. It appears once something is ticked that is not
        // on the desktop yet, and governs those.
        //
        // A greyed-out control asks the reader to work out WHY it is greyed
        // out, and the answer is already on the screen above it.
        if (willPlace) ...[
          const SizedBox(height: 16),
          const _MiniLabel(text: 'Where they sit'),
          const SizedBox(height: 8),
          SetupChoice(
            mono: mono,
            selected: spot,
            options: const {
              'top': 'Top',
              'middle': 'Middle',
              'bottom': 'Bottom',
            },
            onChanged: onSpot,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          chosen.isEmpty
              ? 'No widgets. Long press the desktop to add one any time.'
              : switch (chosen.length) {
                  1 => '1 widget, on your first workspace.',
                  final n => '$n widgets, on your first workspace.',
                },
          softWrap: true,
          style: d.text.body.copyWith(color: c.text),
        ),
        const SizedBox(height: 6),
        Text(
          'Every one is skinned by ${theme.spec.name}. More in the desktop menu later.',
          softWrap: true,
          style: d.text.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

/// One tickable desklet, drawn as itself.
///
/// ─── IT USED TO BE A NAME IN A BOX ──────────────────────────────────────────
///
/// `_WidgetChoice` was a chip with a label, and its docblock argued that a
/// conky at 60dp is four grey bars and that the stage above is where the
/// picture belongs. Both halves are true and the conclusion does not follow.
/// The stage answers WHERE the chosen ones sit, which is a smaller question
/// than which ones you want, and "Fastfetch" tells someone who has never seen
/// one absolutely nothing about whether they want it.
///
/// [DeskletPreview] is the same widget the picker uses, rendering through the
/// same `buildDesklet` the desktop does, so this cannot show something the
/// desktop would not.
class _WidgetTile extends StatelessWidget {
  const _WidgetTile({
    required this.theme,
    required this.kind,
    required this.label,
    required this.chosen,
    required this.mono,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final DeskletKind kind;
  final String label;
  final bool chosen;
  final bool mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: chosen && !mono ? c.accent.withValues(alpha: 0.14) : null,
          border: Border.all(
            color: chosen ? c.accent : c.line,
            width: chosen ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(mono ? 0 : 10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded rather than a fixed height: the tile is sized by the
            // grid's aspect ratio, so the swatch takes whatever the label row
            // leaves. A fixed number here is how the same widget ends up
            // correct on one phone and overflowing on the next.
            Expanded(
              child: DeskletPreview(
                theme: theme,
                kind: kind,
                height: double.infinity,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  chosen ? Icons.check : Icons.add,
                  size: 13,
                  color: chosen ? c.accent : c.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: d.text.caption.copyWith(
                      color: chosen ? c.text : c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepNotifications extends ConsumerStatefulWidget {
  const _StepNotifications({
    required this.theme,
    required this.mono,
    required this.want,
    required this.onWantChanged,
  });

  final EffectiveTheme theme;
  final bool mono;

  /// Whether the user wants badges. Owned by the wizard, because Continue is
  /// what acts on it and Continue lives up there.
  final bool want;
  final ValueChanged<bool> onWantChanged;

  @override
  ConsumerState<_StepNotifications> createState() => _StepNotificationsState();
}

class _StepNotificationsState extends ConsumerState<_StepNotifications>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ─── THE GRANT ARRIVES WITH NO EVENT ──────────────────────────────────
  ///
  /// Continue sends the user to a system settings page. There is no result to
  /// await and no broadcast to listen for, so the only signal that anything
  /// happened is the launcher being resumed. Without this the row would still
  /// read as ungranted after a successful grant, and the user would reasonably
  /// conclude it had failed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(notificationAccessProvider);
    ref.read(badgeCountsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final granted = ref.watch(notificationAccessProvider);
    final on = granted.asData?.value ?? false;

    // What this distro would draw, named rather than described in the abstract.
    // "Badges" means a dot under GNOME and a number under Plasma, and the person
    // is deciding whether they want the thing they are about to see.
    final what = switch (badgeStyleFor(widget.theme)) {
      BadgeStyle.count => ref.t('setup.notifications.asCount'),
      _ => ref.t('setup.notifications.asDot'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── A TICK, NOT A TRIP ────────────────────────────────────────
        //
        // The same control the folders step uses for the same kind of question:
        // do you want this, yes or no, answered where you are standing. The
        // system page is opened by Continue, not by this row, so deciding and
        // being handed off are two separate moments.
        //
        // Locked ON and non-interactive once granted. Turning it off here would
        // read as revoking access, which this cannot do: only Android's own
        // screen can, and pretending otherwise would leave badges drawing under
        // an unticked box.
        SetupRow(
          title: on
              ? ref.t('setup.notifications.allowed')
              : ref.t('setup.notifications.allow'),
          subtitle: on ? what : ref.t('setup.notifications.countsOnly'),
          selected: on || widget.want,
          marker: SetupMarker.check,
          mono: widget.mono,
          enabled: !on,
          onTap: on ? () {} : () => widget.onWantChanged(!widget.want),
        ),
        const SizedBox(height: 10),
        Text(
          ref.t('setup.notifications.note'),
          softWrap: true,
          style: d.text.caption.copyWith(color: d.colors.textMuted),
        ),
      ],
    );
  }
}
