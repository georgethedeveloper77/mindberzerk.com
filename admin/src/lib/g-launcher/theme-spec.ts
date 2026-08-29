/**
 * The theme SHAPE, pure and client-safe.
 *
 * This is the single source of truth for what a theme.json is, how it serializes
 * to the exact bytes a pack signs, and what makes a draft valid. It has no
 * 'server-only' marker and no R2/crypto imports on purpose: the builder form
 * runs it in the browser to preview and validate live, and `themes.ts` runs the
 * same functions on the server to store and (at publish) sign. Two copies of the
 * serializer would sign different bytes than the builder shows; one copy cannot.
 *
 * Every field here mirrors ThemeSpec.fromJson in the app. `palette` is the only
 * required block (fromJson throws without it); everything else has a Dart-side
 * default and is omitted from the payload when unset.
 */
import { isKnownFamily, isMonospaceFamily } from './font-catalogue';

export type ShellName = 'gnome' | 'plasma' | 'tiling' | 'tui' | 'aqua';
/**
 * The design language the launcher's OWN surfaces wear.
 *
 * `xfce` is the fifth and it is the one Kali needs. Five distros fell into
 * `generic` (Kali, Manjaro, Arch, EndeavourOS, Terminal), which is the fallback
 * rather than a design language anyone ships, so the five most distinct
 * desktops in the catalogue had the identical menu and the identical settings
 * page. Xfce's menus are dense lists WITH icons and no separators, and its
 * Settings is a grid of icons rather than a list of rows.
 */
export type ChromeName =
  | 'adwaita'
  | 'breeze'
  | 'xfce'
  // A tiling window manager: text-only menus, nothing rounded, no rules. Splits
  // Arch and EndeavourOS off from Kali and Manjaro, who took `xfce`.
  | 'wm'
  | 'aqua'
  // A phone's home screen: the icon lifts, the rest dims, a rounded card opens
  // beneath it. Named for the product, not the device.
  | 'pocket'
  | 'generic';
export type TierName = 'free' | 'pro';
/**
 * Which edge the dock lives on.
 *
 * `right` was MISSING here while `DockSide` on the device has had it for some
 * time and `ThemeLayout.fromJson` parses it. The panel's vocabulary is what a
 * distro can say, so a value the device understands and this list does not is a
 * value no published distro can use: the builder never offered it and an
 * imported theme.json naming it fell through the guard to `left`.
 */
export type DockName = 'left' | 'bottom' | 'off' | 'right';

export const SHELLS: ShellName[] = ['gnome', 'plasma', 'tiling', 'tui', 'aqua'];
export const CHROMES: ChromeName[] = [
  'adwaita',
  'breeze',
  'xfce',
  'wm',
  'aqua',
  'pocket',
  'generic',
];
export const DOCKS: DockName[] = ['left', 'bottom', 'off', 'right'];

/** The IconStyle fields the app reads. Kept loose where item 3 will add a form. */
/**
 * Every treatment the DEVICE recognises, in the order the picker should offer.
 *
 * ─── THIS LIST WAS WRONG, IN BOTH DIRECTIONS ────────────────────────────────
 *
 * It read `['roundedSquare', 'squircle', 'circle', 'none']`. Dart's `_treatment`
 * accepts `circle, squircle, square, teardrop, original, roundedSquare` and has
 * no `none`.
 *
 * So the builder offered a value that does not exist, which the parser silently
 * degraded to roundedSquare: you picked "none", the JSON said "none", the panel
 * agreed, and the phone drew rounded squares. And it hid three treatments that
 * do exist, so `square`, `teardrop` and `original` were unreachable from the UI
 * and could only be set by hand-editing a theme.json.
 *
 * `original` is worth having in the picker on its own: it is the only way to
 * say "leave the app's own icon shape alone", which is what a distro shipping a
 * complete hero pack wants.
 *
 * SOURCE OF TRUTH: `_treatment` in `lib/engine/theme_spec.dart`. `theme-resolve`
 * imports this rather than keeping a second copy, so the reader and the writer
 * cannot disagree about what is offerable.
 */
export const ICON_TREATMENTS = [
  'roundedSquare',
  'squircle',
  'circle',
  'square',
  'teardrop',
  'original',
] as const;
export type IconTreatment = (typeof ICON_TREATMENTS)[number];

export interface ThemePaletteJson {
  bgTop: string;
  bgBottom: string;
  bar: string;
  dock: string;
  accent: string;
  onDark: string;
}

export interface ThemeTypographyJson {
  display?: string | null;
  mono?: string | null;
}

/** Which edge the shell bar sits on. All four are offered now that the shell
 *  lays out along either axis. A vertical bar shrinks the workspace rather than
 *  overlapping the dock, because the dock is positioned inside the workspace
 *  rather than the shell. */
export const TOP_BAR_SIDES = ['top', 'bottom', 'left', 'right'] as const;
export type TopBarSideName = (typeof TOP_BAR_SIDES)[number];

export interface ThemeFontJson {
  family: string;
  /** BARE filenames. Pack assets are flat: `PackPaths.installedFile` refuses a
   *  separator, so a path here downloads and then fails to open. */
  files: string[];
}

/** What a panel can carry. Mirrors PanelModule on the device, and the omissions
 *  are the point: no clock and no battery, because Android's own status bar
 *  shows both a few pixels away and duplicating them is the opposite of
 *  authentic. */
/**
 * What a panel can carry.
 *
 * ─── FIVE HERE AND TEN ON THE DEVICE, WHICH IS FOUR SILENTLY DROPPED ────────
 *
 * `PanelModule.parse` in theme_spec.dart accepts kickoff, tasks, pager, tray
 * and clock as well, and has for as long as panels have existed. This list did
 * not, and the importer filters `modules` against it, so a theme.json naming a
 * pager or a clock had both stripped on the way in and republished without
 * them. The distro then drew a bar the author never wrote and no error said so.
 *
 * That is the `drawerGrouping: "library"` failure exactly, and it is why the
 * import guard is called out everywhere in this file: a vocabulary the panel
 * does not know is a value no distro can keep.
 *
 * Ordered to match the device's own switch, so the two can be read side by side.
 */
export const PANEL_MODULES = [
  'activities',
  'network',
  'memory',
  'storage',
  'spacer',
  'kickoff',
  'tasks',
  'pager',
  'tray',
  'clock',
] as const;
export type PanelModuleName = (typeof PANEL_MODULES)[number];

export interface PanelJson {
  side: TopBarSideName;
  /** In order, leading edge first. A `spacer` splits the run. */
  modules: PanelModuleName[];
  /** Thickness in dp. Omit for the shell's own default. */
  height?: number;
}

export const WORKSPACE_AXES = ['vertical', 'horizontal'] as const;

/**
 * The drawer's motion and grouping, as a distro may DEFAULT them.
 *
 * A default, never an override. The device consults these only for a user who
 * has never touched the setting, because both were promoted to global prefs
 * and a promoted value is a deliberate choice the distro is not allowed to
 * overrule. See `ThemeLayout.drawerScrollStyle` on the device for the rule and
 * the marker that enforces it.
 *
 * `pages` is the engine default when neither the user nor the distro has an
 * opinion, which is why 'inherit' below emits nothing at all rather than
 * emitting 'pages'.
 */
export const DRAWER_SCROLLS = ['vertical', 'pages', 'cube'] as const;
export type DrawerScrollName = (typeof DRAWER_SCROLLS)[number];

/**
 * How the drawer groups apps.
 *
 * ─── 'library' IS NEW AND ITS ABSENCE WAS SILENT ────────────────────────────
 *
 * The import guard below tests membership in this list and drops anything that
 * fails, which is the right behaviour for a spec written by a newer build. It
 * also means that until this array knew the word, importing a theme.json with
 * `drawerGrouping: "library"` published a pack with the key MISSING, while
 * `drawerScrollStyle: "vertical"` on the adjacent line came through fine
 * because 'vertical' was already in DRAWER_SCROLLS.
 *
 * One key present, its neighbour gone, no error and no warning. The device then
 * fell back to the engine default and the whole feature looked unbuilt.
 *
 * Adding a value here is therefore not cosmetic: this list is the panel's whole
 * vocabulary, and a value the panel cannot say is a value no distro can ship.
 */
