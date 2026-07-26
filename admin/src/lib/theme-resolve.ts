/**
 * WHAT THE DEVICE WILL ACTUALLY DO WITH THIS theme.json.
 *
 * `theme-spec.ts` describes the file the BUILDER writes and stays narrow, as its
 * own docblock insists. This is the other direction: given bytes that are
 * already published, what does `ThemeSpec.fromJson` in Dart make of them, and
 * what did it quietly decide along the way.
 *
 * ─── THE ONE THING THIS PAGE EXISTS TO SAY ──────────────────────────────────
 *
 * Almost nothing in the Dart parser fails loudly. An unknown shell becomes
 * gnome. An unknown icon treatment becomes roundedSquare. A missing `accent`
 * becomes Ubuntu orange. An `iconScale` of 3.0 becomes 1.4. A misspelled key is
 * simply not read. Every one of those produces a working theme that is not the
 * theme anybody authored, and there is no signal anywhere: the pack verifies,
 * installs and renders.
 *
 * So the resolver records a NOTE every time it takes a decision the author did
 * not write, and the pack page lists them. That list is the only place the
 * difference between "my theme" and "the theme that shipped" is visible.
 *
 * ─── FOUR LEVELS, AND THEY MEAN DIFFERENT THINGS ────────────────────────────
 *
 *   error     Dart THROWS here. `theme_engine._loadInstalled` catches it and
 *             returns null, so the device silently renders bundled Ubuntu. The
 *             pack is live, verified, installed and invisible.
 *   degraded  the author wrote something and it was not understood, so a
 *             different value was substituted. The loudest kind of quiet bug.
 *   default   the author wrote nothing and a default applied. Usually fine,
 *             occasionally the reason a distro looks like Ubuntu.
 *   lint      legal, parsed exactly as written, and probably not what was meant.
 *
 * ─── THIS IS A SECOND IMPLEMENTATION, AND THAT IS A COST ────────────────────
 *
 * Every default below is duplicated from Dart. Duplication is exactly how
 * `IconRenderer.IconStyle` became a hand-written twin of the Pigeon one and
 * drifted. It is accepted here because the alternative is worse: a panel that
 * shows you the JSON you uploaded tells you nothing you did not already know,
 * and the whole value is in reporting decisions Dart makes that the file does
 * not contain.
 *
 * The duplication is bounded on purpose. Boot and splash DEFAULTS are not
 * ported — they are seventy lines of authored log data per shell, they change
 * often, and the page does not need them. A theme that ships no boot block gets
 * a note naming the shell whose default will play, and no invented content.
 *
 * SOURCE OF TRUTH: `lib/engine/theme_spec.dart`. When a default changes there,
 * it changes here. The pack page is the only consumer, so a drift shows up as
 * a wrong note rather than as a wrong render.
 */

export type NoteLevel = 'error' | 'degraded' | 'lint' | 'default';

export interface ThemeNote {
  level: NoteLevel;
  /** Dotted path into the JSON, e.g. `palette.accent`. */
  path: string;
  message: string;
}

export type ShellName = 'gnome' | 'plasma' | 'tiling' | 'tui' | 'aqua';
export type ChromeName = 'adwaita' | 'breeze' | 'aqua' | 'generic';
export type DockName = 'left' | 'bottom' | 'off';

/** Every treatment Dart's `_treatment` recognises. */
export const TREATMENTS = [
  'roundedSquare',
  'squircle',
  'circle',
  'square',
  'teardrop',
  'original',
] as const;
export type TreatmentName = (typeof TREATMENTS)[number];

export const BOOT_KINDS = [
  'ok',
  'warn',
  'fail',
  'plain',
  'dim',
  'grub',
  'grubSelected',
  'blank',
] as const;
export type BootKind = (typeof BOOT_KINDS)[number];

export const SPLASH_STYLES = ['dots', 'bar', 'spinner', 'text', 'none'] as const;
export type SplashStyleName = (typeof SPLASH_STYLES)[number];

export interface ResolvedPalette {
  bgTop: string;
  bgBottom: string;
  bar: string;
  dock: string;
  accent: string;
  onDark: string;
}

export interface ResolvedTypography {
  display: string | null;
  mono: string | null;
}

export interface ResolvedLayout {
  dock: DockName;
  topBar: boolean;
  rows: number;
  cols: number;
  iconScale: number;
}

