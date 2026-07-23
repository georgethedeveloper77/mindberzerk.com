/**
 * PHASE C5 — theme.json, parsed the way the launcher parses it.
 *
 * ## Why this file exists
 *
 * `ThemeSpec.fromJson` is FORGIVING BY DESIGN. Every field has a fallback, an
 * unknown enum degrades to a sane default rather than throwing, and a theme from
 * a newer CDN than the app looks slightly wrong instead of crashing the home
 * screen. That is the right behaviour on a phone and it is a terrible property
 * for an editor, because a misspelled key and a correct one produce the same
 * silent result.
 *
 * So this parses the same JSON and records WHAT IT HAD TO DO: which keys were
 * absent and took a default, which values it did not recognise and degraded, and
 * which paths will not resolve once the pack is downloaded rather than bundled.
 *
 * ## It must stay field-for-field with the Dart
 *
 * `lib/engine/theme_spec.dart` is the source of truth. Every default below is
 * copied from it, including the exact fallback colours. When a field is added
 * there it has to be added here, or the panel will report a theme as complete
 * while the phone silently defaults it — which is the same class of failure as
 * forgetting a field in `IconCache.fingerprint()`.
 *
 * NO `server-only`: the builder form will import this in the browser.
 */

export const SHELLS = ['gnome', 'plasma', 'tiling', 'tui', 'aqua'] as const;
export type Shell = (typeof SHELLS)[number];

export const TREATMENTS = [
  'roundedSquare',
  'circle',
  'squircle',
  'square',
  'teardrop',
  'original',
] as const;

export const CHROME_FAMILIES = ['adwaita', 'breeze', 'aqua', 'generic'] as const;

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

export const SPLASH_STYLES = ['dots', 'bar', 'spinner', 'text', 'none'] as const;

/**
 * What the parser had to do to make sense of the file.
 *
 *  default   the key was absent and a fallback was used. Usually fine, but it
 *            is the difference between "authored black" and "never authored".
 *  degraded  the key was present with a value this build does not know. The
 *            phone will render something, just not what the file says.
 *  lint      it parses and it is legal, and it will still not work on a device.
 *  error     it does not parse at all.
 */
export type NoteLevel = 'default' | 'degraded' | 'lint' | 'error';

export interface Note {
  level: NoteLevel;
  /** Dotted path into the JSON, e.g. `icons.cornerRadius`. */
  path: string;
  message: string;
}

export interface ParsedTheme {
  id: string;
  name: string;
  /** A DISPLAY string like "24.04". Not the pack version, which is an integer. */
  version: string;
  shell: Shell;
  chromeFamily: string;
  tier: string;
  minAppVersion: number;
  palette: Record<string, string>;
  typography: { display: string | null; mono: string | null };
  layout: {
    dock: 'left' | 'bottom' | 'off';
    topBar: boolean;
    rows: number;
    cols: number;
    iconScale: number;
  };
  icons: {
    treatment: string;
    cornerRadius: number;
    foregroundScale: number;
    backgroundColor: string | null;
    backgroundGradientEnd: string | null;
    gradientAngle: number | null;
    monochromeTint: string | null;
    heroPack: string | null;
    brandPack: string | null;
    brandTreatment: string | null;
  };
  wallpapers: string[];
  logo: { light: string; dark: string } | null;
  boot: { tailMs: number; lines: { kind: string; text: string; delayMs: number | null }[] } | null;
  splash: { style: string; durationMs: number } | null;
  desklets: { offers: string[]; starter: unknown[]; skins: string[] };
  /** Every asset path the theme references, for cross-checking the manifest. */
  assets: string[];
  notes: Note[];
}

/** The shell a chrome family defaults to. Mirrors ChromeFamily.defaultForShell. */
export function chromeForShell(shell: Shell): string {
  switch (shell) {
    case 'gnome':
      return 'adwaita';
    case 'plasma':
      return 'breeze';
    case 'aqua':
      return 'aqua';
    default:
      return 'generic';
  }
}

/** Accepts "#RRGGBB" and "#AARRGGBB", same as parseColor in the Dart. */
export function parseColour(hex: unknown): string | null {
  if (typeof hex !== 'string') return null;
  let s = hex.replace('#', '').trim();
  if (s.length === 6) s = `FF${s}`;
  if (s.length !== 8) return null;
  if (!/^[0-9a-f]{8}$/i.test(s)) return null;
  return `#${s.toUpperCase()}`;
}

