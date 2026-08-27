/// What each desktop CALLS the things an app menu does.
///
/// ─── SHAPE WAS HALF THE PROBLEM AND WORDS ARE THE OTHER HALF ────────────────
///
/// [ChromeMenu] makes four families draw differently. It does not make them
/// SOUND different, and a launcher imitating a desktop is imitating its
/// vocabulary as much as its layout: KDE says Add to Panel, GNOME says Pin to
/// Dash, a Mac says Keep in Dock, and Xfce says Add to Favourites. All four are
/// the same write to `HomeLayout.pinToDock`.
///
/// One family was already doing this and the rest were not. `aqua_shell.dart`
/// hand-writes 'Keep in Dock', 'Remove from Dock' and 'Take out of the Dock' as
/// English literals in its dock menu, which is both the right instinct and the
/// wrong mechanism: those strings cannot be translated and no other surface can
/// find them. This is that instinct, made reusable and made translatable.
///
/// ─── KEYS, NOT STRINGS ──────────────────────────────────────────────────────
///
/// Every field here is an i18n KEY. The alternative is returning finished
/// English, which is how `aqua_shell` ended up with untranslatable menu items,
/// and it would put copy in a file that has no business holding any.
///
/// ─── AND ONLY THE VERBS THAT ACTUALLY DIVERGE ───────────────────────────────
///
/// Hide, Uninstall and App info are the same word on every desktop, so they are
/// not here. A table with four identical columns is a table nobody will keep
/// correct, and it invites a future edit that forks something for the sake of
/// forking it.
library;

import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart'
    show ChromeFamily, DockSide, ShellKind;

class AppMenuWords {
  const AppMenuWords({
    required this.addToHome,
    required this.pin,
    required this.unpin,
  });

  /// Put the app on the desktop grid. Only ever offered where the distro HAS
  /// one (`theme.desktopIcons`), which on an Adwaita distro is never, since
  /// GNOME's desktop is bare by design. Its label is still authored so a
  /// GNOME-family distro that turns icons on gets a sentence rather than a key.
  final String addToHome;

  final String pin;
  final String unpin;

  /// The words for a whole THEME, which is the family's plus one correction.
  ///
  /// ─── WHETHER THERE IS A DOCK IS NOT A CHROME QUESTION ───────────────────
  ///
  /// [forFamily] picks by design language, and for pin that is nearly right:
  /// GNOME says Dash, Plasma says Panel, a Mac says Dock. It is wrong on the
  /// distros that have no dock at all.
  ///
  /// Manjaro is `dock: off`, so pinning writes to `prefs.favourites`, which
  /// shows up in exactly one place: Kickoff's Favourites tab. The menu said
  /// ADD TO PANEL, naming a panel the app does not go to, on a distro with no
  /// dock for it to go to either. The user is told about a place and the app
  /// appears somewhere else.
  ///
  /// So a distro with no dock says Favourites whatever its chrome is. That is
  /// not a fallback, it is the accurate name: the list is called favourites in
  /// the prefs, in the rail and in Settings, and only the presence of a dock
  /// makes any other word true.
  static AppMenuWords forTheme(EffectiveTheme theme) {
    final base = forFamily(theme.chromeFamily);
    if (!_showsFavourites(theme)) return base;
    return AppMenuWords(
      addToHome: base.addToHome,
      pin: 'shell.addToFavourites',
      unpin: 'shell.removeFromFavourites',
    );
  }

  /// Does the user have somewhere called FAVOURITES in front of them?
  ///
  /// ─── TWO WAYS TO BE TRUE, AND THE SECOND WAS MISSING ────────────────────
  ///
  /// The first is a distro with no dock: pinning writes to `prefs.favourites`
  /// and there is nowhere else it could mean. That is Manjaro, and it is what
  /// this method originally tested.
  ///
  /// The second is a DRAWER with a favourites shelf, which is the case KDE
  /// exposed. KDE has a dock, so the first test passes it through to Breeze's
  /// vocabulary and the menu reads ADD TO PANEL. Meanwhile Kickoff is open with
  /// a tab labelled Favorites, the app lands in it, and Plasma's own Kickoff
  /// menu says Add to Favorites for exactly this reason.
  ///
  /// One list, two surfaces, and the menu was naming the one the user could not
  /// see. Five of the seven drawers show the shelf; `card` and `query` do not,
  /// and on those a distro's own word for its dock is still the honest one.
  static bool _showsFavourites(EffectiveTheme theme) {
    if (theme.dock == DockSide.off) return true;
    return switch (theme.appDrawer) {
      'tools' || 'whisker' || 'cinnamon' || 'zorin' => true,
      // The shared grid routes to Kickoff on plasma, which has the tab, and to
      // AppDrawer elsewhere, which does not. Asking the drawer NAME here would
      // get that wrong, so it asks the same question `shell_drawer` answers.
      'grid' => theme.shell == ShellKind.plasma,
      _ => false,
    };
  }

  /// The family's vocabulary. Exhaustive with no default arm, so a fifth family
  /// stops compiling here until someone chooses its words.
  static AppMenuWords forFamily(ChromeFamily family) => switch (family) {
        // GNOME pins to the Dash, which is what its dock is called.
        ChromeFamily.adwaita => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.pinToDash',
            unpin: 'shell.unpinFromDash',
          ),
        // Plasma's Kickoff offers Add to Panel beside Add to Desktop, and the
        // panel is the Task Manager rather than a dock. This app's dock is the
        // nearest thing to it, and Add to Panel is the name a Plasma user
        // reaches for.
        ChromeFamily.breeze => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.addToPanel',
            unpin: 'shell.removeFromPanel',
          ),
        // Xfce's Whisker menu says Add to Favourites, and so does Kali's.
        ChromeFamily.xfce => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.addToFavourites',
            unpin: 'shell.removeFromFavourites',
          ),
        // A WM has neither a dash nor a panel nor a dock, so favourites is
        // the only one of the four that describes anything real. Same words as
        // xfce, and deliberately not shared with it: the two are the same
        // ANSWER, not the same decision, and folding them into one arm would
        // make the next edit to Xfce's wording silently edit Arch's.
        ChromeFamily.wm => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.addToFavourites',
            unpin: 'shell.removeFromFavourites',
          ),
        // Keep in Dock is the Mac's own phrasing, and Deepin's launcher menu
        // says Send to desktop. Both keys already existed, written by hand in
        // `aqua_shell`; this is where they belong.
        // A phone has a dock and nobody calls it that. What you do to an app is
        // put it on the home screen, and the dock is a row of the home screen
        // you have not thought about; `shell.keepInDock` is the closest true
        // thing this vocabulary has and it is what the aqua distros say.
        ChromeFamily.pocket => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.keepInDock',
            unpin: 'shell.removeFromDock',
          ),
        ChromeFamily.aqua => const AppMenuWords(
            addToHome: 'shell.sendToDesktop',
            pin: 'shell.keepInDock',
            unpin: 'shell.removeFromDock',
          ),
        // Xfce's Whisker menu and the tiling desktops: favourites, not a dash
        // and not a panel.
        ChromeFamily.generic => const AppMenuWords(
            addToHome: 'shell.addToHome',
            pin: 'shell.addToFavourites',
            unpin: 'shell.removeFromFavourites',
          ),
      };
}
