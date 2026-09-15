/// The numbers a panel is drawn with, in one place.
///
/// ─── WHY THESE LEFT plasma_shell ───────────────────────────────────────────
///
/// They were private constants in the KDE shell, which was correct while KDE
/// was the only shell with a panel. It is not: Mint, MATE and Xfce all resolve
/// to a panel through the same spec, GNOME and Aqua draw bars from the same
/// module vocabulary, and a default thickness that lives inside one shell is a
/// default the other four cannot read.
///
/// Nothing here is per distro. A pack that wants a different thickness authors
/// `height` on its panel, and a user who wants one sets it in edit mode; both
/// arrive already merged on `EffectiveTheme`. These are the floor for a panel
/// that has neither.
library;

/// Breeze's panel thickness in dp, used when neither the theme nor the user has
/// set one. Was a literal `48` inside a SizedBox.
const double defaultPanelHeight = 48;

/// ─── THE STEPPER'S RANGE ───────────────────────────────────────────────────
///
/// 36 is the floor because a 30dp app icon plus its padding is what the task
/// strip draws, and below that the strip clips rather than shrinks. 72 is the
/// ceiling because a panel taller than that is a dock, and the app already has
/// one of those with its own capacity rules.
const double minPanelHeight = 36;
const double maxPanelHeight = 72;

/// Four, not one. A stepper that moves a panel by a pixel at a time takes nine
/// taps to cross a difference anybody can see.
const double panelHeightStep = 4;

/// The gap at the trailing end of the strip, so the last module does not sit
/// against the screen edge. Turns with the panel: on a vertical strip a WIDTH
/// of 12 would do nothing at all and the clock would touch the bottom.
const double panelTrailingGutter = 12;

/// How solid a panel is before the user's bar-opacity setting scales it.
///
/// SCALED, never replaced. A Breeze panel is very nearly solid on purpose, and
/// multiplying keeps that relationship at every slider position rather than
/// flattening every distro to the same value at the top of the range.
const double panelBaseOpacity = 0.96;