/** #AARRGGBB to a CSS colour, since the browser wants alpha last. */
export function toCss(argb: string | null): string | undefined {
  if (!argb) return undefined;
  const s = argb.replace('#', '');
  if (s.length !== 8) return undefined;
  return `#${s.slice(2)}${s.slice(0, 2)}`;
}

export function parseTheme(raw: unknown): ParsedTheme | { error: string } {
  if (typeof raw !== 'object' || raw === null) {
    return { error: 'theme.json is not an object' };
  }
  const j = raw as Record<string, unknown>;
  const notes: Note[] = [];
  const assets: string[] = [];

  const note = (level: NoteLevel, path: string, message: string) =>
    notes.push({ level, path, message });

  // A missing id or name throws in the Dart, so it is an error here rather than
  // a note. Everything below this line has a fallback.
  if (typeof j.id !== 'string') return { error: 'id is missing or not a string' };
  if (typeof j.name !== 'string') return { error: 'name is missing or not a string' };

  const shellRaw = j.shell;
  const shell: Shell = (SHELLS as readonly unknown[]).includes(shellRaw)
    ? (shellRaw as Shell)
    : 'gnome';
  if (shellRaw === undefined) note('default', 'shell', 'absent, rendering as gnome');
  else if (shell !== shellRaw)
    note('degraded', 'shell', `"${String(shellRaw)}" is unknown, rendering as gnome`);

  const familyRaw = j.chromeFamily;
  let chromeFamily = chromeForShell(shell);
  if (typeof familyRaw === 'string') {
    if ((CHROME_FAMILIES as readonly string[]).includes(familyRaw)) chromeFamily = familyRaw;
    else
      note(
        'degraded',
        'chromeFamily',
        `"${familyRaw}" is unknown, falling back to the ${shell} default`,
      );
  }

  // ── palette ───────────────────────────────────────────────────────────────
  // PALETTE IS THE ONE BLOCK THAT IS NOT OPTIONAL. Every other field in
  // ThemeSpec.fromJson has a fallback, but the palette line reads
  // `(json['palette'] as Map)` with no `?`, so a theme without one throws a
  // TypeError and never loads. It is an error here, not a note.
  //
  // The per-KEY defaults below are still real: ThemePalette.fromJson falls back
  // field by field, so a palette block missing `bar` is wearing Ubuntu's bar
  // colour rather than failing.
  const paletteDefaults: Record<string, string> = {
    bgTop: '#FF2C0A22',
    bgBottom: '#FF220817',
    bar: '#FF1A171B',
    dock: '#BD201B21',
    accent: '#FFE95420',
    onDark: '#FFFFFFFF',
  };
  if (typeof j.palette !== 'object' || j.palette === null) {
    return {
      error:
        'palette is missing. Unlike every other block it has no fallback, so the theme throws on load and the launcher falls back to Ubuntu.',
    };
  }
  const paletteIn = j.palette as Record<string, unknown>;
  const palette: Record<string, string> = {};
  for (const [key, fallback] of Object.entries(paletteDefaults)) {
    const parsed = parseColour(paletteIn[key]);
    palette[key] = parsed ?? fallback;
    if (paletteIn[key] === undefined) {
      note('default', `palette.${key}`, `absent, using ${fallback}`);
    } else if (!parsed) {
      note('degraded', `palette.${key}`, `"${String(paletteIn[key])}" is not a colour`);
    }
  }

  // ── typography ────────────────────────────────────────────────────────────
  const typoIn = (j.typography ?? {}) as Record<string, unknown>;
  const typography = {
    display: typeof typoIn.display === 'string' ? typoIn.display : null,
    mono: typeof typoIn.mono === 'string' ? typoIn.mono : null,
  };

  // ── layout ────────────────────────────────────────────────────────────────
  const layoutIn = (j.layout ?? {}) as Record<string, unknown>;
  const gridIn = (layoutIn.grid ?? {}) as Record<string, unknown>;

  const dockRaw = layoutIn.dock;
  const dock = dockRaw === 'bottom' ? 'bottom' : dockRaw === 'off' ? 'off' : 'left';
  if (dockRaw !== undefined && dockRaw !== dock)
    note('degraded', 'layout.dock', `"${String(dockRaw)}" is unknown, using left`);

  // IconSizing.parseScale clamps to 0.7–1.4. Downloaded content that drives
  // layout gets validated, so a theme asking for 3.0 is not refused, it is
  // quietly pinned — which looks identical to the field being ignored.
  const scaleRaw = layoutIn.iconScale;
  let iconScale = typeof scaleRaw === 'number' ? scaleRaw : 1.0;
  if (typeof scaleRaw === 'number' && (scaleRaw < 0.7 || scaleRaw > 1.4)) {
    iconScale = Math.min(1.4, Math.max(0.7, scaleRaw));
    note('degraded', 'layout.iconScale', `${scaleRaw} is outside 0.7–1.4, clamped to ${iconScale}`);
  }

  const layout = {
    dock: dock as 'left' | 'bottom' | 'off',
    topBar: typeof layoutIn.topBar === 'boolean' ? layoutIn.topBar : true,
    rows: typeof gridIn.rows === 'number' ? Math.trunc(gridIn.rows) : 5,
    cols: typeof gridIn.cols === 'number' ? Math.trunc(gridIn.cols) : 4,
    iconScale,
  };

  // ── icons ─────────────────────────────────────────────────────────────────
  const iconsIn = (j.icons ?? {}) as Record<string, unknown>;
  if (j.icons === undefined) note('default', 'icons', 'absent, every app gets the generator');

  const treatRaw = iconsIn.treatment;
  const treatment = (TREATMENTS as readonly unknown[]).includes(treatRaw)
    ? (treatRaw as string)
    : 'roundedSquare';
  if (treatRaw !== undefined && treatment !== treatRaw)
    note('degraded', 'icons.treatment', `"${String(treatRaw)}" is unknown, using roundedSquare`);

  // cornerRadius is a FRACTION of the tile, not pixels and not a percentage.
  // 0.22 is the authored Ubuntu value; anything above 0.5 is a circle and
  // anything above 1 is almost certainly someone typing 22.
  const radiusRaw = iconsIn.cornerRadius;
  const cornerRadius = typeof radiusRaw === 'number' ? radiusRaw : 0.22;
  if (cornerRadius > 1)
    note(
      'lint',
      'icons.cornerRadius',
      `${cornerRadius} is a fraction of the tile, not pixels. 0.22 is the Ubuntu value`,
    );

  const icons = {
    treatment,
    cornerRadius,
    foregroundScale:
      typeof iconsIn.foregroundScale === 'number' ? iconsIn.foregroundScale : 1.0,
    backgroundColor: parseColour(iconsIn.backgroundColor),
    backgroundGradientEnd: parseColour(iconsIn.backgroundGradientEnd),
    gradientAngle: typeof iconsIn.gradientAngle === 'number' ? iconsIn.gradientAngle : null,
    monochromeTint: parseColour(iconsIn.monochromeTint),
    heroPack: typeof iconsIn.heroPack === 'string' ? iconsIn.heroPack : null,
    brandPack: typeof iconsIn.brandPack === 'string' ? iconsIn.brandPack : null,
    brandTreatment:
      typeof iconsIn.brandTreatment === 'string' ? iconsIn.brandTreatment : null,
  };

  if (icons.backgroundGradientEnd && icons.backgroundColor === null)
    note('lint', 'icons.backgroundGradientEnd', 'a gradient end with no start draws nothing');
  if (icons.heroPack && !icons.brandPack)
    note(
      'lint',
      'icons.brandPack',
      'no brand pack, so every app the hero pack misses falls straight to the generator',
    );

  // ── wallpapers, logo ──────────────────────────────────────────────────────
  let wallpapers: string[] = [];
  if (Array.isArray(j.wallpapers)) {
    wallpapers = j.wallpapers.filter((w): w is string => typeof w === 'string');
  } else {
    // The legacy single-wallpaper shape is still read, so a theme already on
    // someone's phone does not stop working because the manifest changed.
    const legacy = (j.wallpaper as Record<string, unknown> | undefined)?.asset;
    if (typeof legacy === 'string') {
      wallpapers = [legacy];
      note('lint', 'wallpaper', 'the old single-wallpaper shape. Move it to a wallpapers array');
    }
  }
  assets.push(...wallpapers);

  let logo: { light: string; dark: string } | null = null;
  if (typeof j.logo === 'string') logo = { light: j.logo, dark: j.logo };
  else if (typeof j.logo === 'object' && j.logo !== null) {
    const m = j.logo as Record<string, unknown>;
    const light = typeof m.light === 'string' ? m.light : undefined;
    const dark = typeof m.dark === 'string' ? m.dark : undefined;
    const base = light ?? dark;
    if (base) logo = { light: light ?? base, dark: dark ?? base };
  }
  if (logo) assets.push(logo.light, logo.dark);

  // ── boot, splash ──────────────────────────────────────────────────────────
  let boot: ParsedTheme['boot'] = null;
  if (typeof j.boot === 'object' && j.boot !== null) {
    const b = j.boot as Record<string, unknown>;
    const linesIn = Array.isArray(b.lines) ? b.lines : [];
    boot = {
      tailMs: typeof b.tailMs === 'number' ? b.tailMs : 0,
      lines: linesIn.map((l, i) => {
        const line = (l ?? {}) as Record<string, unknown>;
        const kind = typeof line.kind === 'string' ? line.kind : 'plain';
        if (!(BOOT_KINDS as readonly string[]).includes(kind))
          note('degraded', `boot.lines[${i}].kind`, `"${kind}" is unknown, rendering as plain`);
        return {
          kind,
          text: typeof line.text === 'string' ? line.text : '',
          delayMs: typeof line.delayMs === 'number' ? line.delayMs : null,
        };
      }),
    };
  } else {
    note('default', 'boot', `absent, using the ${shell} default log`);
  }

  let splash: ParsedTheme['splash'] = null;
  if (typeof j.splash === 'object' && j.splash !== null) {
    const s = j.splash as Record<string, unknown>;
    const style = typeof s.style === 'string' ? s.style : 'dots';
    if (!(SPLASH_STYLES as readonly string[]).includes(style))
      note('degraded', 'splash.style', `"${style}" is unknown`);
    // Clamped 400–1500 in the SplashSpec constructor.
    const raw = typeof s.durationMs === 'number' ? s.durationMs : 900;
    const durationMs = Math.min(1500, Math.max(400, raw));
    if (durationMs !== raw)
      note('degraded', 'splash.durationMs', `${raw} is outside 400–1500, clamped to ${durationMs}`);
    splash = { style, durationMs };
  } else {
    note('default', 'splash', `absent, using the ${shell} default`);
  }

  // ── desklets ──────────────────────────────────────────────────────────────
  const deskIn = (j.desklets ?? {}) as Record<string, unknown>;
  const desklets = {
    offers: Array.isArray(deskIn.offers)
      ? deskIn.offers.filter((o): o is string => typeof o === 'string')
      : [],
    starter: Array.isArray(deskIn.starter) ? deskIn.starter : [],
    skins:
      typeof deskIn.skins === 'object' && deskIn.skins !== null
        ? Object.keys(deskIn.skins as object)
        : [],
  };
  if (j.desklets === undefined)
    note('default', 'desklets', 'absent, the desktop starts empty and offers the shell default');

  return {
    id: j.id,
    name: j.name,
    version: typeof j.version === 'string' ? j.version : '',
    shell,
    chromeFamily,
    tier: typeof j.tier === 'string' ? j.tier : 'free',
    minAppVersion: typeof j.minAppVersion === 'number' ? Math.trunc(j.minAppVersion) : 0,
    palette,
    typography,
    layout,
    icons,
    wallpapers,
    logo,
    boot,
    splash,
    desklets,
    assets,
    notes,
  };
}