export const DRAWER_GROUPINGS = ['none', 'az', 'library'] as const;
export type DrawerGroupingName = (typeof DRAWER_GROUPINGS)[number];
export type WorkspaceAxisName = (typeof WORKSPACE_AXES)[number];

/**
 * What the Plasma menu's left rail is made of.
 *
 * Shipped on the device and absent here, which is the exact failure the
 * DRAWER_GROUPINGS note above describes, one field later. `KickoffDrawer` reads
 * a resolved 'tabs' | 'categories' and every plasma distro has been getting
 * 'tabs' because no panel build could write the key.
 *
 * It is the field Linux Mint needs: Cinnamon's menu is a category column, and
 * without it Mint is a green KDE.
 */
export const KICKOFF_RAILS = ['tabs', 'categories'] as const;
export type KickoffRailName = (typeof KICKOFF_RAILS)[number];

/**
 * WHERE the app list lives.
 *
 *  - `overlay`: appears over the desktop and is dismissed. Every distro today.
 *  - `workspace`: the app list IS a page of the desktop, one swipe past the
 *    last workspace, with the dock unchanged underneath. Deepin's fashion mode.
 *
 * Absent means overlay, so this is emitted only for `workspace`, the same way
 * `workspaceAxis` is emitted only for `horizontal`.
 *
 * The device CLAMPS this per shell: GNOME inlines its own pager and TUI has no
 * workspaces, so both resolve to overlay whatever a theme.json says. The panel
 * does not re-implement that clamp, deliberately, because two copies of a rule
 * drift and the device's is the one that decides what renders.
 */
export const APPS_SURFACES = ['overlay', 'workspace'] as const;
export type AppsSurfaceName = (typeof APPS_SURFACES)[number];

/**
 * Which launcher a TILING distro opens.
 *
 *  - `rofi`: a centred card with an accent border, icons and a ranked list.
 *    The default, and what every tiling distro drew before the field existed.
 *  - `dmenu`: one line across the top edge, matches running sideways, no icons,
 *    no card, no scrim.
 *
 * Read only by `TilingLauncher`, so authoring it on a plasma distro writes a
 * key nothing consumes. It is named for its widget rather than clamped for
 * exactly that reason, the same choice `kickoffRail` makes.
 */
export const TILING_LAUNCHERS = ['rofi', 'dmenu'] as const;
export type TilingLauncherName = (typeof TILING_LAUNCHERS)[number];

/**
 * Which drawer widget a distro opens, overriding its shell's own.
 *
 *  - `grid`: whatever the shell would have chosen. Every distro today.
 *  - `tools`: the numbered category menu, with every one of the distro's
 *    `categories` present in the rail whether or not it holds anything.
 *  - `card`: Slingshot. A card that drops from the Applications button and
 *    covers about half the screen. The only drawer that does not take the
 *    display. Pair it with `drawerGrouping: "library"` to open on categories.
 *  - `whisker`: Xfce's menu. A narrow column on the bottom-left corner with a
 *    category strip along its foot. Read by any shell; it anchors itself.
 *  - `cinnamon`: Mint's menu. Three columns side by side, favourites,
 *    categories and apps, with search across the foot.
 *  - `zorin`: the Start menu's shape. A pinned grid above a rule, everything
 *    else as a list below it, search over both. The only stacked one.
 *  - `query`: Pop's launcher. A line at the top with ranked results under it
 *    and nothing else. The only one that does not arrange apps at all.
 *  - `library`: the App Library, category bubbles. The same widget
 *    `drawerGrouping: "library"` reaches, but without a prefs arm, so a product
 *    selling it can carry it as an exclusive row.
 */
export const APP_DRAWERS = [
  'grid',
  'tools',
  'card',
  'whisker',
  'cinnamon',
  'zorin',
  'query',
  'library',
] as const;
export type AppDrawerName = (typeof APP_DRAWERS)[number];

/**
 * How the desktop arranges its icons.
 *
 *  - `grid`: evenly spaced cells with a gutter. Every distro with a desktop.
 *  - `tiled`: the slots fill the workspace edge to edge with no gap, each
 *    taking half of what is left and alternating the split axis. A tiling
 *    window manager's screen.
 *
 * A geometry, not a second surface: both render the same slots, so dragging,
 * folders and the long-press menu are identical. Capacity is still
 * `grid.rows * grid.cols`, and a tiled distro wants a SMALL one: the tiles
 * halve, so six is legible and twenty is a mosaic.
 */
export const HOME_LAYOUTS = ['grid', 'tiled'] as const;
export type HomeLayoutName = (typeof HOME_LAYOUTS)[number];

/**
 * How the dock sits. Read by the Aqua shell only.
 *
 *  - `flat`: on the bottom edge, square-topped, no swell. Plank.
 *  - `floating`: off the edge, fully rounded, translucent, no swell. Deepin.
 *  - `magnified`: floating AND swelling under the finger. The Mac.
 *
 * `magnified` is the device default, because it is what the aqua dock has
 * always drawn and a theme that says nothing must not move.
 */
export const DOCK_STYLES = ['flat', 'floating', 'magnified'] as const;
export type DockStyleName = (typeof DOCK_STYLES)[number];

/**
 * When the dock exists at all. Read by the GNOME shell.
 *
 *  - `always`: part of the desktop. Every distro today.
 *  - `apps`: only while the apps surface is open, which makes it a DASH.
 *    Upstream GNOME, and the one field that tells Fedora from Ubuntu.
 *
 * On `apps` the Dock position and Dock opacity rows grey out: there is no dock
 * on the desktop to position or fade.
 */
export const DOCK_REVEALS = ['always', 'apps'] as const;
export type DockRevealName = (typeof DOCK_REVEALS)[number];

export interface ThemeLayoutJson {
  dock: DockName;
  topBar: boolean;
  /** Absent means `top`, which is what every theme authored before this field
   *  existed gets, and what every GNOME-family desktop does anyway. */
  topBarSide?: TopBarSideName;
  /** Live readouts in the bar: throughput, memory, free space. Never a clock or
   *  a battery percentage, which Android's own status bar already shows.
   *
   *  SUPERSEDED BY `panels`. Kept because every theme authored before panels
   *  existed still uses it, and the device synthesises a panel from it when
   *  `panels` is absent. */
  topBarStats?: boolean;
  /** Every panel this distro draws. Supersedes `topBar`, `topBarSide` and
   *  `topBarStats` when present: the device stops synthesising and uses these
   *  verbatim. This is what lets Xfce ship a top bar AND a bottom one. */
  panels?: PanelJson[];
  /** Which way workspaces page. Absent means vertical, which is GNOME's answer
   *  and what the shell has always done. macOS Spaces are horizontal. */
  workspaceAxis?: WorkspaceAxisName;
  /** Where the app list lives. Absent means `overlay`. See [APPS_SURFACES]. */
  appsSurface?: AppsSurfaceName;
  /**
   * Does this distro's desktop carry an app grid?
   *
   * ─── A CAPABILITY THE PANEL COULD NOT SAY ─────────────────────────────────
   *
   * Absent from this interface until now, so every distro published through the
   * panel shipped `desktopIcons: false` whichever shell it named. KDE's Folder
   * View is Plasma's DEFAULT containment, so the one family whose desktop is
   * supposed to carry icons is the family that has never had them, and the app
   * long-press menu has been offering Uninstall in the glyph strip instead of
   * Add to home as a direct consequence.
   *
   * The device resolves this ONE WAY ONLY: the distro sets the ceiling and the
   * user may lower it. That is what makes it a real exclusive row rather than a
   * setting, so it is also one of the few honest answers to "what does this
   * paid distro do that the free one cannot".
   *
   * Off by default on the device, so emitted only when true.
   */
  desktopIcons?: boolean;
  /**
   * May the user rearrange this distro's panel?
   *
   * Same gap as `desktopIcons` and the same consequence: panel editing is what
   * Plasma is sold on, and Manjaro and Garuda are sold partly on inheriting it,
   * and no panel-published distro has ever been able to grant it.
   *
   * Theme-authored only on the device. Whether the user MAY edit the panel is
   * not itself something the user edits. Off by default, so emitted only when
   * true.
   */
  panelEdit?: boolean;
  grid?: { rows: number; cols: number };
  iconScale?: number;
  /** The distro's DEFAULT drawer motion and grouping. Absent means no opinion,
   *  which is not the same as 'pages': absent lets the engine decide, and the
   *  engine may change its mind in a later build. Honoured only where there is
   *  a paged grid to honour it, so Plasma's Kickoff and the tiling prompt
   *  ignore both, which needs no clamping here. */
  drawerScrollStyle?: DrawerScrollName;
  drawerGrouping?: DrawerGroupingName;
  /** What the Plasma menu's rail is made of. Absent means `tabs`. Read only by
   *  `KickoffDrawer`, so it means nothing on a non-plasma distro. */
  kickoffRail?: KickoffRailName;
  /** Which launcher a tiling distro opens. Absent means `rofi`. Read only by
   *  `TilingLauncher`. */
  tilingLauncher?: TilingLauncherName;
  /** Which drawer widget this distro opens. Absent means `grid`, the shell's
   *  own. See [APP_DRAWERS]. */
  appDrawer?: AppDrawerName;
  /** How the desktop arranges its icons. Absent means `grid`. Only meaningful
   *  where `desktopIcons` is true. See [HOME_LAYOUTS]. */
  homeLayout?: HomeLayoutName;
  /** How the dock sits. Absent means `magnified`. See [DOCK_STYLES]. */
  dockStyle?: DockStyleName;
  /** When the dock exists. Absent means `always`. See [DOCK_REVEALS]. */
  dockReveal?: DockRevealName;
  /**
   * How many workspaces a fresh install of this distro starts with, 1 to 5.
   *
   * A DEFAULT, not a ceiling: the Settings stepper is live and the user's
   * number wins. Absent means the engine's three.
   *
   * It matters most where `appsSurface` is `workspace`, because the app list
   * sits after the last desktop and every extra workspace is an empty swipe in
   * front of it.
   */
  workspaces?: number;
}