export interface ResolvedIcons {
  treatment: TreatmentName;
  cornerRadius: number;
  foregroundScale: number;
  backgroundColor: string | null;
  monochromeTint: string | null;
  heroPack: string | null;
  backgroundGradientEnd: string | null;
  gradientAngle: number | null;
  brandPack: string | null;
  brandTreatment: string | null;
}

export interface ResolvedBootLine {
  kind: BootKind;
  text: string;
  /** After the per-kind default is applied. */
  delayMs: number;
}

export interface ResolvedBoot {
  lines: ResolvedBootLine[];
  tailMs: number;
  /** Sum of every delay plus the tail. */
  totalMs: number;
}

export interface ResolvedSplash {
  style: SplashStyleName | null;
  logo: string | null;
  /** Clamped 400 to 1500 by SplashSpec's constructor. */
  durationMs: number | null;
}

export interface ResolvedStarter {
  kind: string;
  page: number;
  col: number | null;
  row: number | null;
  spanX: number | null;
  spanY: number | null;
}

export interface ResolvedDesklets {
  offers: string[];
  starter: ResolvedStarter[];
  skins: string[];
}

export interface ResolvedTheme {
  id: string;
  name: string;
  /** A DISPLAY string like "24.04". Not the pack's monotonic integer. */
  version: string;
  shell: ShellName;
  tier: string;
  chromeFamily: ChromeName;
  palette: ResolvedPalette;
  typography: ResolvedTypography;
  layout: ResolvedLayout;
  icons: ResolvedIcons;
  wallpapers: string[];
  minAppVersion: number;
  logo: { light: string; dark: string } | null;
  /** Null when the theme authors none; the device plays its shell default. */
  boot: ResolvedBoot | null;
  splash: ResolvedSplash | null;
  desklets: ResolvedDesklets;
  /** Every file the theme references. What `flat-check` inspects. */
  assets: string[];
  notes: ThemeNote[];
}

// ── colour ──────────────────────────────────────────────────────────────────

/**
 * Dart's `parseColor`, exactly: strip `#`, trim, six digits get an opaque
 * alpha, anything not eight digits is null.
 *
 * NULL IS MEANINGFUL, not merely absent. In the icon block it means "use the
 * app's own background", which is why this cannot throw or substitute.
 */
function parseColor(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  let s = raw.replace('#', '').trim();
  if (s.length === 6) s = `FF${s}`;
  if (s.length !== 8) return null;
  if (!/^[0-9a-fA-F]{8}$/.test(s)) return null;
  return `#${s.toUpperCase()}`;
}

/**
 * An `#AARRGGBB` string as a CSS colour.
 *
 * Alpha FIRST, which is the whole reason this function exists: CSS `#RRGGBBAA`
 * puts it last, so handing a Flutter colour straight to `background` renders
 * the alpha as blue. Ubuntu's `dock` is `#BD201B21`, which would come out as a
 * flat blue-black rectangle and look like a deliberate design choice.
 */
export function toCss(argb: string): string {
  const s = argb.replace('#', '');
  if (s.length !== 8) return argb;
  const a = parseInt(s.slice(0, 2), 16) / 255;
  const r = parseInt(s.slice(2, 4), 16);
  const g = parseInt(s.slice(4, 6), 16);
  const b = parseInt(s.slice(6, 8), 16);
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}

/**
 * Asset paths that resolve through the Flutter asset bundle rather than the
 * pack directory.
 *
 * These are the ones that work perfectly while a theme is BUNDLED and resolve
 * against nothing the moment the same file is downloaded, which is the single
 * hardest failure in this system to diagnose from the outside: the theme loads,
 * the palette applies, and the wallpaper is a black rectangle.
 */
export function absolutePaths(assets: string[]): string[] {
  return assets.filter((a) => a.startsWith('/') || a.startsWith('assets/'));
}

// ── the resolver ────────────────────────────────────────────────────────────

const PALETTE_DEFAULTS: ResolvedPalette = {
  bgTop: '#FF2C0A22',
  bgBottom: '#FF220817',
  bar: '#FF1A171B',
  dock: '#BD201B21',
  accent: '#FFE95420',
  onDark: '#FFFFFFFF',
};

/** Dart `ChromeFamily.defaultForShell`. */
const CHROME_FOR_SHELL: Record<ShellName, ChromeName> = {
  gnome: 'adwaita',
  plasma: 'breeze',
  tiling: 'generic',
  tui: 'generic',
  aqua: 'aqua',
};

