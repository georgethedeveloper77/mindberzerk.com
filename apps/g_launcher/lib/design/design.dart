/// `design` — LIFTABLE. Becomes `packages/g_design/` when G Recovery starts.
///
/// Same rule as `core/`: **no launcher-specific imports.**
///
/// ## The distinction that matters most in this folder
///
/// This is the **house design system**: Settings, the Themes gallery, dialogs,
/// bottom sheets, the wallpaper picker, paywalls. Everything the launcher owns
/// that is not a desktop shell.
///
/// It is NOT how the desktop is skinned. Desktop skinning is
/// `engine/ThemeSpec`, which is **data**, not code.
///
/// Keep the two apart or the theme engine ends up hardcoded into widgets, and
/// the "a new distro is minimal JSON, no code" promise quietly stops being
/// true.
///
/// ## Chrome: how a six-colour palette themes a settings screen
///
/// A `ThemePalette` carries six colours (`bgTop`, `bgBottom`, `bar`, `dock`,
/// `accent`, `onDark`) and they describe the **desktop**, not a form. So the
/// chrome layer DERIVES a full chrome colour set from those six, in
/// `components/chrome_theme.dart` → `ChromeColors.fromPalette`. A theme author
/// never writes `surface` or `textMuted`; they fall out of the palette the
/// theme already ships.
///
/// That derivation is what lets a new distro be a six-colour palette and get a
/// themed Settings screen for free.
///
/// ### Flow of truth
///
/// ```
/// EffectiveTheme                (engine — the single source of truth)
///   └─ ThemedScaffold           (the ONE Riverpod bridge)
///        └─ ChromeScope         (InheritedWidget carrying ChromeData)
///             └─ ThemedListRow, ThemedToggle, …  (read ChromeScope.of)
/// ```
///
/// Primitives never touch `EffectiveTheme`, Riverpod, or the house tokens.
/// They read one inherited object. Only `ThemedScaffold` bridges the async
/// provider to the sync scope.
///
/// ### Rules baked into the primitives
///
///  - **House tokens are the floor, never the target.** `ChromeData.bootstrap`
///    (house `GColors`/`GType`) shows only while `effectiveThemeProvider` is
///    resolving or has errored. It is the sole sanctioned reader of `GColors`
///    in chrome, and `scripts/no_constants.sh` enforces that.
///  - **Semantic statuses are theme-independent.** `ok`/`warn`/`danger` do not
///    come from the palette; destructive must read the same red under every
///    distro. They are the only non-derived colours, by design.
///  - **Modals re-provide the scope.** `showModalBottomSheet` and `showDialog`
///    push a route OUTSIDE the screen's `ChromeScope`, so `ThemedSheet.show`
///    and `ThemedDialog.show` capture the chrome before pushing and re-wrap
///    the content. Any new modal must do the same or it renders in house
///    colours — and it will look almost right, which is worse.
///  - **Absent data is an absent line.** `ThemedListRow.subtitle` is nullable
///    and renders single-line when null. Never a `--` placeholder.
///
/// (This doc replaces `design/README.md` and `design/components/README.md`.
/// The "Not here yet" section of the latter described `chromeFamily` and
/// per-family radii as future work; both shipped in Phase B, which is a good
/// illustration of why this content belongs in source.)
library;

export 'components/components.dart';
export 'grid_metrics.dart';
export 'icon_sizing.dart';
export 'theme.dart';