export interface IconStyleJson {
  treatment?: string;
  cornerRadius?: number;
  foregroundScale?: number;
  backgroundColor?: string | null;
  monochromeTint?: string | null;
  heroPack?: string | null;
  brandPack?: string | null;
  brandTreatment?: string | null;
  backgroundGradientEnd?: string | null;
  gradientAngle?: number | null;
}

export interface ThemeSpecJson {
  id: string;
  name: string;
  version: string;
  shell: ShellName;
  tier: TierName;
  chromeFamily?: ChromeName | null;
  palette: ThemePaletteJson;
  /**
   * The LIGHT variant, when the distro ships one.
   *
   * Optional and additive, mirroring `ThemeSpec.paletteLight` on the device:
   * `palette` stays the DARK variant and keeps its name, because renaming it
   * would break every theme.json already published to the CDN. A theme without
   * this block has no light mode and the device forces dark, which is why an
   * absent value must stay absent rather than being filled with a default.
   */
  paletteLight?: ThemePaletteJson | null;
  typography?: ThemeTypographyJson | null;
  layout: ThemeLayoutJson;
  /** This distro's own category vocabulary, in display order. Absent means the
   *  built-in set. See [ThemeCategoryJson]. */
  categories?: ThemeCategoryJson[];
  /** Where an app lands when nothing in `categories` claims it. Absent means
   *  'Other'. Kali names it 'Usual Applications'. */
  categoryFallback?: string;
  icons?: IconStyleJson | null;
  logo?: unknown;
  wallpapers: string[];
  /** How each wallpaper meets the screen, keyed by its entry in `wallpapers`.
   *
   *  A SIDECAR MAP rather than richer `wallpapers` entries, because that array
   *  is a published wire format: every pack in the bucket holds an array of
   *  strings, and the device already carries a legacy branch for the older
   *  single `wallpaper.asset` shape. The string is also an identity on the
   *  device, where prefs store it and the rotation worker keys off it.
   *
   *  The USER always wins over this. It is a starting point, applied until
   *  somebody frames that wallpaper themselves, and it exists because the
   *  author knows where the subject is and the app does not. */
  wallpaperMeta?: Record<string, WallpaperMetaJson>;
  /** Font families the pack ships. A family named in `typography` only resolves
   *  if it is declared in pubspec, which a downloaded pack cannot do, so it
   *  carries its own files and they are registered at runtime. */
  fonts?: ThemeFontJson[];
  minAppVersion: number;
  boot?: unknown;
  splash?: unknown;
  desklets?: unknown;
  /**
   * The distro's DEFAULT gesture bindings: gesture id to a GestureAction id, or
   * "app:<componentKey>".
   *
   * ─── A DISTRO NEVER REBINDS A GESTURE THE USER SET ─────────────────────────
   *
   * These apply only to gestures the user has never bound. Several actions ride
   * an accessibility service the user granted for a specific purpose, so a
   * distro quietly rebinding one is not the same class of choice as a distro
   * picking a dock side. The device enforces it in `resolveGestureBinding`; the
   * panel's job is only to avoid implying more than that.
   *
   * An id this build does not recognise is carried through rather than dropped:
   * the catalogue outlives any one panel build, and the device screens theme
   * defaults it cannot decode by falling back to its own.
   */
  gestures?: Record<string, string>;
  /**
   * The rows the storefront card names, in AUTHORED ORDER.
   *
   * ─── IN theme.json, NOT BESIDE IT ─────────────────────────────────────────
   *
   * `title` and `summary` are ThemeDraft fields, kept panel-side, and elementary
   * once shipped with Kali's summary because of it. A feature row is a claim
   * about what the theme DOES, so it travels with the theme and cannot end up
   * describing a different one.
   *
   * NEVER SORTED. The card shows the first two `exclusive` rows, so the order
   * they are written in is the order they sell in.
   */
  features?: ThemeFeatureJson[];
  /** Editor hint only, never emitted to the payload. */
  seededFromPreview?: boolean;
}

/**
 * Every key a theme.json may carry, and the ONLY list the importer checks.
 *
 * ─── IT WAS A LOCAL SET INSIDE THE IMPORTER, AND IT WAS WRONG ───────────────
 *
 * That copy omitted `paletteLight` and `fonts`, so importing a theme with a
 * light palette reported "Ignored 1 key(s) nothing reads: paletteLight" while
 * the importer was, in the same pass, parsing it correctly and the device was
 * rendering light mode from it. The note is designed to be believed, and the
 * advice attached to it is not to publish until the notes are clear, so a
 * false positive here costs an author a real light palette.
 *
 * Up here beside [ThemeSpecJson] because that is the only place someone adding
 * a field will be looking. TypeScript cannot enumerate an interface at runtime,
 * so this cannot be derived; the next best thing is putting it where the
 * omission is obvious.
 *
 * `wallpaper` is the pre-list legacy key, read by `importTheme` and by the
 * device's own resolver. `seededFromPreview` is never emitted, but a draft
 * pasted back in should not be scolded for carrying it.
 */
/**
 * The four ways a wallpaper can meet the screen, as the device understands
 * them.
 *
 * A STRING UNION, not an enum, matching the Pigeon boundary this feeds: an
 * unrecognised value from a newer build degrades natively rather than failing
 * to parse.
 */
export const WALLPAPER_FITS = ['cover', 'contain', 'fill', 'center'] as const;
export type WallpaperFit = (typeof WALLPAPER_FITS)[number];

/**
 * Framing for ONE wallpaper.
 *
 * ─── THE UNITS ARE FRACTIONS OF THE SOURCE, NOT PIXELS ───────────────────────
 *
 * `focalX` and `focalY` run 0 to 1 across the image the author uploaded. Pixels
 * would break the moment the device picks a different sample size for the
 * decode, which it does on every different screen; screen coordinates would
 * break on every device that is not the one the author was looking at. A
 * fraction survives both, and it is the only form somebody can write here
 * without knowing what phone it lands on.
 *
 * Every field is optional and an absent block means centred at the app default,
 * which is what every pack published before this existed already does.
 */
export interface WallpaperMetaJson {
  fit?: WallpaperFit;
  focalX?: number;
  focalY?: number;
  zoom?: number;
}