/** Dart `BootLine.defaultDelayFor`. */
const BOOT_DELAY: Record<BootKind, number> = {
  ok: 110,
  warn: 300,
  fail: 320,
  dim: 170,
  plain: 200,
  grub: 380,
  grubSelected: 520,
  blank: 70,
};

const ICON_SCALE_MIN = 0.7;
const ICON_SCALE_MAX = 1.4;
const SPLASH_MIN_MS = 400;
const SPLASH_MAX_MS = 1500;
const SPLASH_DEFAULT_MS = 900;

/**
 * Resolve published bytes into what the device will render.
 *
 * The `error` arm is for input that is not an object at all. Everything else,
 * INCLUDING the cases where Dart throws, comes back as a resolved theme carrying
 * an `error` note, because a page that renders nothing cannot tell you why.
 */
export function parseTheme(value: unknown): ResolvedTheme | { error: string } {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'theme.json is not a JSON object' };
  }
  const j = value as Record<string, unknown>;
  const notes: ThemeNote[] = [];
  const note = (level: NoteLevel, path: string, message: string) =>
    notes.push({ level, path, message });

  const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
  const num = (v: unknown): number | null =>
    typeof v === 'number' && Number.isFinite(v) ? v : null;

  // ── identity ──────────────────────────────────────────────────────────
  //
  // `json['id'] as String` in Dart, with no `?`. A cast to a non-nullable type
  // against null THROWS, so these are not "missing field" cases, they are
  // "the pack cannot load at all" cases.
  const id = str(j.id);
  const name = str(j.name);
  if (id === null) {
    note('error', 'id', 'Missing. Dart casts this to a non-null String and throws, so the theme fails to load and the device silently falls back to bundled Ubuntu.');
  }
  if (name === null) {
    note('error', 'name', 'Missing. Same non-null cast as `id`: the whole theme fails to load and the device renders Ubuntu.');
  }

  const version = str(j.version) ?? '';
  if (str(j.version) === null && j.version !== undefined) {
    note('degraded', 'version', 'Not a string, so it reads as empty. This is the DISPLAY version ("24.04"), not the pack version.');
  }

  const tier = str(j.tier) ?? 'free';
  if (j.tier === undefined) note('default', 'tier', 'Absent, so free.');

  const minAppVersion = Math.trunc(num(j.minAppVersion) ?? 0);
  if (j.minAppVersion === undefined) {
    note('default', 'minAppVersion', 'Absent, so 0: every build accepts this theme, including ones predating any field it uses.');
  }

  // ── shell and chrome ──────────────────────────────────────────────────
  const rawShell = str(j.shell);
  const shell: ShellName = isShell(rawShell) ? rawShell : 'gnome';
  if (rawShell === null) {
    note('default', 'shell', 'Absent, so gnome. The shell decides the entire desktop metaphor.');
  } else if (!isShell(rawShell)) {
    note('degraded', 'shell', `'${rawShell}' is not a shell this build knows, so it renders as gnome. Check the spelling before assuming the app is too old.`);
  }

  const rawChrome = str(j.chromeFamily);
  const chromeFamily: ChromeName = isChrome(rawChrome)
    ? rawChrome
    : CHROME_FOR_SHELL[shell];
  if (rawChrome !== null && !isChrome(rawChrome)) {
    note('degraded', 'chromeFamily', `'${rawChrome}' is unknown, so the ${shell} default (${CHROME_FOR_SHELL[shell]}) applies.`);
  }

  // ── palette ───────────────────────────────────────────────────────────
  //
  // `(json['palette'] as Map)` with no `?`. Absent throws, exactly like `id`.
  const paletteRaw = obj(j.palette);
  if (paletteRaw === null) {
    note('error', 'palette', 'Missing. Dart casts this to a non-null Map and throws, so the theme never loads. There is no partial-palette fallback.');
  }
  const palette = { ...PALETTE_DEFAULTS };
  for (const key of Object.keys(PALETTE_DEFAULTS) as (keyof ResolvedPalette)[]) {
    const raw = paletteRaw?.[key];
    const parsed = parseColor(raw);
    if (parsed) {
      palette[key] = parsed;
    } else if (raw !== undefined && raw !== null) {
      note('degraded', `palette.${key}`, `'${String(raw)}' is not #RRGGBB or #AARRGGBB, so it falls back to ${PALETTE_DEFAULTS[key]} — which is Ubuntu's.`);
    } else if (paletteRaw !== null) {
      note('default', `palette.${key}`, `Absent, so ${PALETTE_DEFAULTS[key]}. That default is Ubuntu's colour, so this distro inherits it.`);
    }
  }

  // ── typography ────────────────────────────────────────────────────────
  const typoRaw = obj(j.typography) ?? {};
  const typography: ResolvedTypography = {
    display: str(typoRaw.display),
    mono: str(typoRaw.mono),
  };
  if (typography.display === null) {
    note('default', 'typography.display', "Absent, so the house font is used. Family strings are exact: 'Ubuntu', 'UbuntuMono'.");
  }

  // ── layout ────────────────────────────────────────────────────────────
  //
  // FLAT `dock`/`topBar`/`iconScale`, NESTED `grid.rows`/`grid.cols`. That
  // asymmetry is in the Dart parser and is the single easiest thing to get
  // wrong when authoring by hand: rows and cols written at the top level of
  // `layout` are simply not read, and the grid silently stays 5 x 4.
  const layoutRaw = obj(j.layout) ?? {};
  const gridRaw = obj(layoutRaw.grid) ?? {};

  const rawDock = str(layoutRaw.dock);
  const dock: DockName =
    rawDock === 'bottom' ? 'bottom' : rawDock === 'off' ? 'off' : 'left';
  if (rawDock !== null && rawDock !== 'bottom' && rawDock !== 'off' && rawDock !== 'left') {
    note('degraded', 'layout.dock', `'${rawDock}' is unknown, so the dock sits left.`);
  }

  if (layoutRaw.rows !== undefined || layoutRaw.cols !== undefined) {
    note('lint', 'layout.rows / layout.cols', 'Written at the top level of `layout`, where nothing reads them. The parser only looks at `layout.grid.rows` and `layout.grid.cols`.');
  }

  const rawScale = layoutRaw.iconScale;
  let iconScale = 1.0;
  if (rawScale !== undefined) {
    const v = num(rawScale);
    if (v === null) {
      note('degraded', 'layout.iconScale', 'Not a finite number, so 1.0.');
    } else {
      iconScale = Math.min(ICON_SCALE_MAX, Math.max(ICON_SCALE_MIN, v));
      if (iconScale !== v) {
        note('degraded', 'layout.iconScale', `${v} is outside ${ICON_SCALE_MIN} to ${ICON_SCALE_MAX} and is clamped to ${iconScale}. Downloaded content that drives UI gets bounded.`);
      }
    }
  }

  const layout: ResolvedLayout = {
    dock,
    topBar: typeof layoutRaw.topBar === 'boolean' ? layoutRaw.topBar : true,
    rows: Math.trunc(num(gridRaw.rows) ?? 5),
    cols: Math.trunc(num(gridRaw.cols) ?? 4),
    iconScale,
  };

  // ── icons ─────────────────────────────────────────────────────────────
  const iconsRaw = obj(j.icons) ?? {};
  const rawTreatment = str(iconsRaw.treatment);
  const treatment: TreatmentName = isTreatment(rawTreatment)
    ? rawTreatment
    : 'roundedSquare';
  if (rawTreatment !== null && !isTreatment(rawTreatment)) {
    note('degraded', 'icons.treatment', `'${rawTreatment}' is not one of ${TREATMENTS.join(', ')}, so roundedSquare applies.`);
  }

  const icons: ResolvedIcons = {
    treatment,
    cornerRadius: num(iconsRaw.cornerRadius) ?? 0.22,
    foregroundScale: num(iconsRaw.foregroundScale) ?? 1.0,
    backgroundColor: parseColor(iconsRaw.backgroundColor),
    monochromeTint: parseColor(iconsRaw.monochromeTint),
    heroPack: str(iconsRaw.heroPack),
    backgroundGradientEnd: parseColor(iconsRaw.backgroundGradientEnd),
    gradientAngle: num(iconsRaw.gradientAngle),
    brandPack: str(iconsRaw.brandPack),
    brandTreatment: str(iconsRaw.brandTreatment),
  };

  if (icons.backgroundGradientEnd && !icons.backgroundColor) {
    note('lint', 'icons.backgroundGradientEnd', 'A gradient end with no `backgroundColor` to start from. The renderer needs both, so this draws nothing.');
  }
  if (icons.brandTreatment !== null && icons.brandTreatment !== 'brandPlate' && icons.brandTreatment !== 'themePlate') {
    note('degraded', 'icons.brandTreatment', `'${icons.brandTreatment}' is unknown, so brandPlate applies.`);
  }

  // ── wallpapers ────────────────────────────────────────────────────────
  //
  // `list.map((e) => e as String)` throws on a non-string element, so one bad
  // entry loses the entire theme rather than one wallpaper.
  const wallpapers: string[] = [];
  if (Array.isArray(j.wallpapers)) {
    for (const [i, w] of j.wallpapers.entries()) {
      if (typeof w === 'string') {
        wallpapers.push(w);
      } else {
        note('error', `wallpapers[${i}]`, 'Not a string. Dart casts every element and throws on the first that is not, so the whole theme fails to load.');
      }
    }
  } else if (j.wallpapers !== undefined) {
    note('degraded', 'wallpapers', 'Not a list, so it is ignored and the legacy `wallpaper.asset` is read instead.');
  } else {
    const legacy = str(obj(j.wallpaper)?.asset);
    if (legacy) {
      wallpapers.push(legacy);
      note('lint', 'wallpaper.asset', 'The old single-wallpaper shape. Still read, but `wallpapers: []` is the current one.');
    }
  }

  // ── logo ──────────────────────────────────────────────────────────────
  let logo: { light: string; dark: string } | null = null;
  if (typeof j.logo === 'string') {
    logo = { light: j.logo, dark: j.logo };
    note('lint', 'logo', 'One asset for both surfaces. On a dark surface it is tinted to `onDark`, which flattens a coloured mark to a silhouette.');
  } else if (obj(j.logo)) {
    const m = obj(j.logo)!;
    const light = str(m.light);
    const dark = str(m.dark);
    const base = light ?? dark;
    if (base === null) {
      note('degraded', 'logo', 'Neither `light` nor `dark` is a string, so the theme has no logo and the Mindhunter mark is drawn.');
    } else {
      logo = { light: light ?? base, dark: dark ?? base };
      if (!light || !dark) {
        note('default', 'logo', `Only one variant authored, so both surfaces use it.`);
      }
    }
  }

  // ── boot ──────────────────────────────────────────────────────────────
  //
  // Not defaulted here, deliberately. Dart falls back to
  // `BootSpec.defaultForShell`, which is seventy lines of authored log per
  // shell; porting it would duplicate content that changes often to show
  // something the author did not write. The note names the fallback instead.
  let boot: ResolvedBoot | null = null;
  const bootRaw = obj(j.boot);
  if (bootRaw) {
    const rawLines = Array.isArray(bootRaw.lines) ? bootRaw.lines : null;
    if (!rawLines || rawLines.length === 0) {
      note('degraded', 'boot.lines', `Absent or empty, so the whole boot block is discarded and the ${shell} default log plays.`);
    } else {
      const lines: ResolvedBootLine[] = [];
      for (const [i, entry] of rawLines.entries()) {
        const e = obj(entry);
        if (!e) continue; // Dart skips non-map entries silently.
        const rawKind = str(e.kind);
        const kind: BootKind = isBootKind(rawKind) ? rawKind : 'plain';
        if (rawKind !== null && !isBootKind(rawKind)) {
          note('degraded', `boot.lines[${i}].kind`, `'${rawKind}' is unknown, so it prints as plain text.`);
        }
        lines.push({
          kind,
          text: str(e.text) ?? '',
          delayMs: Math.trunc(num(e.delayMs) ?? BOOT_DELAY[kind]),
        });
      }
      if (lines.length === 0) {
        note('degraded', 'boot.lines', `No entry was an object, so the block is discarded and the ${shell} default plays.`);
      } else {
        const tailMs = Math.trunc(num(bootRaw.tailMs) ?? 600);
        const totalMs = lines.reduce((n, l) => n + l.delayMs, 0) + tailMs;
        boot = { lines, tailMs, totalMs };

        if (totalMs > 12000) {
          note('lint', 'boot', `Runs for ${(totalMs / 1000).toFixed(1)}s. It is tap-to-skip, but this plays on every cold start with verbose boot on.`);
        }
        const fails = lines.filter((l) => l.kind === 'fail').length;
        if (fails > 0) {
          note('lint', 'boot', `${fails} [FAILED] ${fails === 1 ? 'line' : 'lines'}. A launcher that appears to fail a service on every boot reads as broken rather than authentic.`);
        }
      }
    }
  } else {
    note('default', 'boot', `No boot block, so the ${shell} default log plays when verbose boot is on.`);
  }

  // ── splash ────────────────────────────────────────────────────────────
  let splash: ResolvedSplash | null = null;
  const splashRaw = obj(j.splash);
  if (splashRaw) {
    const rawStyle = str(splashRaw.style);
    const style: SplashStyleName = isSplashStyle(rawStyle) ? rawStyle : 'spinner';
    if (rawStyle !== null && !isSplashStyle(rawStyle)) {
      note('degraded', 'splash.style', `'${rawStyle}' is unknown, so spinner applies.`);
    }
    const wanted = num(splashRaw.durationMs) ?? SPLASH_DEFAULT_MS;
    const durationMs = Math.min(SPLASH_MAX_MS, Math.max(SPLASH_MIN_MS, wanted));
    if (durationMs !== wanted) {
      note('degraded', 'splash.durationMs', `${wanted} is outside ${SPLASH_MIN_MS} to ${SPLASH_MAX_MS} and is clamped to ${durationMs}. A CDN theme cannot decide the desktop takes eight seconds to appear.`);
    }
    splash = { style, logo: str(splashRaw.logo), durationMs };
  } else {
    note('default', 'splash', `No splash block, so the ${shell} default applies.`);
  }

  // ── desklets ──────────────────────────────────────────────────────────
  const deskletsRaw = obj(j.desklets) ?? {};
  const offers = Array.isArray(deskletsRaw.offers)
    ? deskletsRaw.offers.map((o) => String(o))
    : [];
  const starter: ResolvedStarter[] = [];
  if (Array.isArray(deskletsRaw.starter)) {
    for (const [i, entry] of deskletsRaw.starter.entries()) {
      const e = obj(entry);
      if (!e) {
        note('error', `desklets.starter[${i}]`, 'Not an object. Dart casts it to a Map and throws, losing the whole theme.');
        continue;
      }
      const kind = str(e.kind);
      if (kind === null) {
        note('error', `desklets.starter[${i}].kind`, 'Missing. Cast to a non-null String, so the theme fails to load entirely.');
        continue;
      }
      const col = num(e.col);
      const row = num(e.row);
      if ((col === null) !== (row === null)) {
        note('lint', `desklets.starter[${i}]`, 'Only one of `col`/`row` is set. An exact cell needs both; with one, the packer places it wherever it fits.');
      }
      starter.push({
        kind,
        page: Math.trunc(num(e.page) ?? 0),
        col: col === null ? null : Math.trunc(col),
        row: row === null ? null : Math.trunc(row),
        spanX: num(e.spanX) === null ? null : Math.trunc(num(e.spanX)!),
        spanY: num(e.spanY) === null ? null : Math.trunc(num(e.spanY)!),
      });
    }
  }
  const desklets: ResolvedDesklets = {
    offers,
    starter,
    skins: Object.keys(obj(deskletsRaw.skins) ?? {}),
  };

  // ── assets ────────────────────────────────────────────────────────────
  const assets = [
    ...new Set(
      [
        ...wallpapers,
        ...(logo ? [logo.light, logo.dark] : []),
        ...(splash?.logo ? [splash.logo] : []),
      ].filter((a) => a.trim().length > 0),
    ),
  ];

  for (const a of assets) {
    if (a.includes('/') || a.includes('\\')) {
      note('lint', 'assets', `'${a}' is not a bare filename. Installed packs are flat, so this resolves against nothing once downloaded.`);
    }
  }
  if (wallpapers.length === 0) {
    note('default', 'wallpapers', 'None, so the previous wallpaper stays on screen when this theme is chosen.');
  }

  return {
    id: id ?? '',
    name: name ?? '',
    version,
    shell,
    tier,
    chromeFamily,
    palette,
    typography,
    layout,
    icons,
    wallpapers,
    minAppVersion,
    logo,
    boot,
    splash,
    desklets,
    assets,
    notes,
  };
}

// ── narrowing helpers ───────────────────────────────────────────────────────

function obj(v: unknown): Record<string, unknown> | null {
  return v && typeof v === 'object' && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : null;
}

function isShell(v: string | null): v is ShellName {
  return v === 'gnome' || v === 'plasma' || v === 'tiling' || v === 'tui' || v === 'aqua';
}

function isChrome(v: string | null): v is ChromeName {
  return v === 'adwaita' || v === 'breeze' || v === 'aqua' || v === 'generic';
}

function isTreatment(v: string | null): v is TreatmentName {
  return v !== null && (TREATMENTS as readonly string[]).includes(v);
}

function isBootKind(v: string | null): v is BootKind {
  return v !== null && (BOOT_KINDS as readonly string[]).includes(v);
}

function isSplashStyle(v: string | null): v is SplashStyleName {
  return v !== null && (SPLASH_STYLES as readonly string[]).includes(v);
}
