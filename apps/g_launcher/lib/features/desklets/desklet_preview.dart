/// A real desklet, at rest, scaled into a box.
///
/// ─── EXTRACTED SO TWO SURFACES CANNOT DRIFT ─────────────────────────────────
///
/// This was private inside `desklet_picker.dart` as `_DeskletPreviewCard`'s
/// swatch. Setup's widgets step now shows the same thing, and the alternative
/// was a second renderer: the picker's live preview beside a setup preview that
/// approximated it. Two pictures of one object is how the storefront ended up
/// with `ThemePreview`'s twelve hand-drawn layout arms disagreeing with the
/// distros they claimed to show.
///
/// ─── IT RENDERS THROUGH buildDesklet, WHICH IS THE POINT ────────────────────
///
/// The same function the desktop calls. A preview therefore cannot drift from
/// what actually lands: add a kind, change a skin, fix a layout, and this
/// follows with no edit here. The `Desklet` handed in is synthetic, at the
/// kind's own default span, so what is previewed is what placing it would give.
///
/// ─── AND THE COST IS REAL, AND ACCEPTED ─────────────────────────────────────
///
/// These are live widgets, not stills. A monitor preview runs the stats poller,
/// a clock ticks, a network tile watches throughput. `_WidgetChoice` in setup
/// used to draw names for exactly this reason, and the reasoning was sound for
/// six chips in a row and wrong about what the step is for: the question is
/// which of these you want on your desktop, and a name does not answer it.
///
/// The picker already renders nine of these on one screen, so the precedent and
/// the budget both exist. Anything wanting more than a screenful should lazily
/// build, which a `ListView` does for free and a `Wrap` does not.
///
/// [IgnorePointer] keeps the note and search tiles, which are interactive, from
/// swallowing the tap that is meant to SELECT them.
library;

import 'package:flutter/widgets.dart';

// `Desklet` lives on LauncherPrefs, not in the engine: a placement is stored
// state, while `DeskletKind` is the catalogue of what can be placed. The picker
// reaches it the same way.
import '../../data/prefs/launcher_prefs.dart';
import '../../engine/desklet_spec.dart';
import '../../engine/effective_theme.dart';
// `ShellKind` for the pane test below. `effective_theme` re-exports nothing, so
// the enum has to come from where it is declared, which is the same place
// `desklet_skin` takes it from.
import '../../engine/theme_spec.dart' show ShellKind;
import 'desklet_surface.dart' show buildDesklet;

class DeskletPreview extends StatelessWidget {
  const DeskletPreview({
    super.key,
    required this.theme,
    required this.kind,
    this.height = 104,
  });

  final EffectiveTheme theme;
  final DeskletKind kind;

  /// The swatch height. The picker uses its default; setup passes something
  /// smaller because it shows two columns inside an installer window rather
  /// than two across a full screen.
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;

    // The skin is resolved per SHELL and per kind, so the same clock is a GNOME
    // card on Ubuntu and a bare mono block on the terminal. Reading it here
    // rather than taking it as a parameter is what makes this widget correct on
    // any distro without the caller knowing the rule.
    final skin = theme.spec.desklets.skinFor(theme.shell, kind.id);

    final preview = buildDesklet(
      theme,
      Desklet(
        id: 'preview_${kind.id}',
        kind: kind.id,
        page: 0,
        col: 0,
        row: 0,
        spanX: kind.defaultSpanX,
        spanY: kind.defaultSpanY,
      ),
      skin,
    );

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // The distro's own dark base, so a `bare` desklet (text straight onto
        // the wallpaper, which is what Ubuntu's conky skin asks for) stays
        // readable with no wallpaper behind it.
        color: p.bgBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: preview ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The kinds a distro offers that can actually be drawn on [theme]'s surface.
///
/// ─── ONE ANSWER, THREE READERS ──────────────────────────────────────────────
///
/// The picker, setup's widgets step, and the sweep in setup that overrules the
/// authored starter all need the same list, and two of them had their own copy.
/// Setup's was a hardcoded seven-id `shortlist`, which is how it came to offer
/// `df`, `free` and `uptime` on a GNOME desktop: all three are [paneOnly], the
/// widgets step never runs on the terminal, and `DeskletLayout.renderable`
/// drops them from a grid. Ticking one wrote a desklet that could never draw,
/// silently, with the tick still showing.
///
/// ─── AND THE OFFERS COME FROM THE DISTRO ────────────────────────────────────
///
/// `theme.json` authors them, so a CDN distro decides what its own picker shows
/// with no edit here. [fallback] is the shipping set, for a theme that predates
/// the block: an empty `offers` means "has not authored a list", never "offer
/// nothing".
List<DeskletKind> offeredDesklets(EffectiveTheme theme) {
  const fallback = [
    'glance',
    'clock',
    'monitor',
    'fastfetch',
    'network',
    'storage',
    'battery',
    'notes',
    'search',
  ];

  final pane = theme.shell == ShellKind.tui;
  return [
    for (final k in DeskletKinds.resolveOffers(
      theme.spec.desklets.offersOr(fallback),
    ))
      // `df -h` on a GNOME desktop would be a file manager, not a desklet. The
      // terminal's pane surface relaxes this, which is where those kinds are
      // added by TYPING rather than by a picker anyway.
      if (!k.paneOnly || pane) k,
  ];
}