/**
 * Drop a framing block that says nothing, and clamp one that says too much.
 *
 * Returning null for a default-valued block is what keeps `wallpaperMeta` from
 * accumulating a row per wallpaper the author merely looked at. An absent key
 * and a key holding all defaults mean the same thing on the device, and only
 * one of them costs bytes in every pack every phone downloads.
 *
 * The clamps are here as well as on the device because this is where a hand
 * edited theme.json enters the pipeline, and a zoom below 1 asks for a region
 * larger than the image: the device turns that into a degenerate crop rect and
 * quietly ignores it, which looks like the framing simply not applying.
 */
export function canonWallpaperMeta(m: WallpaperMetaJson): WallpaperMetaJson | null {
  const clamp = (v: number | undefined, lo: number, hi: number, fallback: number) =>
    typeof v === 'number' && Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : fallback;

  const fit = m.fit && WALLPAPER_FITS.includes(m.fit) ? m.fit : undefined;
  const focalX = clamp(m.focalX, 0, 1, 0.5);
  const focalY = clamp(m.focalY, 0, 1, 0.5);
  const zoom = clamp(m.zoom, 1, 4, 1);

  const out: WallpaperMetaJson = {};
  if (fit) out.fit = fit;
  if (focalX !== 0.5) out.focalX = round3(focalX);
  if (focalY !== 0.5) out.focalY = round3(focalY);
  if (zoom !== 1) out.zoom = round3(zoom);
  return Object.keys(out).length ? out : null;
}

/**
 * Three decimals, which is finer than any phone can resolve on a drag and short
 * enough that a published theme.json stays readable. Without it a focal point
 * set by dragging serialises as 0.4183673469387755 and every diff of the file
 * is unreadable noise.
 */
function round3(v: number): number {
  return Math.round(v * 1000) / 1000;
}

export const THEME_SPEC_KEYS: ReadonlySet<string> = new Set([
  'id', 'name', 'version', 'shell', 'tier', 'chromeFamily',
  'palette', 'paletteLight', 'typography', 'layout', 'icons', 'logo',
  'wallpapers', 'wallpaper', 'wallpaperMeta', 'fonts', 'minAppVersion',
  'boot', 'splash', 'desklets', 'gestures', 'features', 'seededFromPreview',
  'categories', 'categoryFallback',
]);

/**
 * One bucket in a distro's own category vocabulary.
 *
 * The distro supplies the NAME and the ORDER. It does not supply a filing rule:
 * the device still reads `ApplicationInfo.category`, which the app declares
 * about itself, and `feeds` only says which built-in bucket pours into which of
 * this distro's names. Kali's thirteen tool groups all have an empty `feeds`,
 * because no Android category honestly maps to "01 Information Gathering".
 */
export interface ThemeCategoryJson {
  name: string;
  /** Built-in bucket names: Social, Media, Productivity, Games, News, Travel,
   *  Utilities. Absent or empty means nothing arrives automatically. */
  feeds?: string[];
}

/** One row on a storefront card. See [ThemeSpecJson.features]. */
export interface ThemeFeatureJson {
  title: string;
  body: string;
  /**
   * Whether the all-access settings can reproduce this.
   *
   * REQUIRED. A missing answer reads as `true`, which is the flattering
   * direction, and this bool is the entire price argument: a paid distro whose
   * rows are all `false` is selling a palette.
   */
  exclusive: boolean;
}

export interface ThemeDraft {
  id: string;
  title: string;
  summary: string;
  sku: string | null;
  bundled: boolean;
  packVersion: number;
  spec: ThemeSpecJson;
  updatedAt: number;
}

// ── validators (pure copies, matching sign.ts and CdnIndex.kt) ───────────────

const PACK_ID = /^[a-z0-9._-]+$/;
const SKU = /^[a-z0-9][a-z0-9_]{0,63}$/;
const HEX = /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

export function isSafePackId(id: string): boolean {
  return !!id && id.length <= 64 && !id.startsWith('.') && PACK_ID.test(id);
}
export function isSafeSku(sku: string): boolean {
  return SKU.test(sku);
}
export function isHexColor(v: string): boolean {
  return HEX.test(v);
}

/**
 * WCAG relative luminance of a hex colour, 0 (black) to 1 (white).
 *
 * Mirrors Flutter's `Color.computeLuminance`, which is what
 * `ChromeColors.fromPalette` uses to decide whether a theme's chrome is dark.
 * Duplicated here rather than approximated, because the panel and the device
 * disagreeing about which side of 0.5 a colour falls on would mean a theme that
 * validates in the builder and renders unreadable on a phone.
 *
 * Accepts `#RRGGBB` and `#AARRGGBB`; the alpha byte is ignored, since ink is
 * composited opaque.
 */
