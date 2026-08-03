/// Dock geometry, as pure functions. No Flutter imports — testable at every
/// screen size without a device, including the very tall budget phones this app
/// is actually for, which is where naive capacity math breaks.
library;

/// Where the dock lives. Parses `LauncherPrefs.dockSide`.
///
/// ─── THIS IS THE SECOND DockSide IN THE APP, AND THAT IS A KNOWN DEBT ───────
///
/// `theme_spec.dart` declares one too. They are the same four values with the
/// same meanings and two separate parsers, which is why `terminal_matches.dart`
/// carries a comment about `show ThemePalette` being mandatory: importing both
/// files unrestricted is an ambiguous-import error that reads as if neither
/// declaration exists.
///
/// Adding `right` had to be done in both, in step, and that is the argument for
/// collapsing them rather than a reason to keep going. Doing it is a rename
/// across every shell and dock file, so it is its own pass. Until then: EDIT
/// THESE TWO TOGETHER. A `right` here without a `right` there is a dock the
/// settings screen can select and the shell cannot render.
enum DockSide {
  left,
  bottom,
  off,
  right;

  static DockSide parse(String? raw) => switch (raw) {
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        'right' => DockSide.right,
        _ => DockSide.left, // Ubuntu default
      };

  /// Both edges that run down the screen.
  ///
  /// Was `this == DockSide.left`, which was correct while left was the only
  /// vertical side and is the exact shape of every site `right` broke: the
  /// question being asked is about the AXIS, and the answer happened to have
  /// one member.
  bool get isVertical => this == DockSide.left || this == DockSide.right;
}

/// Where the Activities grid button sits within the dock.
/// Parses `LauncherPrefs.dockGridButton`.
///
/// Ubuntu puts it at the far end (bottom of a left dock). Some people want it
/// first — it is the most-tapped thing in the dock, and the far end of a tall
/// dock is a stretch on a big phone. 'off' removes it entirely; the drawer is
/// still reachable by gesture (swipe right) so hiding it orphans nothing.
enum GridButtonPosition {
  start,
  end,
  off;

  static GridButtonPosition parse(String? raw) => switch (raw) {
        'start' => GridButtonPosition.start,
        'off' => GridButtonPosition.off,
        _ => GridButtonPosition.end, // Ubuntu default
      };
}

/// Dock sizing + capacity.
///
/// **The dock is fit-to-run: icons start LARGE and shrink toward a floor as the
/// dock fills, and it never overflows.** That replaces the old fixed 52px slot,
/// which made a 3-app dock look thin and a 9-app dock clip. Slot size is no
/// longer a constant — it's [slotFor], computed per render from the app count
/// and the dock's actual length. Everything downstream (the glyph, the
/// running-bar centring) derives from that one number.
///
/// **A vertical dock holds roughly twice what a horizontal one does, and that is
/// not a detail.** A phone is ~2.2× taller than it is wide, so a left dock fits
/// far more than a bottom one. Capacity is therefore computed from the dock's
/// real run — and a bottom dock is additionally hard-capped, because a long row
/// of tiny icons sharing space with the gesture pill looks wrong no matter how
/// many technically fit.
abstract final class DockMetrics {
  static const gap = 9.0;
  static const padding = 9.0;

  /// Slot-size range. [maxSlot] is the out-of-box "few big apps" size; [minSlot]
  /// the floor below which taps get fiddly on a budget screen. The old fixed 52
  /// sat between these — now it's the span the dock moves through.
  static const minSlot = 46.0;
  static const maxSlot = 64.0;

  /// App icons nearly fill their slot. An adaptive icon already carries its own
  /// tile and padding, so the mockup's ~0.6 ratio — which was meant for a bare
  /// glyph on a plate — left real app icons looking tiny and lost in the slot.
  /// Apps get most of the cell; the grid button, which IS a bare glyph on a
  /// plate, keeps the smaller ratio.
  static const appGlyphRatio = 0.86;
  static const gridGlyphRatio = 0.52;

  /// The running-app indicator's long dimension. Fixed — it's a status mark, not
  /// something that scales with the icon. Its OFFSET is computed from the slot.
  static const runningBar = 18.0;

  /// The hairline separator before the grid button, plus its gap.
  static const separator = 1.0 + gap;

  /// The out-of-box dock: four apps, auto-filled from frequency. Also where the
  /// count-taper starts biting — apps past this pull the slot size down.
  static const defaultCount = 4;

  /// Below this it stops being a dock.
  static const minCapacity = 3;

  /// Above this it's a scrolling list, and a dock you scroll has lost the point.
  static const maxCapacity = 12;

  /// A bottom (horizontal) dock is short, shares its run with the gesture pill,
  /// and looks wrong stuffed full. Hard-capped on top of the fit math.
  static const maxBottomApps = 6;

  /// How much each app beyond [defaultCount] pulls the slot down, so the shrink
  /// is visible even on a tall left dock that could fit them all at [maxSlot].
  static const _shrinkPerApp = 4.0;

  /// An app icon's size inside a [slot]-sized cell — nearly filling it.
  static double appGlyphFor(double slot) => slot * appGlyphRatio;

  /// The Activities grid glyph: a bare glyph on a plate, so distinctly smaller.
  static double gridGlyphFor(double slot) => slot * gridGlyphRatio;

  /// The slot size for [count] apps in a dock of usable length [available]
  /// (insets already subtracted). Whichever force is smaller wins:
  ///
  ///   • **fit-to-run** — the largest slot at which every app, plus the grid
  ///     button, fits [available]. This is what stops a full dock overflowing.
  ///   • **count taper** — [maxSlot] minus a step per app past [defaultCount],
  ///     so the dock visibly shrinks as you pin more even with room to spare.
  ///
  /// Clamped to [minSlot]..[maxSlot]. A 4-app dock lands at [maxSlot]; a bottom
  /// dock on a narrow phone bottoms out near [minSlot].
  static double slotFor({
    required int count,
    required double available,
    required bool hasGridButton,
  }) {
    final slots = count + (hasGridButton ? 1 : 0);

    final fit = slots <= 0
        ? maxSlot
        : (available -
                padding * 2 -
                (hasGridButton ? separator : 0.0) -
                (slots - 1) * gap) /
            slots;

    final taper =
        maxSlot - (count - defaultCount).clamp(0, 1000) * _shrinkPerApp;

    final slot = fit < taper ? fit : taper;
    return slot.clamp(minSlot, maxSlot);
  }

  /// The most apps the dock will hold. Measured at [minSlot] — the smallest the
  /// fit-to-run shrink can reach, hence the true ceiling. A bottom dock is
  /// additionally capped at [maxBottomApps].
  static int capacityFor({
    required double available,
    required bool hasGridButton,
    // Optional: bottom docks are capped at [maxBottomApps]. Defaults to the
    // uncapped (non-bottom) case so callers that don't care — and the unit
    // tests, which predate this cap — need not pass it. The shell always passes
    // it explicitly.
    bool isBottom = false,
  }) {
    // The grid button and its separator take room but are not app slots. At the
    // smallest slot size, the most apps fit.
    final reserved =
        padding * 2 + (hasGridButton ? minSlot + gap + separator : 0.0);
    final usable = available - reserved;

    // n slots need n*minSlot + (n-1)*gap  →  n = (usable + gap) / (minSlot + gap)
    final fits = ((usable + gap) / (minSlot + gap)).floor();
    var cap = fits.clamp(minCapacity, maxCapacity);
    if (isBottom && cap > maxBottomApps) cap = maxBottomApps;
    return cap;
  }
}
