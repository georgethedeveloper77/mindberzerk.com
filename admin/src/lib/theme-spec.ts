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

export type ShellName = 'gnome' | 'plasma' | 'tiling' | 'tui' | 'aqua';
export type ChromeName = 'adwaita' | 'breeze' | 'aqua' | 'generic';
export type TierName = 'free' | 'pro';
export type DockName = 'left' | 'bottom' | 'off';

export const SHELLS: ShellName[] = ['gnome', 'plasma', 'tiling', 'tui', 'aqua'];
export const CHROMES: ChromeName[] = ['adwaita', 'breeze', 'aqua', 'generic'];
export const DOCKS: DockName[] = ['left', 'bottom', 'off'];

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

export interface ThemeLayoutJson {
  dock: DockName;
  topBar: boolean;
  grid?: { rows: number; cols: number };
  iconScale?: number;
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
  typography?: ThemeTypographyJson | null;
  layout: ThemeLayoutJson;
  icons?: IconStyleJson | null;
  logo?: unknown;
  wallpapers: string[];
  minAppVersion: number;
  boot?: unknown;
  splash?: unknown;
  desklets?: unknown;
  /** Editor hint only, never emitted to the payload. */
  seededFromPreview?: boolean;
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

  if (spec.typography && (spec.typography.display || spec.typography.mono)) {
    const t: Record<string, string> = {};
    if (spec.typography.display) t.display = spec.typography.display;
    if (spec.typography.mono) t.mono = spec.typography.mono;
    out.typography = t;
  }

  out.layout = {
    dock: spec.layout.dock,
    topBar: spec.layout.topBar,
    ...(spec.layout.grid
      ? { grid: { rows: spec.layout.grid.rows, cols: spec.layout.grid.cols } }
      : {}),
    ...(spec.layout.iconScale != null ? { iconScale: spec.layout.iconScale } : {}),
  };

  if (spec.icons && Object.keys(pruneIcons(spec.icons)).length) {
    out.icons = pruneIcons(spec.icons);
  }
  if (spec.logo != null) out.logo = spec.logo;
  if (spec.wallpapers && spec.wallpapers.length) out.wallpapers = spec.wallpapers;
  if (spec.minAppVersion) out.minAppVersion = spec.minAppVersion;
  if (spec.boot != null) out.boot = spec.boot;
  if (spec.splash != null) out.splash = spec.splash;
  if (spec.desklets != null) out.desklets = spec.desklets;

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
    layout: {
      dock: (DOCKS as string[]).includes(str(layoutRaw.dock) ?? '')
        ? (str(layoutRaw.dock) as DockName)
        : base.layout.dock,
      topBar:
        typeof layoutRaw.topBar === 'boolean' ? layoutRaw.topBar : base.layout.topBar,
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
    },
    wallpapers,
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

  // Keys nothing reads. Usually a typo, occasionally a field from a newer
  // build, and either way worth naming: the device ignores both silently.
  const known = new Set([
    'id', 'name', 'version', 'shell', 'tier', 'chromeFamily', 'palette',
    'typography', 'layout', 'icons', 'logo', 'wallpapers', 'wallpaper',
    'minAppVersion', 'boot', 'splash', 'desklets',
  ]);
  const unknownKeys = Object.keys(j).filter((k) => !known.has(k));
  if (unknownKeys.length) {
    notes.push(`Ignored ${unknownKeys.length} key(s) nothing reads: ${unknownKeys.join(', ')}. A typo and a field from a newer build look the same here.`);
  }

  return { spec, notes };
}