export function luminance(hex: string): number {
  const s = hex.trim().replace(/^#/, '');
  const rgb = s.length === 8 ? s.slice(2) : s;
  const ch = (i: number) => {
    const c = parseInt(rgb.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * ch(0) + 0.7152 * ch(2) + 0.0722 * ch(4);
}

/** Normalize a hex string to `#RRGGBB` / `#AARRGGBB`, uppercased with a leading #. */
export function normalizeHex(v: string): string {
  const s = v.trim().replace(/^#/, '');
  return '#' + s.toUpperCase();
}

// ── the canonical serializer (byte-stable, order-fixed) ──────────────────────

/**
 * The exact bytes that become the theme.json payload inside a pack. Fixed key
 * order, two-space indent, parse-time defaults omitted so a generated file diffs
 * cleanly against a hand-authored one. Identical input always yields identical
 * bytes, which keeps the manifest sha256 stable across re-publishes.
 */
export function canonicalThemeJson(spec: ThemeSpecJson): string {
  const out: Record<string, unknown> = {};
  out.id = spec.id;
  out.name = spec.name;
  if (spec.version) out.version = spec.version;
  out.shell = spec.shell;
  out.tier = spec.tier;
  if (spec.chromeFamily) out.chromeFamily = spec.chromeFamily;

  out.palette = {
    bgTop: spec.palette.bgTop,
    bgBottom: spec.palette.bgBottom,
    bar: spec.palette.bar,
    dock: spec.palette.dock,
    accent: spec.palette.accent,
    onDark: spec.palette.onDark,
  };

  // Emitted ONLY when authored. An empty or partial light block would make the
  // device believe the distro has a light mode and then paint it with whatever
  // defaults happened to be in the editor.
  if (spec.paletteLight) {
    out.paletteLight = {
      bgTop: spec.paletteLight.bgTop,
      bgBottom: spec.paletteLight.bgBottom,
      bar: spec.paletteLight.bar,
      dock: spec.paletteLight.dock,
      accent: spec.paletteLight.accent,
      onDark: spec.paletteLight.onDark,
    };
  }

  if (spec.typography && (spec.typography.display || spec.typography.mono)) {
    const t: Record<string, string> = {};
    if (spec.typography.display) t.display = spec.typography.display;
    if (spec.typography.mono) t.mono = spec.typography.mono;
    out.typography = t;
  }

  out.layout = {
    dock: spec.layout.dock,
    topBar: spec.layout.topBar,
    // Emitted only when they differ from the device's own defaults, so a theme
    // that does not care about either stays as small as it was before the
    // fields existed. The device reads an absent key as top / off.
    ...(spec.layout.topBarSide && spec.layout.topBarSide !== 'top'
      ? { topBarSide: spec.layout.topBarSide }
      : {}),
    ...(spec.layout.topBarStats ? { topBarStats: true } : {}),
    // Emitted verbatim when authored. The device stops synthesising the moment
    // this key exists, so a half-written panels array would silently replace a
    // working legacy bar; the filter below drops panels with no modules rather
    // than shipping one.
    ...(spec.layout.panels?.length
      ? {
          panels: spec.layout.panels
            .filter((p) => p.modules.length)
            .map((p) => ({
              side: p.side,
              modules: [...p.modules],
              ...(p.height != null ? { height: p.height } : {}),
            })),
        }
      : {}),
    ...(spec.layout.workspaceAxis && spec.layout.workspaceAxis !== 'vertical'
      ? { workspaceAxis: spec.layout.workspaceAxis }
      : {}),
    // Overlay is the device default and what every distro does, so only the
    // interesting answer is written. Same shape as workspaceAxis directly
    // above, and for the same reason: a key that only ever restates the
    // default is a key that freezes this theme on today's default forever.
    ...(spec.layout.appsSurface && spec.layout.appsSurface !== 'overlay'
      ? { appsSurface: spec.layout.appsSurface }
      : {}),
    // Booleans that default to false on the device, emitted only when true.
    // Same treatment topBarStats gets a few lines up.
    ...(spec.layout.desktopIcons ? { desktopIcons: true } : {}),
    ...(spec.layout.panelEdit ? { panelEdit: true } : {}),
    ...(spec.layout.grid
      ? { grid: { rows: spec.layout.grid.rows, cols: spec.layout.grid.cols } }
      : {}),
    ...(spec.layout.iconScale != null ? { iconScale: spec.layout.iconScale } : {}),
    // Absent when the distro has no opinion. Emitting 'pages' to mean "the
    // default" would freeze this theme on today's default forever, which is
    // the opposite of what leaving the control on inherit says.
    ...(spec.layout.drawerScrollStyle
      ? { drawerScrollStyle: spec.layout.drawerScrollStyle }
      : {}),
    ...(spec.layout.drawerGrouping
      ? { drawerGrouping: spec.layout.drawerGrouping }
      : {}),
    ...(spec.layout.kickoffRail
      ? { kickoffRail: spec.layout.kickoffRail }
      : {}),
    ...(spec.layout.tilingLauncher
      ? { tilingLauncher: spec.layout.tilingLauncher }
      : {}),
    // 'grid' is the device default and emits nothing, the same rule every
    // other inherit-shaped control here follows.
    ...(spec.layout.appDrawer && spec.layout.appDrawer !== 'grid'
      ? { appDrawer: spec.layout.appDrawer }
      : {}),
    ...(spec.layout.homeLayout && spec.layout.homeLayout !== 'grid'
      ? { homeLayout: spec.layout.homeLayout }
      : {}),
    ...(spec.layout.dockStyle && spec.layout.dockStyle !== 'magnified'
      ? { dockStyle: spec.layout.dockStyle }
      : {}),
    ...(spec.layout.dockReveal && spec.layout.dockReveal !== 'always'
      ? { dockReveal: spec.layout.dockReveal }
      : {}),
    // Three is the engine default and emits nothing, the same rule every other
    // inherit-shaped value here follows.
    ...(spec.layout.workspaces && spec.layout.workspaces !== 3
      ? { workspaces: spec.layout.workspaces }
      : {}),
  };

  // Dropped when a category has no name, matching the device parser, which
  // skips them too: a rail slot nobody can read is worse than one fewer slot.
  if (spec.categories?.length) {
    const rows = spec.categories
      .filter((c) => c.name.trim())
      .map((c) => ({
        name: c.name.trim(),
        ...(c.feeds?.length ? { feeds: [...c.feeds] } : {}),
      }));
    if (rows.length) out.categories = rows;
  }
  if (spec.categoryFallback?.trim()) {
    out.categoryFallback = spec.categoryFallback.trim();
  }

  if (spec.icons && Object.keys(pruneIcons(spec.icons)).length) {
    out.icons = pruneIcons(spec.icons);
  }
  if (spec.fonts?.length) {
    out.fonts = spec.fonts
      .filter((f) => f.family.trim() && f.files.length)
      .map((f) => ({ family: f.family.trim(), files: [...f.files] }));
  }
  if (spec.logo != null) out.logo = spec.logo;
  if (spec.wallpapers && spec.wallpapers.length) out.wallpapers = spec.wallpapers;
  // Entries that say nothing are dropped, so a wallpaper the author opened and
  // left alone adds no bytes to every pack every device downloads, and a reset
  // genuinely removes the key rather than leaving a row of defaults behind it.
  if (spec.wallpaperMeta) {
    const meta: Record<string, WallpaperMetaJson> = {};
    for (const [name, m] of Object.entries(spec.wallpaperMeta)) {
      const trimmed = canonWallpaperMeta(m);
      if (trimmed) meta[name] = trimmed;
    }
    if (Object.keys(meta).length) out.wallpaperMeta = meta;
  }
  if (spec.minAppVersion) out.minAppVersion = spec.minAppVersion;
  if (spec.boot != null) out.boot = spec.boot;
  if (spec.splash != null) out.splash = spec.splash;
  if (spec.desklets != null) out.desklets = spec.desklets;

  // ORDER PRESERVED, unlike the gestures below. Rows are sorted nowhere in this
  // pipeline: the first two exclusive ones are what the card sells, so sorting
  // would take that decision away from whoever wrote them. Determinism still
  // holds, because an array's order is its own and does not depend on the
  // editor's insertion order the way an object's keys do.
  //
  // Rows with an empty title are dropped rather than published, matching the
  // native parser, which skips them too. A row with no title renders as a bare
  // sentence with a gap where the bold half should be.
  if (spec.features?.length) {
    const rows = spec.features
      .filter((f) => f.title.trim())
      .map((f) => ({
        title: f.title.trim(),
        body: f.body.trim(),
        exclusive: f.exclusive === true,
      }));
    if (rows.length) out.features = rows;
  }

  // Sorted and emitted only when non-empty, for the same reason the hero pack
  // sorts its icon keys: identical content has to sign to identical bytes, and
  // object key order in JS is insertion order, which the editor decides.
  const boundGestures = Object.entries(spec.gestures ?? {}).filter(
    ([k, v]) => k.trim() !== '' && typeof v === 'string' && v.trim() !== '',
  );
  if (boundGestures.length) {
    const g: Record<string, string> = {};
    for (const [k, v] of boundGestures.sort((a, b) => a[0].localeCompare(b[0]))) {
      g[k] = v;
    }
    out.gestures = g;
  }

  return JSON.stringify(out, null, 2) + '\n';
}

/** Drop empty-string / undefined icon fields so the block stays lean. Keeps
 *  explicit nulls (backgroundColor:null is meaningful to fromJson). */
function pruneIcons(icons: IconStyleJson): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(icons)) {
    if (v === undefined) continue;
    if (typeof v === 'string' && v.trim() === '') continue;
    out[k] = v;
  }
  return out;
}

// ── validation, surfacing exactly what the signer or device would reject ─────

export function validateDraft(draft: ThemeDraft): string[] {
  const p: string[] = [];
  const s = draft.spec;

  if (!isSafePackId(draft.id)) p.push(`Pack id '${draft.id}' must be lowercase letters, digits, . _ or -`);
  if (draft.id !== s.id) p.push('Pack id and spec id must match');
  if (!draft.title.trim()) p.push('Title is required');
  if (draft.sku != null && draft.sku !== '' && !isSafeSku(draft.sku)) {
    p.push(`SKU '${draft.sku}' must match a Play product id`);
  }
  if (!Number.isInteger(draft.packVersion) || draft.packVersion < 1) {
    p.push('Pack version must be a whole number of at least 1');
  }

  if (!s.name.trim()) p.push('Theme name is required');
  if (!SHELLS.includes(s.shell)) p.push(`Shell '${s.shell}' is not one of ${SHELLS.join(', ')}`);
  if (s.tier !== 'free' && s.tier !== 'pro') p.push(`Tier '${s.tier}' is not free or pro`);

  if (!s.palette) {
    p.push('Palette is required');
  } else {
    for (const [k, v] of Object.entries(s.palette)) {
      if (!isHexColor(v as string)) p.push(`Palette ${k} '${v}' is not a hex colour`);
    }
  }

  // A distro that publishes a bar position while its bar is off has almost
  // certainly toggled the bar and forgotten the rest. Refusing beats shipping a
  // theme.json whose layout block contradicts itself.
  if (!s.layout?.topBar && (s.layout?.topBarSide || s.layout?.topBarStats)) {
    p.push('Bar side and bar modules need the shell bar switched on');
  }

  const panels = s.layout?.panels ?? [];

  for (const panel of panels) {
    if (!panel.modules.length) {
      p.push(`A ${panel.side} panel has no modules`);
    }
    const spacers = panel.modules.filter((m) => m === 'spacer').length;
    if (spacers > 2) {
      // ─── TWO IS THE CENTRING PATTERN, NOT A MISTAKE ────────────────────
      //
      // This warned at more than ONE, on the reasoning that a middle group has
      // no edge to sit against and lands wherever the flex maths puts it. That
      // is not what happens. Two equal spacers are exactly how you centre a
      // run: `leading | spacer | centre | spacer | trailing` is waybar's own
      // modules-left / modules-center / modules-right, and it is the
      // arrangement EndeavourOS uses to put its workspaces in the middle
      // against Arch's left-aligned ones.
      //
      // The nuance the old comment was reaching for is real but small: the
      // centre group is centred in the LEFTOVER space, which is the screen
      // centre only when the two end groups happen to be the same width. Every
      // status bar on every desktop behaves that way, so warning about it would
      // be warning about flexbox.
      //
      // Three or more genuinely has no meaning: a fourth group has nowhere to
      // be, and whoever wrote it was reaching for padding.
      p.push(`The ${panel.side} panel has ${spacers} spacers, and more than two has no meaning`);
    }
    if (panel.height != null && (panel.height < 16 || panel.height > 96)) {
      p.push(`Panel height ${panel.height} is outside 16 to 96dp`);
    }
  }

  // Two panels on one edge stack, which is legal and is almost never what
  // someone meant. Not fatal: a distro could genuinely want a thin strip above
  // a thick one.
  for (const side of TOP_BAR_SIDES) {
    if (panels.filter((x) => x.side === side).length > 1) {
      p.push(`More than one panel on the ${side} edge; they will stack`);
    }
  }

  // The legacy trio is IGNORED once panels exist. Saying so beats an author
  // moving `topBarSide` and watching nothing happen on the phone.
  if (panels.length && (s.layout?.topBarSide || s.layout?.topBarStats)) {
    p.push(
      'Panels supersede topBarSide and topBarStats; those two will be ignored',
    );
  }

  for (const f of s.fonts ?? []) {
    if (!f.family.trim()) p.push('A font block has no family name');
    if (!f.files.length) p.push(`Font '${f.family}' lists no files`);
    for (const file of f.files) {
      // The flat-path rule, enforced where it is cheap to fix. On the device it
      // presents as text silently in the platform fallback and no error at all.
      if (file.includes('/') || file.includes('\\')) {
        p.push(`Font file '${file}' must be a bare filename, not a path`);
      }
      if (!/\.(ttf|otf)$/i.test(file)) {
        p.push(`Font file '${file}' should be .ttf or .otf`);
      }
    }
  }

  // A shipped family nobody references loads glyphs for nothing, and the usual
  // cause is a typo between the two blocks. On the device that is invisible:
  // the text falls back and no error is raised anywhere.
  const namedFamilies = [s.typography?.display, s.typography?.mono]
    .filter((x): x is string => !!x);
  for (const f of s.fonts ?? []) {
    if (f.family.trim() && !namedFamilies.includes(f.family.trim())) {
      p.push(`Font '${f.family}' is shipped but not named by typography`);
    }
  }

  // ─── AND THE DIRECTION THAT ACTUALLY BITES ────────────────────────────────
  //
  // The check above catches a font shipped and never used, which wastes bytes.
  // This one catches a family NAMED and never resolvable, which is the failure
  // that reaches users: the device hands the string to `fontFamily`, nothing
  // has registered it, and the text silently renders in the platform default.
  // No error, no log, no crash. `UbuntuMon` publishes exactly as happily as
  // `UbuntuMono`.
  //
  // Three ways a family can resolve, and it needs one of them:
  //   bundled          declared in pubspec, works offline on a cold boot
  //   Google Fonts     fetched at runtime and cached
  //   shipped in pack  files carried in `fonts`, registered by FontRegistry
  const shippedFamilies = (s.fonts ?? [])
    .map((f) => f.family.trim())
    .filter(Boolean);

  for (const [slot, family] of [
    ['display', s.typography?.display],
    ['mono', s.typography?.mono],
  ] as const) {
    const f = family?.trim();
    if (!f) continue;
    if (isKnownFamily(f) || shippedFamilies.includes(f)) continue;
    p.push(
      `Font '${f}' (${slot}) is not bundled, not on Google Fonts, and not shipped by this pack: it will render in the system font`,
    );
  }

  // A proportional mono family is not a typo and does not look like one, which
  // is why it needs saying. `terminal_screen.dart` derives the PTY column count
  // by measuring a run of glyphs in this family, so a proportional face makes
  // the count too generous and the remote host formats for a width the screen
  // does not have. Its output then wraps mid-field, which reads as a bug in the
  // SSH client rather than as a font choice.
  const monoFamily = s.typography?.mono?.trim();
  if (monoFamily && isKnownFamily(monoFamily) && !isMonospaceFamily(monoFamily)) {
    p.push(
      `Font '${monoFamily}' is not monospaced: the terminal's column count is measured from it`,
    );
  }

  if (s.paletteLight) {
    for (const [k, v] of Object.entries(s.paletteLight)) {
      if (!isHexColor(v as string)) {
        p.push(`Light palette ${k} '${v}' is not a hex colour`);
      }
    }
    // The device derives chrome brightness backwards from onDark's own
    // luminance, so a light palette carrying light ink inverts the whole
    // settings surface: white text on white cards. Cheap to catch here,
    // expensive to notice on a phone.
    if (isHexColor(s.paletteLight.onDark) && luminance(s.paletteLight.onDark) > 0.5) {
      p.push(
        "Light palette onDark is a light colour. It is the INK that must read on a light surface, so it should be dark.",
      );
    }
  }

  if (s.layout?.iconScale != null && (s.layout.iconScale < 0.7 || s.layout.iconScale > 1.4)) {
    p.push('Icon scale must be between 0.7 and 1.4');
  }
  if (s.minAppVersion != null && (!Number.isInteger(s.minAppVersion) || s.minAppVersion < 0)) {
    p.push('Min app version must be a whole number of 0 or more');
  }
  for (const key of ['boot', 'splash', 'desklets'] as const) {
    const v = s[key];
    if (v != null && typeof v !== 'object') p.push(`${key} must be a JSON object`);
  }
  return p;
}

// ── a new, blank theme to start from ─────────────────────────────────────────

/**
 * A minimal valid GNOME theme. Sensible neutral palette so the preview renders
 * immediately and the draft passes validation the moment an id and name are
 * typed. Deliberately free and unbundled: a builder starts by authoring, pricing
 * is a later, explicit choice.
 */
export function blankDraft(id = ''): ThemeDraft {
  return {
    id,
    title: '',
    summary: '',
    sku: null,
    bundled: false,
    packVersion: 1,
    updatedAt: 0,
    spec: {
      id,
      name: '',
      version: '',
      shell: 'gnome',
      tier: 'free',
      palette: {
        bgTop: '#2B2B36',
        bgBottom: '#16161E',
        bar: '#1B1B22',
        dock: '#CC1B1B22',
        accent: '#E9531F',
        onDark: '#FFFFFF',
      },
      typography: { display: 'Ubuntu', mono: 'UbuntuMono' },
      layout: { dock: 'left', topBar: true, grid: { rows: 5, cols: 4 } },
      icons: { treatment: 'roundedSquare', cornerRadius: 0.22, foregroundScale: 1.0 },
      wallpapers: [],
      minAppVersion: 6,
    },
  };
}


// ── importing an existing theme.json ─────────────────────────────────────────

/**
 * Read a published or hand-written `theme.json` back into an editable draft.
 *
 * The exact inverse of [canonicalThemeJson]: that writes the authored file, this
 * reads it. Together they let a theme round-trip through the builder without
 * changing what the device renders.
 *
 * ─── IT DOES NOT USE THE RESOLVER, AND THAT IS THE WHOLE DESIGN ─────────────
 *
 * `theme-resolve.ts` answers "what will the device draw", filling every absent
 * key with the default Dart would apply. Importing through it would be a
 * disaster in slow motion: a theme that authored no `icons` block would come
 * back with `treatment: roundedSquare, cornerRadius: 0.22`, look unchanged in
 * the preview, and RE-EXPORT those values as though the author had chosen them.
 * The next time the app's default changed, every theme ever opened in the
 * builder would be pinned to the old one.
 *
 * That is not hypothetical. `DeskletSkin` carries a long comment about exactly
 * this bug: its parse manufactured a `surface` for a key the theme never wrote,
 * and a theme asking for a bigger clock silently turned GNOME's bare clock into
 * a card. The fix there was to make absence representable. The same rule holds
 * here.
 *
 * So: ABSENT STAYS ABSENT. Only keys actually present are copied. The four
 * blocks typed `unknown` on [ThemeSpecJson] (`logo`, `boot`, `splash`,
 * `desklets`) pass through byte-for-byte, so a boot log this build has never
 * heard of survives an edit to the palette.
 *
 * ─── THE REQUIRED FIELDS ────────────────────────────────────────────────────
 *
 * `id`, `name`, `palette` and `layout` are non-optional on [ThemeSpecJson]
 * because the builder needs something to render. When the file omits one, it is
 * filled from [blankDraft] and a note says so, rather than the import failing:
 * a half-written theme is the normal reason to open a builder.
 */
export function importTheme(
  value: unknown,
): { spec: ThemeSpecJson; notes: string[] } | { error: string } {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'That file is not a JSON object.' };
  }
  const j = value as Record<string, unknown>;
  const notes: string[] = [];

  const base = blankDraft().spec;
  const str = (v: unknown) => (typeof v === 'string' ? v : undefined);
  const num = (v: unknown) =>
    typeof v === 'number' && Number.isFinite(v) ? v : undefined;
  const obj = (v: unknown) =>
    v && typeof v === 'object' && !Array.isArray(v)
      ? (v as Record<string, unknown>)
      : undefined;

  const id = str(j.id);
  if (!id) notes.push('No `id`. The device casts this to a non-null String and throws, so the theme would never load; set one before publishing.');

  const name = str(j.name);
  if (!name) notes.push('No `name`.');

  const shell = str(j.shell);
  if (shell && !SHELLS.includes(shell as ShellName)) {
    notes.push(`Shell '${shell}' is not one this build knows, so it was left as ${base.shell}. Check the spelling before assuming the panel is out of date.`);
  }

  const paletteRaw = obj(j.palette);
  const lightRaw = obj(j.paletteLight);
  if (!paletteRaw) notes.push('No `palette`. The device throws on an absent palette, so this one is the blank default.');

  const layoutRaw = obj(j.layout) ?? {};
  const gridRaw = obj(layoutRaw.grid);
  if (!gridRaw && (layoutRaw.rows !== undefined || layoutRaw.cols !== undefined)) {
    notes.push('`layout.rows`/`layout.cols` are at the top level, where nothing reads them. The parser only looks at `layout.grid`, so the grid has been left at its default.');
  }

  const tier = str(j.tier);
  const chrome = str(j.chromeFamily);
  if (chrome && !CHROMES.includes(chrome as ChromeName)) {
    notes.push(`Chrome family '${chrome}' is unknown and was dropped, so the shell default applies.`);
  }

  const wallpapers = Array.isArray(j.wallpapers)
    ? j.wallpapers.filter((w): w is string => typeof w === 'string')
    : [];
  if (Array.isArray(j.wallpapers) && wallpapers.length !== j.wallpapers.length) {
    notes.push('Some `wallpapers` entries were not strings and were dropped. On the device one such entry throws and loses the whole theme.');
  }
  if (!Array.isArray(j.wallpapers) && obj(j.wallpaper)) {
    const legacy = str(obj(j.wallpaper)!.asset);
    if (legacy) {
      wallpapers.push(legacy);
      notes.push('Converted the old single `wallpaper.asset` shape into `wallpapers`.');
    }
  }

  const wallpaperMeta: Record<string, WallpaperMetaJson> = {};
  const metaRaw = obj(j.wallpaperMeta);
  if (metaRaw) {
    for (const [name, raw] of Object.entries(metaRaw)) {
      const m = obj(raw);
      if (!m) continue;
      const fit = str(m.fit);
      if (fit && !WALLPAPER_FITS.includes(fit as WallpaperFit)) {
        notes.push(`Framing for '${name}' named an unknown fit '${fit}', which was dropped, so the app default applies.`);
      }
      const trimmed = canonWallpaperMeta({
        ...(fit && WALLPAPER_FITS.includes(fit as WallpaperFit)
          ? { fit: fit as WallpaperFit }
          : {}),
        focalX: num(m.focalX) ?? 0.5,
        focalY: num(m.focalY) ?? 0.5,
        zoom: num(m.zoom) ?? 1,
      });
      if (trimmed) wallpaperMeta[name] = trimmed;
    }
    // A key naming a wallpaper this theme does not ship is never looked up on
    // the device rather than an error, but it IS worth saying: it is almost
    // always a rename that only got applied on one side.
    const orphans = Object.keys(wallpaperMeta).filter((k) => !wallpapers.includes(k));
    if (orphans.length) {
      notes.push(`Framing was set for ${orphans.length === 1 ? 'a wallpaper' : `${orphans.length} wallpapers`} this theme does not ship (${orphans.join(', ')}). It is kept but never applied.`);
    }
  }

  const spec: ThemeSpecJson = {
    id: id ?? base.id,
    name: name ?? base.name,
    version: str(j.version) ?? '',
    shell: (shell && SHELLS.includes(shell as ShellName) ? shell : base.shell) as ShellName,
    tier: (tier === 'free' || tier === 'pro' ? tier : base.tier) as TierName,
    palette: {
      bgTop: str(paletteRaw?.bgTop) ?? base.palette.bgTop,
      bgBottom: str(paletteRaw?.bgBottom) ?? base.palette.bgBottom,
      bar: str(paletteRaw?.bar) ?? base.palette.bar,
      dock: str(paletteRaw?.dock) ?? base.palette.dock,
      accent: str(paletteRaw?.accent) ?? base.palette.accent,
      onDark: str(paletteRaw?.onDark) ?? base.palette.onDark,
    },
    // ABSENT STAYS ABSENT. Unlike `palette`, which the device throws without
    // and which therefore falls back to the blank default, a missing light
    // block is a meaningful answer: this distro has no light mode. Filling it
    // from `base` would invent one on every import and republish it.
    fonts: Array.isArray(j.fonts)
      ? (j.fonts as unknown[])
          .map((e) => obj(e))
          .filter((e): e is Record<string, unknown> => !!e)
          .map((e) => ({
            family: str(e.family) ?? '',
            files: Array.isArray(e.files)
              ? (e.files as unknown[]).map(String).filter(Boolean)
              : [],
          }))
          .filter((f) => f.family && f.files.length)
      : undefined,
    paletteLight: lightRaw
      ? {
          bgTop: str(lightRaw.bgTop) ?? base.palette.bgTop,
          bgBottom: str(lightRaw.bgBottom) ?? base.palette.bgBottom,
          bar: str(lightRaw.bar) ?? base.palette.bar,
          dock: str(lightRaw.dock) ?? base.palette.dock,
          accent: str(lightRaw.accent) ?? base.palette.accent,
          onDark: str(lightRaw.onDark) ?? base.palette.onDark,
        }
      : null,
    layout: {
      dock: (DOCKS as string[]).includes(str(layoutRaw.dock) ?? '')
        ? (str(layoutRaw.dock) as DockName)
        : base.layout.dock,
      topBar:
        typeof layoutRaw.topBar === 'boolean' ? layoutRaw.topBar : base.layout.topBar,
      // Round-tripped so importing a theme and republishing it does not drop
      // its bar position, the same reason `paletteLight` is read here.
      topBarSide: (TOP_BAR_SIDES as readonly string[]).includes(
        str(layoutRaw.topBarSide) ?? '',
      )
        ? (str(layoutRaw.topBarSide) as TopBarSideName)
        : undefined,
      topBarStats:
        typeof layoutRaw.topBarStats === 'boolean'
          ? layoutRaw.topBarStats
          : undefined,
      // Round-tripped so importing a theme and republishing it does not quietly
      // flatten a two-panel distro back to one.
      panels: Array.isArray(layoutRaw.panels)
        ? (layoutRaw.panels as unknown[])
            .map((e) => obj(e))
            .filter((e): e is Record<string, unknown> => !!e)
            .map((e) => ({
              side: ((TOP_BAR_SIDES as readonly string[]).includes(
                str(e.side) ?? '',
              )
                ? str(e.side)
                : 'top') as TopBarSideName,
              modules: (Array.isArray(e.modules) ? e.modules : [])
                .map(String)
                .filter((m): m is PanelModuleName =>
                  (PANEL_MODULES as readonly string[]).includes(m),
                ),
              ...(typeof e.height === 'number' ? { height: e.height } : {}),
            }))
            .filter((p) => p.modules.length)
        : undefined,
      workspaceAxis: (WORKSPACE_AXES as readonly string[]).includes(
        str(layoutRaw.workspaceAxis) ?? '',
      )
        ? (str(layoutRaw.workspaceAxis) as WorkspaceAxisName)
        : undefined,
      // ─── THE IMPORT GUARD IS THE HALF THAT GETS FORGOTTEN ───────────────
      //
      // Adding a key to the interface and the serializer makes the BUILDER
      // able to write it. Without an arm here, importing a theme.json that
      // already carries the key drops it silently, so a round trip through the
      // panel strips the field and republishing quietly reverts the distro.
      // That is what happened to `drawerGrouping: "library"`, and the note on
      // DRAWER_GROUPINGS above is that bug's headstone.
      appsSurface: (APPS_SURFACES as readonly string[]).includes(
        str(layoutRaw.appsSurface) ?? '',
      )
        ? (str(layoutRaw.appsSurface) as AppsSurfaceName)
        : undefined,
      desktopIcons:
        typeof layoutRaw.desktopIcons === 'boolean'
          ? layoutRaw.desktopIcons
          : undefined,
      panelEdit:
        typeof layoutRaw.panelEdit === 'boolean'
          ? layoutRaw.panelEdit
          : undefined,
      grid: {
        rows: num(gridRaw?.rows) ?? base.layout.grid?.rows ?? 5,
        cols: num(gridRaw?.cols) ?? base.layout.grid?.cols ?? 4,
      },
      // Absent stays absent: `canonicalThemeJson` only emits iconScale when it
      // is non-null, so importing a theme without one and re-exporting must not
      // introduce it.
      ...(num(layoutRaw.iconScale) !== undefined
        ? { iconScale: num(layoutRaw.iconScale) }
        : {}),
      // Unknown values become absent rather than fatal, matching
      // `ThemeLayout.fromJson` on the device: a value from a newer catalogue
      // has to degrade to "no opinion", not stop the import.
      ...((DRAWER_SCROLLS as readonly string[]).includes(
        str(layoutRaw.drawerScrollStyle) ?? '',
      )
        ? { drawerScrollStyle: str(layoutRaw.drawerScrollStyle) as DrawerScrollName }
        : {}),
      ...((DRAWER_GROUPINGS as readonly string[]).includes(
        str(layoutRaw.drawerGrouping) ?? '',
      )
        ? { drawerGrouping: str(layoutRaw.drawerGrouping) as DrawerGroupingName }
        : {}),
      ...((KICKOFF_RAILS as readonly string[]).includes(
        str(layoutRaw.kickoffRail) ?? '',
      )
        ? { kickoffRail: str(layoutRaw.kickoffRail) as KickoffRailName }
        : {}),
      ...((TILING_LAUNCHERS as readonly string[]).includes(
        str(layoutRaw.tilingLauncher) ?? '',
      )
        ? { tilingLauncher: str(layoutRaw.tilingLauncher) as TilingLauncherName }
        : {}),
      ...((APP_DRAWERS as readonly string[]).includes(
        str(layoutRaw.appDrawer) ?? '',
      )
        ? { appDrawer: str(layoutRaw.appDrawer) as AppDrawerName }
        : {}),
      ...((HOME_LAYOUTS as readonly string[]).includes(
        str(layoutRaw.homeLayout) ?? '',
      )
        ? { homeLayout: str(layoutRaw.homeLayout) as HomeLayoutName }
        : {}),
      ...((DOCK_STYLES as readonly string[]).includes(
        str(layoutRaw.dockStyle) ?? '',
      )
        ? { dockStyle: str(layoutRaw.dockStyle) as DockStyleName }
        : {}),
      ...((DOCK_REVEALS as readonly string[]).includes(
        str(layoutRaw.dockReveal) ?? '',
      )
        ? { dockReveal: str(layoutRaw.dockReveal) as DockRevealName }
        : {}),
      // CLAMPED on the way in, matching the device and the stepper. A theme
      // asking for eight gets five rather than a row of dots nobody can count.
      ...(typeof layoutRaw.workspaces === 'number'
        ? {
            workspaces: Math.min(
              5,
              Math.max(1, Math.round(layoutRaw.workspaces)),
            ),
          }
        : {}),
    },
    wallpapers,
    ...(Object.keys(wallpaperMeta).length ? { wallpaperMeta } : {}),
    minAppVersion: Math.trunc(num(j.minAppVersion) ?? 0),
  };

  if (chrome && CHROMES.includes(chrome as ChromeName)) {
    spec.chromeFamily = chrome as ChromeName;
  }

  const typo = obj(j.typography);
  if (typo && (str(typo.display) || str(typo.mono))) {
    spec.typography = { display: str(typo.display), mono: str(typo.mono) };
  }

  const icons = obj(j.icons);
  if (icons) spec.icons = icons as IconStyleJson;

  // Straight through. These are `unknown` on ThemeSpecJson precisely so a block
  // this build does not model survives an edit to something else.
  if (j.logo != null) spec.logo = j.logo;
  if (j.boot != null) spec.boot = j.boot;
  if (j.splash != null) spec.splash = j.splash;
  if (j.desklets != null) spec.desklets = j.desklets;

  // MODELLED, not straight through, unlike the four above. Those are `unknown`
  // so a block this build cannot parse survives a round trip; rows are a typed
  // array the editor renders as fields, so they have to arrive as real objects.
  //
  // A malformed element is skipped rather than fatal, matching `features()` in
  // CdnIndex.kt: editorial copy must not be able to fail an import.
  // MODELLED, not straight through, for the same reason `features` is: the
  // editor renders these as fields. And present HERE at all because an import
  // arm is the half that gets forgotten: without it, importing Kali's
  // theme.json and republishing would silently strip its thirteen categories
  // and leave the tool menu empty, which is exactly what happened to
  // `drawerGrouping: "library"`.
  const catRaw = j.categories;
  if (Array.isArray(catRaw)) {
    const rows: ThemeCategoryJson[] = [];
    for (const raw of catRaw) {
      const c = obj(raw);
      if (!c) continue;
      const name = str(c.name)?.trim();
      if (!name) continue;
      const feeds = Array.isArray(c.feeds)
        ? c.feeds.map(String).map((f) => f.trim()).filter(Boolean)
        : [];
      rows.push({ name, ...(feeds.length ? { feeds } : {}) });
    }
    if (rows.length) spec.categories = rows;
  }
  const catFallback = str(j.categoryFallback)?.trim();
  if (catFallback) spec.categoryFallback = catFallback;

  const featureRaw = j.features;
  if (Array.isArray(featureRaw)) {
    const rows: ThemeFeatureJson[] = [];
    for (const raw of featureRaw) {
      const f = obj(raw);
      if (!f) continue;
      const title = str(f.title)?.trim();
      if (!title) continue;
      rows.push({
        title,
        body: str(f.body)?.trim() ?? '',
        // Absent reads as `true`, matching the device's ThemeFeature default
        // and the native parser. The panel always writes it, so this only
        // fires for hand-edited JSON.
        exclusive: f.exclusive !== false,
      });
    }
    if (rows.length) spec.features = rows;
  }

  // String pairs only. An action id this build does not know is KEPT, not
  // dropped: the catalogue outlives any one panel build, and the device
  // already screens a theme default it cannot decode. Dropping it here would
  // silently strip a working binding on a round trip through an older panel.
  const gestureRaw = obj(j.gestures);
  if (gestureRaw) {
    const g: Record<string, string> = {};
    for (const [k, v] of Object.entries(gestureRaw)) {
      if (typeof v === 'string' && v.trim() !== '') g[k] = v;
    }
    if (Object.keys(g).length) spec.gestures = g;
  }

  // Keys nothing reads. Usually a typo, occasionally a field from a newer
  // build, and either way worth naming: the device ignores both silently.
  const unknownKeys = Object.keys(j).filter((k) => !THEME_SPEC_KEYS.has(k));
  if (unknownKeys.length) {
    notes.push(`Ignored ${unknownKeys.length} key(s) nothing reads: ${unknownKeys.join(', ')}. A typo and a field from a newer build look the same here.`);
  }

  return { spec, notes };
}
