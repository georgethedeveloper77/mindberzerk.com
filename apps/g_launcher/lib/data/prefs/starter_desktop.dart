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
  static LauncherPrefs apply(
    LauncherPrefs prefs,
    DeskletThemeBlock block, {
    required int cols,
    required int rows,
    required String Function() newId,
  }) {
    if (block.starter.isEmpty) return prefs;

    var out = prefs;
    for (final s in block.starter) {
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
