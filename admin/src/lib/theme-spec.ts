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
export const ICON_TREATMENTS = ['roundedSquare', 'squircle', 'circle', 'none'] as const;
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

// ── reading a theme.json back ────────────────────────────────────────────────

/**
 * A theme.json, read for the ONE question the flat-path gate asks: which files
 * does this theme reference?
 *
 * DELIBERATELY NOT A FULL PARSER. `canonicalThemeJson` writes; this reads, and
 * the only reader is `flat-check.ts`, which needs the asset references and
 * nothing else. Validating every field here would mean a second, weaker copy of
 * `ThemeSpec.fromJson` that drifts from the Dart one and starts refusing packs
 * the device would have rendered perfectly.
 *
 * So the rule is: unknown shapes are IGNORED, never rejected. A newer theme.json
 * carrying a block this build has never heard of parses fine and simply
 * contributes no assets, which matches how the app treats the same file.
 *
 * The `error` arm exists only for input that is not a JSON object at all.
 */
export interface ParsedTheme {
  id: string;
  /** Every file path the theme references: wallpapers, logo, splash logo. */
  assets: string[];
}

export function parseTheme(value: unknown): ParsedTheme | { error: string } {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'theme.json is not a JSON object' };
  }
  const j = value as Record<string, unknown>;

  const assets: string[] = [];
  const push = (v: unknown) => {
    if (typeof v === 'string' && v.trim()) assets.push(v.trim());
  };

  // wallpapers: the current shape.
  if (Array.isArray(j.wallpapers)) for (const w of j.wallpapers) push(w);

  // wallpaper.asset: the old single-wallpaper shape. Still read by
  // ThemeSpec._wallpapers on device, so a theme using it is not malformed and
  // its path still has to be flat.
  const legacy = j.wallpaper;
  if (legacy && typeof legacy === 'object') {
    push((legacy as Record<string, unknown>).asset);
  }

  // logo: a bare string, or { light, dark }.
  const logo = j.logo;
  if (typeof logo === 'string') {
    push(logo);
  } else if (logo && typeof logo === 'object') {
    const l = logo as Record<string, unknown>;
    push(l.light);
    push(l.dark);
  }

  // splash.logo, when a splash block names artwork rather than a built-in
  // style. Guarded rather than assumed: a splash with no logo key contributes
  // nothing and costs nothing.
  const splash = j.splash;
  if (splash && typeof splash === 'object') {
    push((splash as Record<string, unknown>).logo);
  }

  // De-duplicated, because a theme naming the same wallpaper twice would
  // otherwise report the same fix twice.
  return {
    id: typeof j.id === 'string' ? j.id : '',
    assets: [...new Set(assets)],
  };
}
