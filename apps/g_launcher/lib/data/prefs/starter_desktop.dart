import '../../engine/desklet_skin.dart';
import 'desklet_layout.dart';
import 'launcher_prefs.dart';

/// Lay out a distro's authored desktop, once. PHASE D3.
///
/// Choosing Arch should give you a waybar-ish desktop, not an empty screen with
/// a bar. That is the difference between a theme and a skin, and it is the
/// cheapest way to make a distro feel finished: authored placements shipped in
/// `theme.json`, applied the first time the theme is used and never again.
///
/// ─── PURE, AND THAT IS THE POINT ────────────────────────────────────────────
///
/// This runs against content that can arrive over the CDN, so it goes through
/// the same clamps and collision checks as a user drag. An authored desktop
/// that overlaps itself, or asks for a 6-wide tile on a 4-column grid, is
/// silently corrected rather than trusted — the exact rule `SplashSpec` and
/// `IconSizing.parseScale` follow for the same reason.
///
/// ─── EXACT CELLS ARE HONOURED, MISSING ONES ARE PACKED ──────────────────────
///
/// A starter with `col`/`row` uses `placeAt`, which REFUSES rather than
/// relocating: the point of shipping a layout is that it looks like the
/// screenshot, and one silently reflowed tile makes the whole desktop look
/// like a mistake. A starter with no position uses `place`, which packs it
/// wherever it fits, for themes that care which desklets appear but not where.
class StarterDesktop {
  const StarterDesktop._();

  /// Returns [prefs] unchanged when there is nothing to do, so a caller can
  /// compare identity and skip the write entirely.
  ///
  /// [skip] names kinds this starter must NOT place, and it exists for two
  /// reasons that arrive from opposite directions.
  ///
  /// ─── THE USER WAS ASKED, SO THE USER WINS ────────────────────────────────
  ///
  /// Setup's widgets step asks which desklets you want and writes the answer as
  /// it advances. This runs afterwards, at the end of the wizard, and it has no
  /// idea that happened: unticking the conky removed it, and then the authored
  /// starter put it straight back. The step's own comment claimed to overrule
  /// the starter, and the ordering quietly defeated it, so the whole step was
  /// decoration for any kind the distro also ships.
  ///
  /// Scoped to what was ASKED rather than to what was chosen, so a starter
  /// placement the step never mentioned is still honoured. This owns the
  /// question it was asked and nothing more.
  ///
  /// ─── AND A PANE-ONLY KIND ON A GRID IS WORSE THAN NOTHING ────────────────
  ///
  /// `DeskletLayout.renderable` drops [DeskletKind.paneOnly] kinds from a
  /// graphical surface, and `DeskletLayout.fits` does not: it walks every
  /// stored desklet. So KDE's authored `df` at (0,2) occupied a four-wide band
  /// that never drew and that nothing else could ever be placed in. Invisible
  /// and load-bearing, which is the worst pair.
  ///
  /// Filtered by the CALLER rather than tested here, because this class is pure
  /// and knows nothing about shells. See `setup_screen._seedFirstDesktop`.
  static LauncherPrefs apply(
    LauncherPrefs prefs,
    DeskletThemeBlock block, {
    required int cols,
    required int rows,
    required String Function() newId,
    Set<String> skip = const {},
  }) {
    if (block.starter.isEmpty) return prefs;

    var out = prefs;
    for (final s in block.starter) {
      if (skip.contains(s.kind)) continue;
      out = (s.col != null && s.row != null)
          ? DeskletLayout.placeAt(
              out,
              kindId: s.kind,
              page: s.page,
              col: s.col!,
              row: s.row!,
              cols: cols,
              rows: rows,
              newId: newId,
              config: s.config,
              spanX: s.spanX,
              spanY: s.spanY,
            )
          : DeskletLayout.place(
              out,
              kindId: s.kind,
              page: s.page,
              cols: cols,
              rows: rows,
              newId: newId,
              config: s.config,
              spanX: s.spanX,
              spanY: s.spanY,
            );
    }
    return out;
  }
}