/**
 * Paths that will not resolve once the theme arrives over the CDN.
 *
 * THIS IS THE ONE THAT GATES PAID PACKS, and the launcher source makes it
 * sharper than "relative vs absolute". `PackPaths.installedFile` resolves a
 * downloaded asset as `packs/<packId>/<filename>` and REFUSES any filename
 * containing a slash at all:
 *
 *     if (filename.contains('/') ...) return null
 *
 * So a bundled theme, read through the Flutter asset bundle, can say
 * `assets/themes/ubuntu-24-04/wallpapers/numbat.webp`, and the SAME string in a
 * downloaded pack resolves against nothing — not because it is absolute, but
 * because it has slashes in it. Even a tidy relative `wallpapers/numbat.webp`
 * fails on device. A downloaded pack is flat.
 *
 * [absolutePaths] is kept for the inspector's softer warning on already-
 * published themes; [unflatPaths] is the publish-time gate.
 */
export function absolutePaths(assets: string[]): string[] {
  return assets.filter((a) => a.startsWith('/') || a.startsWith('assets/'));
}

/**
 * Asset references that a downloaded pack cannot resolve: anything with a path
 * separator, because the installed layout is one flat directory per pack.
 * Returns the offending references, each paired with the bare filename it would
 * have to become.
 */
export function unflatPaths(assets: string[]): { ref: string; flat: string }[] {
  return assets
    .filter((a) => a.includes('/') || a.includes('\\'))
    .map((ref) => ({ ref, flat: ref.split(/[\\/]/).pop() ?? ref }));
}
