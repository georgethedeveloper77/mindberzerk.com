'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { BuilderShell, useToast } from '@/components/console';
import { Section, Field, TextInput, NumberInput, SelectInput, Segmented, Toggle, FontSelect } from '@/components/theme-builder/primitives';
import { PaletteEditor, LayoutEditor, GesturesEditor, IconStyleEditor, PassthroughEditor } from '@/components/theme-builder/editors';
import { ThemePreview } from '@/components/theme-builder/ThemePreview';
import { GeneratedJson } from '@/components/theme-builder/GeneratedJson';
import { AppGrid, type Assignment } from './AppGrid';
import { FeatureRowsEditor } from './FeatureRowsEditor';
import { composeIcon, type ComposeSpec } from '@/lib/g-launcher/icon-compose';
import { glyphToBlob, type GlyphLite } from '@/lib/g-launcher/glyph-blob';
import { GlyphPicker, IconStyleBar } from '@/app/components/icon-compose-bar';
import { IconContactSheet } from '@/app/components/icon-contact-sheet';
import { IconSetHealth } from '@/app/components/icon-set-health';
import { renderHeroIcon } from '@/lib/core/image-trim';
import { publishDistroAction, saveDistroDraftAction } from '@/app/apps/[app]/distros/actions';
import { PREVIEW_NAME, composePreviewPng } from '@/lib/g-launcher/pack-preview';
import { importDiff, replacedBlocks } from '@/lib/g-launcher/import-diff';
import {
  blankDraft,
  importTheme,
  isSafePackId,
  validateDraft,
  type ChromeName,
  type ShellName,
  type ThemeDraft,
  type ThemeFeatureJson,
  type ThemeSpecJson,
  CHROMES,
  SHELLS,
  WALLPAPER_FITS,
  canonWallpaperMeta,
  type WallpaperFit,
  type WallpaperMetaJson,
} from '@/lib/g-launcher/theme-spec';
import { COMMON_APPS, isBareFilename, validateHeroPack, type HeroIconEntry, expandRoleEntries, roleForPackage } from '@/lib/g-launcher/hero-pack';
import { playSkuNote, type PlayLite } from '@/lib/core/play-lite';
import { SKU_PREFIX, distroSkuFor, iconsSkuFor, skuProblems } from '@/lib/core/skus';

/**
 * Did the opened theme reference any wallpaper, and any logo.
 *
 * REPLACES `assetNamesOf`, which returned the bare FILENAMES a theme referenced
 * so they could be matched one-for-one against what the author uploaded. That
 * match could never succeed AT THE TIME: wallpaper uploads were renamed to
 * `wall_<timestamp>` while the references were authored names, so a theme that
 * already had wallpapers had its publish button disabled forever. Names are no
 * longer compared; only presence is, per kind. Uploads now KEEP their names
 * (see [wallpaperNameFor]), but that does not resurrect the name match: an
 * author re-uploading under a different name is legitimate, `effectiveSpec`
 * follows the uploads, and presence remains the honest guard.
 *
 * ─── WHAT PRESENCE STILL HAS TO CATCH ────────────────────────────────────────
 *
 * `effectiveSpec` rewrites `wallpapers` and `logo` from the UPLOADED files,
 * unconditionally. Open Ubuntu, change the accent colour, publish without ever
 * opening the assets tab, and `wallpapers` becomes `[]` and `logo` becomes
 * undefined. The pack publishes cleanly. The flat-path gate cannot fire, because
 * there are no paths left to be unflat. Every device that installs it gets a
 * distro with no wallpaper and the Mindhunter fallback mark, and nothing
 * anywhere reports a problem.
 *
 * So the two booleans below are not a weaker version of the name match. They are
 * the whole of what the name match was actually protecting: dropping references
 * silently. A published wallpaper being called `wall_ms34zzni.webp` instead of
 * `numbat_color.webp` costs a clean diff against the bundled copy. Shipping no
 * wallpaper at all costs a broken distro on every phone that installs it.
 *
 * ─── SPLASH IS DELIBERATELY NOT GUARDED ──────────────────────────────────────
 *
 * `assetNamesOf` also required `splash.logo`, and there is no uploader for it:
 * `splash` is passthrough JSON edited as text, with no file slot anywhere in
 * this workspace. Requiring it made every theme carrying one unpublishable for
 * the same reason the wallpapers were, which is the bug being fixed here rather
 * than a second one to preserve. `effectiveSpec` does not rewrite `splash`
 * either, so the reference survives publish untouched. It can therefore ship
 * pointing at a file that was never uploaded. That is a real gap and it is not
 * closed here, because closing it means giving splash a file slot, which is a
 * change to what the workspace can edit and not to this guard.
 */
function referencesWallpaper(spec: ThemeSpecJson): boolean {
  return (spec.wallpapers ?? []).some((w) => typeof w === 'string' && w.trim() !== '');
}

function referencesLogo(spec: ThemeSpecJson): boolean {
  const logo = spec.logo;
  if (typeof logo === 'string') return logo.trim() !== '';
  if (logo && typeof logo === 'object') {
    const l = logo as Record<string, unknown>;
    return [l.light, l.dark].some((v) => typeof v === 'string' && v.trim() !== '');
  }
  return false;
}

interface Asset {
  name: string;
  blob: Blob;
  url: string;
}

/**
 * Decode one `data:` URL into a Blob, synchronously.
 *
 * Synchronous is the point, same as the icon builder's copy: a saved draft
 * becomes real assets inside a `useState` initialiser, with no effect, no
 * loading state and no frame in which the workspace is mounted but empty.
 */
function blobFromDataUrl(dataUrl: string): Blob {
  const comma = dataUrl.indexOf(',');
  const head = dataUrl.slice(0, comma);
  const mime = /:(.*?);/.exec(head)?.[1] ?? 'image/png';
  const binary = atob(dataUrl.slice(comma + 1));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

/** A rehydrated draft asset as workspace state. The data URL is a valid `src`,
 *  so nothing needs `URL.createObjectURL` and there is no handle to revoke. */
function assetFromDataUrl(name: string, dataUrl: string): Asset {
  return { name, blob: blobFromDataUrl(dataUrl), url: dataUrl };
}

/**
 * The logo filenames a spec references, if any.
 *
 * `ThemeSpecJson.logo` is deliberately `unknown`: it is passthrough JSON the
 * importer never fills with defaults, so the names are narrowed here rather
 * than trusted. A hand-written draft can put anything in that block, and
 * anything that is not a string simply is not a logo filename.
 */
function logoNamesOf(
  spec: ThemeSpecJson | null | undefined,
): { light: string | null; dark: string | null } {
  const raw = spec?.logo;
  if (!raw || typeof raw !== 'object') return { light: null, dark: null };
  const o = raw as { light?: unknown; dark?: unknown };
  return {
    light: typeof o.light === 'string' ? o.light : null,
    dark: typeof o.dark === 'string' ? o.dark : null,
  };
}

type Tab = 'theme' | 'icons' | 'pricing';

/**
 * Recover the distro id from a theme pack id.
 *
 * ONE suffix, and only at the end. A distro legitimately named `plasma-theme`
 * would round-trip through here as `plasma`, which is why this is a suffix
 * strip rather than a replace: the alternative eats the word wherever it
 * appears and renames the distro.
 */
function stripThemeSuffix(id: string): string {
  return id.endsWith('-theme') ? id.slice(0, -'-theme'.length) : id;
}

const shellLabels: Record<ShellName, string> = {
  gnome: 'GNOME',
  plasma: 'Plasma',
  tiling: 'Tiling',
  tui: 'Terminal',
  aqua: 'Aqua',
};

function extFor(file: File): string {
  const m = /\.([a-zA-Z0-9]+)$/.exec(file.name);
  const raw = (m ? m[1] : file.type.split('/')[1] || 'webp').toLowerCase();
  return raw.replace(/[^a-z0-9]/g, '') || 'webp';
}

/**
 * OPTION A OF THE UPLOADER NAMING DECISION: an upload keeps its own name.
 *
 * A wallpaper used to be renamed to `wall_<timestamp>.<ext>` on the way in.
 * With the presence guard replacing the name match, that rename no longer
 * deadlocks publish, but it still costs two real things:
 *
 *   - `effectiveSpec` writes `wallpapers` from the uploads, so every published
 *     theme.json carried opaque timestamp names and could never diff cleanly
 *     against the bundled copy it came from.
 *   - `effectiveSpec` does NOT rewrite `splash`, so a `splash.logo` reference
 *     had to match an uploaded name exactly, and no upload could EVER match an
 *     authored name, because this function destroyed it. The flat gate then
 *     refused the pack at publish with nothing the author could do about it
 *     from this screen. Keeping the name is what makes that reference
 *     satisfiable at all.
 *
 * The name is sanitised to the bare-filename contract the device enforces
 * (`PackPaths.installedFile` refuses separators; runs of dots would smuggle
 * `..`): path stripped, whitespace to underscores, anything outside
 * [A-Za-z0-9._-] dropped, dot runs collapsed, edge punctuation trimmed. Case
 * is kept, because the point is matching the file the author manages. Only
 * when nothing survives sanitising does the timestamp name return as a
 * fallback, and `isBareFilename` gates the result so this function cannot
 * drift from the validator the icon path already trusts.
 */
function wallpaperNameFor(file: File): string {
  // Two unnamed files picked in the same batch resolve in the same millisecond,
  // so the timestamp alone would give them one name and the second would
  // silently replace the first. Only reached when a file has no usable stem.
  const fallback = `wall_${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 6)}.${extFor(file)}`;
  const base = file.name.split(/[\\/]/).pop() ?? '';
  const dot = base.lastIndexOf('.');
  const stem = (dot > 0 ? base.slice(0, dot) : base)
    .replace(/\s+/g, '_')
    .replace(/[^A-Za-z0-9._-]/g, '')
    .replace(/\.{2,}/g, '.')
    .replace(/^[._-]+|[._-]+$/g, '');
  if (!stem) return fallback;
  const name = `${stem}.${extFor(file)}`;
  return isBareFilename(name) ? name : fallback;
}

/**
 * Add an asset, or replace the one already holding its name.
 *
 * Under kept names, the name IS the identity: uploading `numbat_color.webp`
 * again means "use this file for numbat_color", exactly as re-picking a logo
 * slot does, so the second upload replaces the first in place rather than
 * shipping two files whose FormData keys would collide anyway. The replaced
 * preview URL is revoked; nothing else holds it.
 */
function upsertAsset(list: Asset[], a: Asset): Asset[] {
  const prev = list.find((x) => x.name === a.name);
  if (!prev) return [...list, a];
  URL.revokeObjectURL(prev.url);
  return list.map((x) => (x.name === a.name ? a : x));
}

export function DistroWorkspace({
  app,
  initial = null,
  initialAssets = [],
  initialIcons = null,
  rehydrateNotes = [],
  heroPacks = [],
  heroPacksUnreadable = false,
  play,
}: {
  /**
   * The draft's saved wallpapers and logos, read back off `admin/distro-drafts/`
   * and inlined as data URLs on the server. Without this the bytes were SAVED
   * faithfully and never read again: every reopen showed empty asset slots over
   * a spec that still referenced them.
   */
  initialAssets?: { file: string; dataUrl: string }[];
  /** The distro's own icon-pack draft (`<base>-icons`), if one was saved. */
  initialIcons?: { name: string; icons: { pkg: string; file: string; dataUrl: string }[] } | null;
  /** Assets the server could not read back. Shown, never silently dropped. */
  rehydrateNotes?: string[];
  app: string;
  /**
   * An existing draft to open, or null for a new distro.
   *
   * Read on the SERVER and passed down, so every `useState` below initialises
   * with the real value on first render. Loading it in an effect instead would
   * mount the whole form blank and correct it a frame later, and a builder that
   * flashes an empty palette before filling in is one you check twice.
   */
  initial?: ThemeDraft | null;

  /**
   * Hero packs already in the live index, for the "use published" source.
   *
   * Read on the server for the same reason `initial` is. Empty when nothing is
   * published AND when the bucket could not be read, which are different facts
   * with the same shape, so [heroPacksUnreadable] carries the difference: a
   * picker saying "nothing published yet" when the truth is "we could not look"
   * invites someone to build a second copy of a pack that already exists.
   */
  heroPacks?: { packId: string; title: string; sku: string | null }[];
  heroPacksUnreadable?: boolean;

  /**
   * What Play actually sells, slimmed. Read on the server like everything
   * else. `ok: false` degrades the sku fields to plain text inputs with the
   * reason: pricing must stay editable when the reporting API is down, and an
   * unreachable Play is a different fact from a missing product.
   */
  play: PlayLite;
}) {
  const [tab, setTab] = React.useState<Tab>('theme');

  /**
   * BUNDLED DISTROS PUBLISH UNDER THEIR OWN BARE ID.
   *
   * The theme baked into the APK is `ubuntu-24-04`, and the launcher's catalog
   * pairs a CDN pack with a bundled theme BY ID. Suffixing `-theme` here
   * published `ubuntu-24-04-theme`, which paired with nothing: the Distros list
   * grew a second Ubuntu, and no device could ever receive the update because
   * the pack it downloaded did not name the theme it was meant to replace.
   *
   * So the suffix convention applies only to distros born in this workspace.
   * A draft that arrived with `bundled: true` keeps its APK id end to end.
   */
  const isBundled = initial?.bundled === true;

  // The distro id, from which both pack ids and both SKUs derive. An existing
  // theme's pack id IS that id, so opening one seeds it and every derived
  // field falls out unchanged.
  /**
   * THE DRAFT ID IS THE THEME PACK ID, AND `base` IS NOT.
   *
   * `themeDraft.id` is `${base}-theme` on purpose: it has to equal the packId
   * the publish writes, or `mergeThemeRows` cannot pair a draft with the pack it
   * became and the Distros list shows the same distro twice.
   *
   * The inverse was missing. Hydrating `base` straight from `initial.id` fed a
   * pack id into the field that DERIVES pack ids, so reopening a saved draft
   * produced `linux-mint-22-theme-theme` and, on publish, a theme.json whose
   * `id` no longer equalled its `packId`. That mismatch is the silent one: the
   * pack installs, inherits the bundled theme's preferences bucket, and the
   * wallpaper never applies with nothing reported anywhere.
   *
   * Seeded bundled drafts carry a bare id (`ubuntu-24-04`), so stripping only a
   * trailing `-theme` is correct for both shapes.
   */
  const [base, setBase] = React.useState(() => stripThemeSuffix(initial?.id ?? ''));

  const [spec, setSpec] = React.useState<ThemeSpecJson>(
    // THROUGH `importTheme`, NOT the draft's spec directly. A draft read back
    // out of R2 was written by an older build, by a script, or by hand, so it
    // is untrusted input in exactly the way a downloaded theme.json is. The
    // importer fills only what the file actually contains and leaves absent
    // keys absent, which is what stops an edit to the palette from silently
    // writing out today's defaults for every block the author never touched.
    () => {
      if (!initial) return blankDraft().spec;
      const imported = importTheme(initial.spec);
      return 'error' in imported ? blankDraft().spec : imported.spec;
    },
  );

  /**
   * What the OPENED OR IMPORTED theme referenced. See the note on
   * [referencesWallpaper] for why this is presence per kind and not a filename
   * list.
   *
   * Both are false for a new draft, and that is correct rather than a gap: a
   * distro with no wallpaper renders the palette gradient, which is a legitimate
   * thing to ship. The guard is only ever about LOSING a reference that was
   * there when the theme arrived, never about requiring one to exist.
   *
   * Import RAISES these and never lowers them: an imported spec that references
   * wallpapers, published without an upload, would otherwise ship with
   * `wallpapers: []` silently, which is the exact bug this guard exists for.
   */
  const [hadWallpaper, setHadWallpaper] = React.useState<boolean>(() =>
    initial ? referencesWallpaper(initial.spec) : false,
  );
  const [hadLogo, setHadLogo] = React.useState<boolean>(() =>
    initial ? referencesLogo(initial.spec) : false,
  );

  const [cardTitle, setCardTitle] = React.useState(initial?.title ?? '');
  const [cardSummary, setCardSummary] = React.useState(initial?.summary ?? '');

  // pricing
  //
  // A draft with no sku is a free distro, which is the bundled case and the
  // common one. `free` therefore starts true when we opened something that has
  // no product ID, rather than defaulting to paid and making every free theme
  // an edit away from being priced.
  const [free, setFree] = React.useState(initial ? !initial.sku : false);
  const [distroSkuRaw, setDistroSkuRaw] = React.useState(initial?.sku ?? '');
  const [iconsSkuRaw, setIconsSkuRaw] = React.useState('');

  // theme assets, seeded from what the draft actually stored. The spec's own
  // `logo` references decide which saved file is a logo and which a wallpaper;
  // a file the spec does not claim as a logo is a wallpaper, which also covers
  // drafts saved before logos existed.
  const initialLogoNames = logoNamesOf(initial?.spec);
  const [wallpapers, setWallpapers] = React.useState<Asset[]>(() =>
    initialAssets
      .filter((a) => a.file !== initialLogoNames.light && a.file !== initialLogoNames.dark)
      .map((a) => assetFromDataUrl(a.file, a.dataUrl)),
  );
  // Framing lives BESIDE the assets, keyed by filename, exactly as it ships.
  // Hanging it off the Asset objects would look tidier and would lose it on
  // every re-upload, because `upsertAsset` replaces the object holding a name
  // and the framing is a fact about the SLOT rather than about the bytes
  // currently in it: re-uploading a corrected export of the same wallpaper
  // should keep the focal point somebody already set for it.
  const [wallpaperMeta, setWallpaperMeta] = React.useState<Record<string, WallpaperMetaJson>>(
    () => ({ ...(initial?.spec?.wallpaperMeta ?? {}) }),
  );

  const [logoLight, setLogoLight] = React.useState<Asset | null>(() => {
    const hit = initialLogoNames.light
      ? initialAssets.find((a) => a.file === initialLogoNames.light)
      : null;
    return hit ? assetFromDataUrl(hit.file, hit.dataUrl) : null;
  });
  const [logoDark, setLogoDark] = React.useState<Asset | null>(() => {
    const hit = initialLogoNames.dark
      ? initialAssets.find((a) => a.file === initialLogoNames.dark)
      : null;
    return hit ? assetFromDataUrl(hit.file, hit.dataUrl) : null;
  });

  // icons, seeded the same way: the saved icon-pack draft's assignments land in
  // their grid slots, and any package outside the common set gets its row back.
  const [entries, setEntries] = React.useState<{ pkg: string; label: string }[]>(() => {
    const extra = (initialIcons?.icons ?? [])
      .filter((i) => !COMMON_APPS.some((c) => c.pkg === i.pkg))
      .map((i) => ({ pkg: i.pkg, label: i.pkg.split('.').pop() ?? i.pkg }));
    return [...extra, ...COMMON_APPS];
  });
  const [assignments, setAssignments] = React.useState<Record<string, Assignment>>(() => {
    const out: Record<string, Assignment> = {};
    for (const i of initialIcons?.icons ?? []) {
      out[i.pkg] = { file: i.file, blob: blobFromDataUrl(i.dataUrl), url: i.dataUrl };
    }
    return out;
  });
  const [iconName, setIconName] = React.useState(initialIcons?.name ?? '');

  /**
   * WHERE THIS DISTRO'S HERO PACK COMES FROM.
   *
   * 'build' is the screen as it was: assign art per app below, and publish a new
   * pack at `<base>-icons`. 'published' points at a pack that already exists and
   * publishes no icon pack at all.
   *
   * ONE SOURCE, NEVER BOTH, and that is the point rather than a simplification.
   * A theme names exactly one hero pack. Offering an inline grid and a picker at
   * the same time means the two can disagree, and the losing one is a pack that
   * uploads, verifies, installs, is granted, and is never read by anything.
   *
   * Opening an existing distro starts in 'published' when its spec already names
   * a pack, because that is what the distro currently is. It does NOT start
   * there merely because the field is non-empty and unrecognised: a spec naming
   * a bundled pack like `yaru`, which is not in the CDN index, would otherwise
   * open into a picker with nothing selected and look broken.
   */
  const [iconSource, setIconSource] = React.useState<'build' | 'published'>(() => {
    const named = initial?.spec.icons?.heroPack;
    return named && heroPacks.some((p) => p.packId === named) ? 'published' : 'build';
  });
  const [pickedPack, setPickedPack] = React.useState<string>(
    () => initial?.spec.icons?.heroPack ?? '',
  );

  const [publishing, setPublishing] = React.useState(false);
  const toast = useToast();

  const [importOpen, setImportOpen] = React.useState(false);

  /**
   * Apply a pasted or picked theme.json. REPLACE, NOT MERGE: the importer's
   * absent-stays-absent contract only holds when it starts from the file
   * alone, so the whole spec state is swapped for `importTheme`'s result.
   * Pricing, card title, and summary are untouched; they live in the index
   * row, not in theme.json, so the file has nothing to say about them.
   *
   * Beyond the spec, three things follow the file:
   *
   *   - the distro id is seeded from the imported `id` (trailing `-theme`
   *     stripped) ONLY when it is currently empty, so importing into an
   *     existing distro can never silently rename its pack ids and skus
   *   - the icon source mirrors the open-from-draft initialiser exactly: a
   *     named hero pack that is published opens the picker on it, anything
   *     else lands in build mode with the reference carried in the spec
   *   - the asset guard is RAISED (never lowered) from what the file
   *     references, so publishing without the uploads blocks instead of
   *     shipping a wallpaperless pack silently
   *
   * The union return is for the panel: an error means nothing was changed,
   * notes mean the spec landed and these are the fixes to make before
   * publishing, in the importer's own words.
   */
  function applyImport(raw: string): { error: string } | { notes: string[] } {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return { error: 'That is not valid JSON. Nothing was changed.' };
    }
    const imported = importTheme(parsed);
    if ('error' in imported) {
      return { error: `${imported.error} Nothing was changed.` };
    }

    // ─── BEFORE `setSpec`, WHICH IS THE ONLY MOMENT BOTH EXIST ────────────
    //
    // `spec` here is the draft about to be discarded. One line later it is gone,
    // and with it any block this file omits: `setSpec` replaces, it does not
    // merge. Arch lost its boot log, splash and desklet skins to a layout-only
    // import and nobody noticed until three textareas were visibly empty.
    const lost = replacedBlocks(spec, imported.spec);

    setSpec(imported.spec);

    // The one pricing field the file actually speaks about. Seeded ONLY when
    // the raw JSON carried a `tier` key (the importer fills an absent one from
    // the blank default, which must not flip anything) and only while both sku
    // fields are untouched, so an import can never reprice a distro someone
    // has already priced.
    if (
      typeof parsed === 'object' &&
      !Array.isArray(parsed) &&
      'tier' in (parsed as Record<string, unknown>) &&
      distroSkuRaw === '' &&
      iconsSkuRaw === ''
    ) {
      setFree(imported.spec.tier === 'free');
    }

    const importedBase = imported.spec.id.replace(/-theme$/, '');
    if (!base && importedBase) setBase(importedBase);

    const named = imported.spec.icons?.heroPack;
    if (named && heroPacks.some((p) => p.packId === named)) {
      setIconSource('published');
      setPickedPack(named);
    } else {
      setIconSource('build');
      setPickedPack(named ?? '');
    }

    if (referencesWallpaper(imported.spec)) setHadWallpaper(true);
    if (referencesLogo(imported.spec)) setHadLogo(true);

    toast.success('Imported.');

    // ─── AND WHAT THE CANONICALISER THREW AWAY ────────────────────────────
    //
    // `importTheme` already returns notes for what it KNOWS it rejected, which
    // is how `Chrome family 'pocket' is unknown and was dropped` reaches the
    // panel below. It says nothing about values removed by the allow-lists
    // further in, and three shipped that way:
    //
    //   * Arch published with `pager` and `clock` gone from its bar, because
    //     `PANEL_MODULES` was five entries at the time.
    //   * Pocket imported with no `appDrawer`, because `APP_DRAWERS` did not
    //     yet know `library`, and drew the shared grid for days.
    //   * Garuda published a four-module panel as `["spacer"]`.
    //
    // Each was found by someone noticing a screen looked wrong. This function
    // held both sides the whole time: the file that came in and the spec that
    // came out, on the two lines above it.
    //
    // AFTER the importer's own notes rather than merged into them. Those are a
    // deliberate rejection with a reason; these are a silent loss, and reading
    // them as one list would make the second look as considered as the first.
    // `lost` LAST. The importer's own notes are a rejection with a reason, the
    // diff is a silent removal on the way in, and this is a whole block the
    // file never mentioned. Increasing order of "and you probably meant to keep
    // that", which is the order a reader should hit them in.
    return {
      notes: [
        ...imported.notes,
        ...importDiff(parsed, imported.spec),
        ...lost,
      ],
    };
  }

  const setS = (p: Partial<ThemeSpecJson>) => setSpec((s) => ({ ...s, ...p }));

  const themePackId = base ? (isBundled ? base : `${base}-theme`) : '';
  const iconPackId = base ? `${base}-icons` : '';
  // ── SKU DERIVATION, THROUGH `skus.ts` AND NOT BY HAND ────────────────────
  //
  // This was `base.replace(/-/g, '_')` inline, which is right for the ordinary
  // case and wrong for the one that costs something. `isSafePackId` allows a
  // PERIOD in a distro id, so `kali-2024.1` derived `distro_kali_2024.1`, which
  // `isSafeSku` refuses. The publish would upload both packs, reach `signIndex`
  // and fail there, leaving the objects in the bucket and nothing in the
  // catalogue pointing at them.
  //
  // `slugFor` collapses every run of non-alphanumerics to one underscore and
  // trims the ends, so a derived id is always something Play and the signed
  // index both accept. One derivation, shared with the icon builder and the
  // commerce page.
  const distroSku = free ? null : distroSkuRaw.trim() || (base ? distroSkuFor(base) : '');
  const iconsSku = free ? null : iconsSkuRaw.trim() || (base ? iconsSkuFor(base) : '');

  /**
   * The grid's own view: one row per SLOT, which is a role id for the core set
   * and a raw package id for anything hand-added. Files are uploaded from this,
   * because a file is uploaded once no matter how many packages it covers.
   */
  const slotOrder = React.useMemo(
    () =>
      entries
        .filter((e) => assignments[e.pkg])
        .map((e) => ({ slot: e.pkg, file: assignments[e.pkg].file })),
    [entries, assignments],
  );

  /**
   * The PACK'S view: one row per package. `expandRoleEntries` turns the Phone
   * slot into the AOSP, Google and Samsung dialer ids all pointing at one file,
   * which is what makes a single drawn icon land on every vendor's phone.
   */
  const order = React.useMemo(() => expandRoleEntries(slotOrder), [slotOrder]);

  /**
   * The contact sheet and the health panel, per SLOT rather than per package.
   *
   * One drawn Phone icon expands to three dialer packages, and measuring it
   * three times would put three identical readings into the ink histogram and
   * pull the median toward whichever roles happen to cover the most vendors.
   * The author drew one icon, so it is measured once.
   *
   * `blob` is the composed output, which is what ships. There is no separate
   * source here: unlike the icon builder, this workspace does not retain the
   * original upload once `renderHeroIcon` has run, so the composed bytes are
   * the only art available. That means a plate makes ink coverage useless, so
   * a styled pack measures its plate rather than its art. Called out rather
   * than hidden: the reading is honest only while `style` is null, and closing
   * that needs the workspace to keep sources the way the builder does.
   */
  const sheetTiles = React.useMemo(
    () =>
      entries
        .filter((e) => assignments[e.pkg])
        .map((e) => ({
          id: e.pkg,
          blob: assignments[e.pkg].blob,
          source: assignments[e.pkg].blob,
          label: e.label,
          slot: e.pkg,
        })),
    [entries, assignments],
  );

  const healthRows = React.useMemo(
    () =>
      sheetTiles.map((t) => ({
        key: `${t.label}:${t.source.size}`,
        label: t.label,
        art: t.source,
      })),
    [sheetTiles],
  );
  // Only the 'build' source publishes an inline pack. In 'published' the grid is
  // not rendered at all, but its assignments survive a mode switch in state, and
  // sending them would upload a second pack nothing references.
  const hasIcons = iconSource === 'build' && order.length > 0;

  /**
   * The hero pack this distro ships, whichever way it was chosen.
   *
   * ─── THE FIELD WAS NEVER WRITTEN, AND THAT WAS THE BUG ──────────────────
   *
   * `effectiveSpec` below rewrote `id`, `wallpapers` and `logo`. `heroPack` was
   * not in it and appeared nowhere else in this file. So filling the grid and
   * publishing uploaded a pack at `<base>-icons`, wrote the entitlement granting
   * it, and shipped a theme.json that never named it. The pack verified,
   * installed, was granted, and if the device links a theme to its icons through
   * this field, was never read. Nothing errors on that path: an unnamed hero
   * pack simply means every app falls to the generator, which looks like a
   * design choice rather than a failure.
   *
   * Writing it is correct either way. If the launcher instead resolves by a
   * `<base>-icons` convention, naming the pack explicitly changes nothing and
   * makes the theme self-describing.
   */
  const heroPackId =
    iconSource === 'published'
      ? pickedPack || null
      : hasIcons
        ? iconPackId
        : (spec.icons?.heroPack ?? null);

  const pickedSku =
    iconSource === 'published'
      ? (heroPacks.find((p) => p.packId === pickedPack)?.sku ?? null)
      : null;

  /**
   * Problems only the published source can create.
   *
   * The second one is a pricing leak rather than a typo, and it is silent on
   * device. `distro-publish` writes an entitlement only when `distroSku` is set,
   * so a FREE distro naming a PAID icon pack grants nobody anything: the theme
   * asks for a pack the buyer does not own, the request fails entitlement, and
   * every app falls to the generator. The distro looks finished here, ships, and
   * renders wrong for everyone.
   */
  const pickedProblems: string[] = [];
  if (iconSource === 'published') {
    if (!pickedPack) {
      pickedProblems.push('Choose a published icon pack, or switch back to building one here.');
    } else if (!heroPacks.some((p) => p.packId === pickedPack)) {
      pickedProblems.push(`'${pickedPack}' is not in the published packs, so nothing would resolve it.`);
    } else if (free && pickedSku) {
      pickedProblems.push(
        `This distro is free, so it writes no entitlement, but '${pickedPack}' is sold as '${pickedSku}'. ` +
          'Nobody would be granted it and every app would fall back to the generated icon.',
      );
    }
  }

  // The spec exactly as it will publish: id becomes the theme packId, and the
  // asset paths become the bare filenames the pack ships (not the APK paths).
  const effectiveSpec: ThemeSpecJson = React.useMemo(() => {
    const logo =
      logoLight || logoDark
        ? { light: (logoLight ?? logoDark)!.name, dark: (logoDark ?? logoLight)!.name }
        : undefined;
    return {
      ...spec,
      id: themePackId,
      wallpapers: wallpapers.map((w) => w.name),
      // Narrowed to what is actually shipping. A wallpaper the author framed
      // and then removed would otherwise leave a key the device looks up and
      // never finds, and the importer would flag it as an orphan on the next
      // round trip through this workspace.
      wallpaperMeta: Object.fromEntries(
        wallpapers
          .map((w) => [w.name, wallpaperMeta[w.name]] as const)
          .filter((e): e is readonly [string, WallpaperMetaJson] => e[1] != null),
      ),
      logo,
      // `?? undefined` rather than null: `pruneIcons` in theme-spec drops absent
      // keys, and a distro with no hero pack should ship no key at all rather
      // than an explicit null that reads as a deliberate empty.
      icons: { ...spec.icons, heroPack: heroPackId ?? undefined },
    };
  }, [spec, themePackId, wallpapers, wallpaperMeta, logoLight, logoDark, heroPackId]);

  const themeDraft: ThemeDraft = {
    id: themePackId,
    title: cardTitle || spec.name,
    summary: cardSummary,
    sku: distroSku,
    // Hardcoding false here is how editing bundled Ubuntu once produced a
    // second, deletable, non-bundled copy of it. The flag is the draft's
    // identity, not a form field, so it passes through untouched.
    bundled: isBundled,
    packVersion: 1,
    updatedAt: 0,
    spec: effectiveSpec,
  };

  const baseProblems: string[] = [];
  if (!base) baseProblems.push('Set a distro id (e.g. kali)');
  else if (!isSafePackId(base)) baseProblems.push('Distro id must be lowercase letters, digits, . _ or -');

  const themeProblems = base ? validateDraft(themeDraft) : [];
  /**
   * ─── VALIDATE THE PACK, NOT THE GRID ──────────────────────────────────────
   *
   * This passed `entries`, which is one row per SLOT, and a slot id is a role:
   * `phone`, `messages`, `contacts`. `validateHeroPack` says so in its own
   * comment, in the file it lives in:
   *
   *     Entries reach here ALREADY EXPANDED by `expandRoleEntries`, so every
   *     `pkg` is a real package id.
   *
   * It was the only caller violating that, and the result was thirty problems
   * reading "'phone' is not a valid Android package name" on a workspace where
   * nothing was actually wrong. The publish path was already correct, because
   * it builds from `order`; only the validator saw the unexpanded view, so the
   * screen refused to publish something that would have published fine.
   *
   * `order` is that same expansion, already memoised above for the publish
   * path. Using it here means the check now runs over exactly the rows that
   * will be written into pack.json, which is the only view worth validating.
   */
  const iconProblems = hasIcons
    ? validateHeroPack(
        {
          id: iconPackId,
          name: iconName || `${spec.name} icons`,
          minAppVersion: spec.minAppVersion,
          masked: false,
          sku: iconsSku,
        },
        order.map<HeroIconEntry>((o) => ({
          pkg: o.pkg,
          label: roleForPackage(o.pkg)?.label ?? o.pkg,
          file: o.file,
        })),
      )
    : [];

  // Advisory, and it belongs here rather than beside the derivation above
  // because it reads `hasIcons`, which is declared further down. A `const` read
  // before its initialiser is a TDZ throw at render, not a lint warning.
  //
  // `isSafeSku` inside `signIndex` remains the gate. This exists so a bad shape
  // is visible BEFORE an upload rather than after it: a Play product ID is
  // permanent, so the moment to catch a typo is while it is still a draft.
  const skuIssues = free
    ? []
    : [
        ...skuProblems(distroSku ?? '', 'distro'),
        ...(hasIcons ? skuProblems(iconsSku ?? '', 'icons') : []),
      ];

  // Only one logo slot has to be filled: `effectiveSpec` above falls back with
  // `logoLight ?? logoDark` for both sides, so a single upload satisfies a theme
  // that referenced light and dark.
  const assetProblems: string[] = [];
  if (hadWallpaper && wallpapers.length === 0) {
    assetProblems.push(
      'This theme referenced a wallpaper and none has been uploaded. ' +
        'Publishing now would ship the pack with no wallpaper at all, silently.',
    );
  }
  if (hadLogo && !logoLight && !logoDark) {
    assetProblems.push(
      'This theme referenced a logo and neither slot is filled. ' +
        'Publishing now would ship the pack with no logo, silently.',
    );
  }

  const allProblems = [
    ...baseProblems,
    ...themeProblems,
    ...iconProblems,
    ...skuIssues,
    ...assetProblems,
    ...pickedProblems,
  ];
  const valid = allProblems.length === 0;

  function onAssign(pkg: string, a: Assignment | null) {
    setAssignments((prev) => {
      const next = { ...prev };
      if (a) next[pkg] = a;
      else delete next[pkg];
      return next;
    });
  }

  /**
   * The composed style for this pack, or null for "art as authored".
   *
   * SAME DEFAULT AS THE STANDALONE BUILDER, and for the same reason: every pack
   * published before today was rendered without composing, so a workspace that
   * opened in styling mode would silently restyle a republished distro.
   */
  const [style, setStyle] = React.useState<ComposeSpec | null>(null);
  const [restyling, setRestyling] = React.useState(false);
  const [pickingGlyph, setPickingGlyph] = React.useState(false);

  /**
   * Recompose every assignment that still has its source.
   *
   * ─── SEQUENTIAL, AND SKIPPING WHAT IT CANNOT DO ─────────────────────────
   *
   * Each pass decodes and re-encodes a full image, so forty at once stalls the
   * tab long enough to look like a crash.
   *
   * An assignment saved before `source` existed is LEFT ALONE rather than
   * re-rendered from its output. Recomposing a composed plate is the one thing
   * this whole design exists to prevent, and a slightly inconsistent pack with
   * one un-restyled icon is a smaller problem than one icon that has been
   * plated twice and cannot be recovered without a re-upload.
   */
  async function restyle(next: ComposeSpec | null) {
    setStyle(next);
    const pairs = Object.entries(assignments);
    if (pairs.length === 0) return;
    setRestyling(true);
    for (const [pkg, a] of pairs) {
      if (!a.source) continue;
      try {
        const png = next
          ? await composeIcon(next, a.source)
          : (await renderHeroIcon(new File([a.source], a.file))).blob;
        if (!png) continue;
        URL.revokeObjectURL(a.url);
        onAssign(pkg, {
          ...a,
          blob: png,
          url: URL.createObjectURL(png),
        });
      } catch {
        // One bad source leaves its icon at the previous render rather than
        // sinking the batch, which matches every other loop in this pipeline.
      }
    }
    setRestyling(false);
  }

  /**
   * A picked brand glyph, assigned to a slot.
   *
   * The slot is the FIRST UNFILLED one whose label matches the glyph's title,
   * falling back to the first unfilled slot at all. Guessing from a package id
   * the way the standalone builder does is not available here, because this
   * grid is keyed by slot rather than by filename.
   */
  async function addGlyph(glyph: GlyphLite) {
    setPickingGlyph(false);
    const wanted = glyph.title.toLowerCase();
    const target =
      entries.find((e) => !assignments[e.pkg] && e.label.toLowerCase() === wanted) ??
      entries.find((e) => !assignments[e.pkg]);
    if (!target) return;

    const src = glyphToBlob(glyph);
    const png = style
      ? await composeIcon(style, src)
      : (await renderHeroIcon(new File([src], `${glyph.slug}.svg`, { type: 'image/svg+xml' }))).blob;
    if (!png) return;

    onAssign(target.pkg, {
      file: `${target.pkg.replace(/[^a-z0-9]+/gi, '_').toLowerCase()}.png`,
      blob: png,
      url: URL.createObjectURL(png),
      source: src,
    });
  }
  function onAddApp(pkg: string, label: string) {
    setEntries((prev) => (prev.some((e) => e.pkg === pkg) ? prev : [{ pkg, label }, ...prev]));
  }

  async function pickAsset(file: File, name: string, set: (a: Asset) => void) {
    const blob = file;
    set({ name, blob, url: URL.createObjectURL(blob) });
  }

  /**
   * Add a batch of wallpapers.
   *
   * ONE setState, not one per file. A loop of `setWallpapers` calls with
   * `upsertAsset` would work, but each name is resolved against the list as it
   * stood when that call ran, so two files resolving to the same kept name
   * inside one batch would both append instead of the second replacing the
   * first. Folding the whole batch in a single updater makes a multi-pick
   * behave exactly like the same files picked one at a time.
   */
  function addWallpapers(files: File[]) {
    const added: Asset[] = files.map((f) => ({
      name: wallpaperNameFor(f),
      blob: f,
      url: URL.createObjectURL(f),
    }));
    setWallpapers((prev) => {
      let next = prev;
      for (const a of added) next = upsertAsset(next, a);
      return next;
    });
  }

  // ── SAVE DRAFT ────────────────────────────────────────────────────────
  //
  // A distro is wallpapers, a palette, a boot log and an icon set, and that is
  // not a one-sitting job. Until this existed the only exit from this screen
  // was publish: closing the tab discarded every uploaded wallpaper and logo,
  // which on a distro is most of the work.
  //
  // TWO STORES, ONE PRESS. The spec goes through `writeDraft`, which validates
  // and merges; the images go to `admin/distro-drafts/<id>/`, because a
  // ThemeDraft references wallpapers BY FILENAME and has never carried the
  // bytes. The action writes art first and spec last, so a partial failure
  // leaves unreferenced bytes rather than a draft naming files that are not
  // stored.
  //
  // It publishes nothing: no version bump, no index write, no signature, and
  // no device sees anything.
  const [savingDraft, setSavingDraft] = React.useState(false);

  async function saveDraft() {
    if (!base.trim()) {
      toast.error('A distro id is needed before a draft can be saved.');
      return;
    }
    setSavingDraft(true);
    try {
      const fd = new FormData();
      fd.append('app', app);
      // The SAME `themeDraft` the rest of this component already derives, so a
      // draft and a publish can never disagree about what is being edited.
      fd.append('draft', JSON.stringify(themeDraft));

      // Wallpapers and logos only. Icon art belongs to the icon pack and is
      // saved with it; duplicating it here would give one image two owners.
      for (const w of wallpapers) {
        fd.append('files', new File([w.blob], w.name, { type: w.blob.type || 'image/webp' }));
        fd.append('paths', w.name);
      }
      if (logoLight) {
        fd.append('files', new File([logoLight.blob], logoLight.name, { type: logoLight.blob.type || 'image/png' }));
        fd.append('paths', logoLight.name);
      }
      if (logoDark && logoDark.name !== logoLight?.name) {
        fd.append('files', new File([logoDark.blob], logoDark.name, { type: logoDark.blob.type || 'image/png' }));
        fd.append('paths', logoDark.name);
      }

      // The inline icon set, saved as the icon-pack draft it will publish as.
      // The comment above used to claim icon art "is saved with the icon pack",
      // and nothing saved it: closing the tab discarded every assignment. It
      // goes to `icon-drafts` under `<base>-icons`, the same store the icon
      // builder uses, so either screen can resume it.
      if (iconSource === 'build' && order.length > 0) {
        fd.append(
          'iconDraft',
          JSON.stringify({
            packId: iconPackId,
            name: iconName || `${spec.name} icons`,
            minAppVersion: spec.minAppVersion,
            masked: false,
            sku: iconsSkuRaw.trim(),
            plate: '#E95420',
            radius: 22,
            shape: spec.icons?.treatment ?? 'roundedSquare',
            // SLOTS, not expanded packages: a reopened draft has to land back in
            // the same role tiles it was drawn in, and expanding here would
            // rehydrate as forty hand-added package rows.
            icons: slotOrder.map((s) => ({ pkg: s.slot, file: s.file })),
          }),
        );
        for (const s of slotOrder) {
          const a = assignments[s.slot];
          fd.append('iconFiles', new File([a.blob], s.file, { type: a.blob.type || 'image/png' }));
          fd.append('iconPaths', s.file);
        }
      }

      const res = await saveDistroDraftAction(fd);
      if (res.ok) {
        toast.success(
          `Draft saved. ${res.assets} ${res.assets === 1 ? 'asset' : 'assets'} kept. Nothing published.`,
        );
      } else {
        toast.error(res.error);
      }
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSavingDraft(false);
    }
  }

  async function publish() {
    setPublishing(true);
    try {
      const assets = [
        ...wallpapers.map((w) => ({ file: w.name })),
        ...(logoLight ? [{ file: logoLight.name }] : []),
        ...(logoDark && logoDark.name !== logoLight?.name ? [{ file: logoDark.name }] : []),
      ];
      const meta = {
        app,
        theme: {
          packId: themePackId,
          minAppVersion: spec.minAppVersion,
          sku: distroSku,
          title: cardTitle || spec.name,
          summary: cardSummary,
          spec: effectiveSpec,
          assets,
        },
        icons: hasIcons
          ? {
              packId: iconPackId,
              minAppVersion: spec.minAppVersion,
              sku: iconsSku,
              name: iconName || `${spec.name} icons`,
              order,
              // Composited below and shipped as a payload file, so the store
              // card on device shows the pack's own art. See pack-preview.ts.
              preview: true,
            }
          : null,
        distroSku,
        distroTitle: cardTitle || spec.name,
        distroSummary: cardSummary,
      };

      const fd = new FormData();
      fd.append('meta', JSON.stringify(meta));
      // ─── PUBLISH SAVES THE DRAFT TOO ────────────────────────────────────
      //
      // The SAME `themeDraft` save sends, so publishing and saving cannot
      // disagree about what is being edited. Publishing used to ship a pack and
      // leave the stored draft untouched, so reopening showed the last SAVE and
      // every edit that went straight to publish looked lost.
      fd.append('draft', JSON.stringify(themeDraft));
      for (const w of wallpapers) fd.append(`asset:${w.name}`, w.blob, w.name);
      if (logoLight) fd.append(`asset:${logoLight.name}`, logoLight.blob, logoLight.name);
      if (logoDark && logoDark.name !== logoLight?.name) fd.append(`asset:${logoDark.name}`, logoDark.blob, logoDark.name);
      // One blob per FILE. `order` may name the same file three times (one per
      // package in a role) and appending it three times would upload the same
      // bytes three times and, worse, make the route's file list disagree with
      // the manifest's.
      for (const s of slotOrder) fd.append(`icon:${s.file}`, assignments[s.slot].blob, s.file);
      if (hasIcons) {
        const preview = await composePreviewPng(slotOrder.map((s) => assignments[s.slot].blob));
        if (preview) fd.append(`icon:${PREVIEW_NAME}`, preview, PREVIEW_NAME);
      }

      const res = await publishDistroAction(fd);
      if (res.ok) {
        toast.success(`Published ${base}: theme v${res.themeVersion}${res.iconVersion ? `, icons v${res.iconVersion}` : ''}`);
        // The packs shipped and the draft did not. Its own toast rather than a
        // suffix on the success line: the publish genuinely worked, and the
        // thing to act on is that this workspace will reopen out of date.
        if (res.warning) toast.error(res.warning);
      }
      else toast.error(res.error);
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setPublishing(false);
    }
  }

  return (
    <BuilderShell
      crumbs={[{ label: 'Apps', href: '/' }, { label: app, href: `/apps/${app}/packs` }, { label: 'Distros', href: `/apps/${app}/distros/builder` }, { label: base || 'new' }]}
      title="Distro workspace"
      meta={valid ? '✓ ready' : `✗ ${allProblems.length} to fix`}
      actions={
        <>
          <button
            type="button"
            className="tb-btn"
            onClick={() => setImportOpen((v) => !v)}
            style={{ fontFamily: C.mono, fontSize: 12.5, color: importOpen ? C.inkStrong : C.ink, background: importOpen ? C.chip : 'transparent', border: `1px solid ${C.line}`, borderRadius: 7, padding: '8px 14px', marginRight: 8 }}
          >
            import theme.json
          </button>

          {/* SAVE DRAFT SITS BEFORE PUBLISH AND HAS NO `valid` GATE. The reason
              to save a draft is that the distro is not finished, so disabling
              it whenever publish is disabled would disable it exactly when it
              is needed. The only requirement is an id, which is the draft's
              address. */}
          <button
            type="button"
            className="tb-btn"
            disabled={savingDraft || !base.trim()}
            onClick={saveDraft}
            style={{ fontFamily: C.mono, fontSize: 12.5, color: C.ink, background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 7, padding: '8px 14px', marginRight: 8 }}
          >
            {savingDraft ? 'saving' : 'save draft'}
          </button>

          <button type="button" className="tb-btn" disabled={!valid || publishing} onClick={publish} style={{ fontFamily: C.mono, fontWeight: 700, fontSize: 12.5, color: C.onAccent, background: C.amber, border: 'none', borderRadius: 7, padding: '8px 16px' }}>
            {publishing ? 'publishing' : 'publish distro'}
          </button>
        </>
      }
    >
      <style
        dangerouslySetInnerHTML={{
          __html: `
.dw-grid { display:grid; grid-template-columns: minmax(0,1fr) 300px; gap:18px; align-items:start; }
.dw-right { position: sticky; top: 108px; }
@media (max-width: 1040px){ .dw-grid { grid-template-columns:1fr; } .dw-right{ position:static; } }
`,
        }}
      />
      {importOpen ? <ImportPanel onApply={applyImport} /> : null}

        <div style={{ display: 'flex', gap: 4, padding: '0 0 14px' }}>
          {(['theme', 'icons', 'pricing'] as Tab[]).map((t) => {
            const on = t === tab;
            const probs = t === 'theme' ? themeProblems.length + baseProblems.length : t === 'icons' ? iconProblems.length : 0;
            return (
              <button
                key={t}
                type="button"
                className="tb-btn"
                onClick={() => setTab(t)}
                style={{
                  fontFamily: C.mono,
                  fontSize: 12.5,
                  color: on ? C.inkStrong : C.dim,
                  background: on ? C.chip : 'transparent',
                  border: `1px solid ${on ? C.line : 'transparent'}`,
                  borderRadius: 7,
                  padding: '6px 14px',
                }}
              >
                {t}
                {probs ? <span style={{ color: C.red, marginLeft: 6 }}>●</span> : null}
              </button>
            );
          })}
        </div>


        {(savingDraft || publishing) ? (
          <>
            <style>{'@keyframes dwSlide {0%{transform:translateX(-100%)}100%{transform:translateX(350%)}}'}</style>
            <div style={{ position: 'relative', height: 3, overflow: 'hidden', borderRadius: 2, background: C.line, margin: '10px 0 0' }}>
              <div style={{ position: 'absolute', top: 0, bottom: 0, left: 0, width: '32%', background: C.inkStrong, animation: 'dwSlide 1.1s linear infinite' }} />
            </div>
          </>
        ) : null}

        {rehydrateNotes.length > 0 ? (
          <div style={{ margin: '10px 0 0', padding: '10px 14px', border: `1px solid ${C.line}`, borderRadius: 10, fontFamily: C.mono, fontSize: 11.5, color: C.dim, lineHeight: 1.6 }}>
            {rehydrateNotes.map((n) => (
              <div key={n}>{n}</div>
            ))}
          </div>
        ) : null}

        <div className="dw-grid">
          <div>
            {tab === 'theme' ? (
              <>
                <Section title="distro" hint="one id; the theme and icon packs derive from it">
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0 14px' }}>
                    <Field
                      label="distro id"
                      hint={initial ? 'locked; the id is this draft\u0027s address on device and in the index' : 'lowercase, e.g. kali'}
                    >
                      {/* IMMUTABLE ONCE A DRAFT EXISTS. Drafts, packs, asset
                          folders, SKUs and the device catalog are all keyed by
                          this string, so editing it does not rename a distro,
                          it forks one. That fork is exactly how Ubuntu became
                          two rows. */}
                      {initial ? (
                        <div style={{ fontFamily: C.mono, fontSize: 13, color: C.inkStrong, padding: '9px 10px', border: `1px solid ${C.line}`, borderRadius: 7, background: C.chip }}>
                          {base}
                        </div>
                      ) : (
                        <TextInput value={base} placeholder="kali" onChange={(v) => setBase(v.trim())} />
                      )}
                    </Field>
                    <Field label="name">
                      <TextInput value={spec.name} placeholder="Kali Linux" mono={false} onChange={(v) => setS({ name: v })} />
                    </Field>
                    <Field label="version">
                      <TextInput value={spec.version} placeholder="2026.1" onChange={(v) => setS({ version: v })} />
                    </Field>
                    <Field label="shell">
                      <SelectInput<ShellName> value={spec.shell} options={SHELLS} labels={shellLabels} onChange={(v) => setS({ shell: v })} />
                    </Field>
                    <Field label="chrome" hint="auto = follow shell">
                      <SelectInput<ChromeName | 'auto'>
                        value={spec.chromeFamily ?? 'auto'}
                        options={['auto', ...CHROMES] as (ChromeName | 'auto')[]}
                        onChange={(v) => setS({ chromeFamily: v === 'auto' ? null : v })}
                      />
                    </Field>
                    <Field label="min app version">
                      <NumberInput value={spec.minAppVersion} min={0} step={1} onChange={(v) => setS({ minAppVersion: v ?? 0 })} />
                    </Field>
                    <Field label="display font" hint="labels and titles">
                      <FontSelect value={spec.typography?.display ?? ''} mono={false} placeholder="Ubuntu" onChange={(v) => setS({ typography: { ...spec.typography, display: v || null } })} />
                    </Field>
                    <Field label="mono font" hint="terminal and readouts">
                      <FontSelect value={spec.typography?.mono ?? ''} mono placeholder="UbuntuMono" onChange={(v) => setS({ typography: { ...spec.typography, mono: v || null } })} />
                    </Field>
                  </div>
                  <div style={{ marginTop: 6, paddingTop: 14, borderTop: `1px solid ${C.lineSoft}`, fontFamily: C.mono, fontSize: 11.5, color: C.faint }}>
                    {base ? (
                      <>packs: <span style={{ color: C.dim }}>{themePackId}</span> · <span style={{ color: C.dim }}>{iconPackId}</span></>
                    ) : (
                      'set a distro id to derive the pack ids'
                    )}
                  </div>
                </Section>

                <Section title="palette" hint="six colours; dock takes an #AARRGGBB alpha byte">
                  <PaletteEditor
                    palette={spec.palette}
                    setPalette={(p) => setSpec((s) => ({ ...s, palette: { ...s.palette, ...p } }))}
                    paletteLight={spec.paletteLight ?? null}
                    setPaletteLight={(pl) => setSpec((s) => ({ ...s, paletteLight: pl }))}
                  />
                </Section>

                <Section title="layout">
                  <LayoutEditor layout={spec.layout} setLayout={(p) => setSpec((s) => ({ ...s, layout: { ...s.layout, ...p } }))} />
                  <GesturesEditor
                    gestures={spec.gestures}
                    // Undefined rather than {} when the last binding is
                    // cleared, so `canonicalThemeJson` omits the key and a
                    // theme that ends up with no gesture opinion signs to the
                    // same bytes it did before anyone opened this editor.
                    setGestures={(g) => setSpec((s) => ({ ...s, gestures: g }))}
                  />
                </Section>

                <Section title="icon shape" hint="the general look; specific app icons live in the Icons tab">
                  <IconStyleEditor spec={spec} icons={spec.icons ?? {}} setIcons={(p) => setSpec((s) => ({ ...s, icons: { ...(s.icons ?? {}), ...p } }))} />
                </Section>

                <Section title="wallpapers & logo" hint="uploaded and shipped inside the pack as bare files">
                  <AssetList
                    label="wallpapers"
                    assets={wallpapers}
                    meta={wallpaperMeta}
                    onFrame={(name, m) =>
                      setWallpaperMeta((prev) => {
                        const next = { ...prev };
                        const trimmed = m ? canonWallpaperMeta(m) : null;
                        // A block that says nothing is REMOVED, not stored as
                        // defaults. That is what makes Reset actually reset,
                        // and it keeps the published theme.json free of rows
                        // for wallpapers nobody framed.
                        if (trimmed) next[name] = trimmed;
                        else delete next[name];
                        return next;
                      })
                    }
                    onAdd={(files) => addWallpapers(files)}
                    onRemove={(name) => setWallpapers((w) => w.filter((x) => x.name !== name))}
                    onReorder={(from, to) =>
                      setWallpapers((w) => {
                        // Rebuilt, not mutated. `wallpapers` feeds
                        // `effectiveSpec` through a useMemo keyed on the array
                        // identity, so splicing in place would leave the
                        // generated theme.json showing the old order until some
                        // unrelated edit happened to change the reference.
                        const next = [...w];
                        const [moved] = next.splice(from, 1);
                        if (!moved) return w;
                        next.splice(to, 0, moved);
                        return next;
                      })
                    }
                  />
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 12 }}>
                    <AssetSlot label="logo (light bg)" asset={logoLight} onPick={(file) => pickAsset(file, `logo_light.${extFor(file)}`, setLogoLight)} onClear={() => setLogoLight(null)} />
                    <AssetSlot label="logo (dark bg)" asset={logoDark} onPick={(file) => pickAsset(file, `logo_dark.${extFor(file)}`, setLogoDark)} onClear={() => setLogoDark(null)} />
                  </div>
                </Section>

                <Section title="boot · splash · desklets" hint="stored verbatim; valid JSON only">
                  <PassthroughEditor spec={spec} setSpec={setS} />
                </Section>
              </>
            ) : null}

            {tab === 'icons' ? (
              <>
                <Section
                  title="icon pack"
                  hint={
                    iconSource === 'published'
                      ? 'point this distro at a pack that is already published'
                      : hasIcons
                        ? `${order.length} assigned`
                        : 'optional - a distro can ship with no icon pack'
                  }
                  right={
                    <Segmented<'build' | 'published'>
                      value={iconSource}
                      options={['build', 'published'] as const}
                      labels={{ build: 'build here', published: 'use published' }}
                      onChange={setIconSource}
                    />
                  }
                >
                  {iconSource === 'published' ? (
                    <>
                      <Field
                        label="published pack"
                        hint="publishes no new icon pack"
                        error={
                          heroPacksUnreadable
                            ? 'The published packs could not be read, so this list is empty for a reason that is not "none exist".'
                            : undefined
                        }
                      >
                        <SelectInput<string>
                          value={pickedPack}
                          options={['', ...heroPacks.map((p) => p.packId)]}
                          labels={{
                            '': heroPacks.length === 0 ? 'nothing published' : 'choose a pack',
                            ...Object.fromEntries(
                              heroPacks.map((p) => [
                                p.packId,
                                p.title && p.title !== p.packId ? `${p.title} · ${p.packId}` : p.packId,
                              ]),
                            ),
                          }}
                          onChange={setPickedPack}
                        />
                      </Field>
                      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: -4 }}>
                        theme.json names <span style={{ color: C.dim }}>{pickedPack || '<nothing>'}</span>
                        {pickedSku ? <> · sold alone as <span style={{ color: C.dim }}>{pickedSku}</span></> : null}
                      </div>
                      {/* The one path where a dead product ships silently: the
                          pack is already published, so no sku field on this
                          screen would ever mention it. Same three states as
                          the pricing tab. */}
                      {pickedSku ? <PlayNote play={play} sku={pickedSku} /> : null}
                    </>
                  ) : (
                    <>
                      <Field label="icon pack name">
                        <TextInput value={iconName} placeholder={`${spec.name || 'Kali'} icons`} mono={false} onChange={setIconName} />
                      </Field>
                      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: -4 }}>
                        ships as <span style={{ color: C.dim }}>{iconPackId || '<distro>-icons'}</span>
                        {iconsSku ? <> · sold alone as <span style={{ color: C.dim }}>{iconsSku}</span></> : ' · free'}
                      </div>
                    </>
                  )}
                </Section>
                {iconSource === 'build' ? (
                  <Section title="app icons" hint="assign an image per app; the rest inherit the theme's icon shape">
                    {/* ── THE SAME COMPOSER THE STANDALONE BUILDER HAS ──────
                        Two icon builders existed, and every feature was
                        landing in one of them. This is the port, not a second
                        implementation: `IconStyleBar`, `GlyphPicker` and
                        `composeIcon` are the same modules, so the next change
                        to any of them reaches both screens.

                        The real fix is one builder behind both routes, and
                        this is not it. It is the version that ships Kali
                        tonight. */}
                    <div style={{ marginBottom: 12 }}>
                      <IconStyleBar
                        style={style}
                        onChange={restyle}
                        count={Object.keys(assignments).length}
                        busy={restyling}
                      />
                      <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
                        <button type="button" onClick={() => setPickingGlyph((v) => !v)}>
                          {pickingGlyph ? 'Close glyphs' : 'Brand glyph'}
                        </button>
                      </div>
                      <div style={{ marginTop: 10 }}>
                        <GlyphPicker
                          open={pickingGlyph}
                          onClose={() => setPickingGlyph(false)}
                          onPick={addGlyph}
                        />
                      </div>
                    </div>
                    {/* ── THE SAME TWO PANELS THE ICON BUILDER MOUNTS ──────
                        Imported, not reimplemented, for the reason the comment
                        above already gives: the last time a check lived in two
                        places, one copy learned about roles and the other did
                        not, and this screen spent a month reporting thirty
                        problems that were not problems. */}
                    {Object.keys(assignments).length > 0 ? (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 12 }}>
                        <IconContactSheet
                          tiles={sheetTiles}
                          inset={style?.inset ?? 0}
                          strokeWidth={style?.strokeWidth ?? null}
                        />
                        <IconSetHealth
                          rows={healthRows}
                          inset={style?.inset ?? 0}
                          strokeWidth={style?.strokeWidth ?? null}
                          plateNone={!style || style.plate.kind === 'none'}
                        />
                      </div>
                    ) : null}

                    <AppGrid entries={entries} assignments={assignments} masked={false} onAssign={onAssign} onAddApp={onAddApp} />
                  </Section>
                ) : null}
              </>
            ) : null}

            {tab === 'pricing' ? <PricingTab
              free={free}
              setFree={setFree}
              base={base}
              distroSku={distroSku}
              iconsSku={iconsSku}
              distroSkuRaw={distroSkuRaw}
              iconsSkuRaw={iconsSkuRaw}
              setDistroSkuRaw={setDistroSkuRaw}
              setIconsSkuRaw={setIconsSkuRaw}
              cardTitle={cardTitle}
              cardSummary={cardSummary}
              setCardTitle={setCardTitle}
              setCardSummary={setCardSummary}
              themePackId={themePackId}
              iconPackId={iconPackId}
              hasIcons={hasIcons}
              play={play}
              features={spec.features ?? []}
              setFeatures={(f) => setSpec((s) => ({ ...s, features: f }))}
            /> : null}
          </div>

          <div className="dw-right">
            <ThemePreview spec={effectiveSpec} />
            <div style={{ height: 14 }} />
            {allProblems.length ? (
              <div style={{ border: `1px solid ${C.red}`, borderRadius: 10, background: C.surface, padding: 12 }}>
                <div style={{ fontFamily: C.mono, fontSize: 11, letterSpacing: '0.14em', color: C.red, marginBottom: 8 }}>to fix</div>
                {allProblems.map((p, i) => (
                  <div key={i} style={{ fontFamily: C.mono, fontSize: 11.5, color: C.ink, marginBottom: 4 }}>· {p}</div>
                ))}
              </div>
            ) : (
              <GeneratedJson draft={themeDraft} />
            )}
          </div>
        </div>

    </BuilderShell>
  );
}

function PricingTab(props: {
  free: boolean;
  setFree: (v: boolean) => void;
  base: string;
  distroSku: string | null;
  iconsSku: string | null;
  distroSkuRaw: string;
  iconsSkuRaw: string;
  setDistroSkuRaw: (v: string) => void;
  setIconsSkuRaw: (v: string) => void;
  cardTitle: string;
  cardSummary: string;
  setCardTitle: (v: string) => void;
  setCardSummary: (v: string) => void;
  themePackId: string;
  iconPackId: string;
  hasIcons: boolean;
  play: PlayLite;
  features: ThemeFeatureJson[];
  setFeatures: (f: ThemeFeatureJson[]) => void;
}) {
  return (
    <>
      <Section title="storefront" hint="how the distro reads on the themes grid">
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <Field label="card title">
            <TextInput value={props.cardTitle} placeholder="Kali" mono={false} onChange={props.setCardTitle} />
          </Field>
          <Field label="card summary">
            <TextInput value={props.cardSummary} placeholder="2026.1 · undercover" mono={false} onChange={props.setCardSummary} />
          </Field>
        </div>
      </Section>

      <FeatureRowsEditor rows={props.features} setRows={props.setFeatures} free={props.free} />

      <Section title="pricing" hint="a paid distro is two products: the whole distro, and its icons alone">
        <div style={{ marginBottom: 14 }}>
          <Toggle value={props.free} label="Free distro (no purchase)" onChange={props.setFree} />
        </div>
        {!props.free ? (
          <>
            <SkuSourceNote play={props.play} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            <SkuField
              label="whole-distro sku"
              hint="unlocks theme + icons"
              kind="distro"
              derived={props.base ? distroSkuFor(props.base) : ''}
              placeholder={props.base ? distroSkuFor(props.base) : 'distro_kali'}
              raw={props.distroSkuRaw}
              setRaw={props.setDistroSkuRaw}
              play={props.play}
            />
            <SkuField
              label="icons-alone sku"
              hint="unlocks the icon pack only"
              kind="icons"
              derived={props.base ? iconsSkuFor(props.base) : ''}
              placeholder={props.base ? iconsSkuFor(props.base) : 'icons_kali'}
              raw={props.iconsSkuRaw}
              setRaw={props.setIconsSkuRaw}
              play={props.play}
            />
            </div>
          </>
        ) : null}
      </Section>

      <Section title="how each product unlocks" hint="the entitlement this publish writes">
        <Unlock label={props.themePackId || '<distro>-theme'} by={props.free ? ['free'] : [props.distroSku ?? '-']} />
        {props.hasIcons ? (
          <Unlock
            label={props.iconPackId || '<distro>-icons'}
            by={props.free ? ['free'] : [props.iconsSku ?? '-', props.distroSku ?? '-']}
          />
        ) : null}
        <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: 8 }}>
          The whole-distro sku grants both packs (an index entitlement). The icons-alone sku is the icon pack&apos;s own sku, so it
          sells on its own over any theme. `bundle_all_distros` is managed on the Bundles page.
        </div>
      </Section>
    </>
  );
}

function Unlock({ label, by }: { label: string; by: string[] }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '7px 0', borderBottom: `1px solid ${C.lineSoft}` }}>
      <span style={{ fontFamily: C.mono, fontSize: 12.5, color: C.inkStrong, minWidth: 140 }}>{label}</span>
      <span style={{ color: C.faint, fontSize: 12 }}>unlocked by</span>
      {by.map((b, i) => (
        <span key={i} style={{ fontFamily: C.mono, fontSize: 11.5, color: b === 'free' ? C.green : C.amber, background: C.chip, borderRadius: 5, padding: '2px 8px' }}>
          {b}
        </span>
      ))}
    </div>
  );
}
/**
 * The uploaded wallpapers, as a reorderable row.
 *
 * ─── WHY ORDER IS A FEATURE HERE AND NOT A TIDINESS ──────────────────────────
 *
 * `effectiveSpec` writes `wallpapers` straight from this array, and the device
 * treats the FIRST entry as the one to seed: `LauncherPrefs.wallpaperInitialized`
 * applies it once, on first use of the theme, and never again. So position zero
 * is the distro's opening impression on every phone that installs it, and until
 * now it was whichever file the author happened to pick first out of the system
 * file dialog. That is a real authoring decision being made by the sort order of
 * a folder.
 *
 * ─── WHY NATIVE DRAG EVENTS AND NOT A LIBRARY ────────────────────────────────
 *
 * Seven 64px tiles in one row. A drag-and-drop library is a dependency, a
 * bundle, and a set of behaviours the rest of this panel has no other examples
 * of, in exchange for touch support the console does not need and keyboard
 * support the arrows below already provide better than a drag ever would.
 *
 * The arrows are not a fallback. A precise one-step move is the edit an author
 * actually wants most of the time (promote this one to first), and doing that by
 * dragging a 64px square two positions left is worse at it than a button.
 */
function AssetList(props: {
  label: string;
  assets: Asset[];
  onAdd: (files: File[]) => void;
  onRemove: (name: string) => void;
  /** Omit on a list whose order carries no meaning. */
  onReorder?: (from: number, to: number) => void;
  /** Authored framing per filename. Omit on a list that ships no framing. */
  meta?: Record<string, WallpaperMetaJson>;
  /** Null clears the entry rather than storing a block of defaults. */
  onFrame?: (name: string, meta: WallpaperMetaJson | null) => void;
}) {
  const ref = React.useRef<HTMLInputElement>(null);
  const [dragFrom, setDragFrom] = React.useState<number | null>(null);
  const [dragOver, setDragOver] = React.useState<number | null>(null);
  const [framing, setFraming] = React.useState<string | null>(null);
  const reorder = props.onReorder;
  const onFrame = props.onFrame;
  const meta = props.meta ?? {};

  const move = (from: number, to: number) => {
    if (!reorder) return;
    if (to < 0 || to >= props.assets.length || to === from) return;
    reorder(from, to);
  };

  return (
    <Field label={props.label} hint={reorder ? 'webp or png; keeps its filename, which theme.json will reference; drag to reorder, first one is what a new install gets' : 'webp or png; keeps its filename, which theme.json will reference; re-uploading a name replaces it'}>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'flex-start' }}>
        {props.assets.map((a, i) => (
          <div key={a.name} style={{ width: 64 }}>
            <div
              draggable={reorder ? true : undefined}
              onDragStart={reorder ? () => setDragFrom(i) : undefined}
              onDragEnd={reorder ? () => { setDragFrom(null); setDragOver(null); } : undefined}
              // preventDefault on dragover is what MAKES an element a drop
              // target. Without it the browser refuses the drop and the row
              // looks like it simply does not reorder.
              onDragOver={reorder ? (e) => { e.preventDefault(); if (dragOver !== i) setDragOver(i); } : undefined}
              onDrop={reorder ? (e) => { e.preventDefault(); if (dragFrom !== null) move(dragFrom, i); setDragFrom(null); setDragOver(null); } : undefined}
              style={{
                position: 'relative',
                width: 64,
                height: 64,
                borderRadius: 8,
                overflow: 'hidden',
                border: `1px solid ${dragOver === i && dragFrom !== null && dragFrom !== i ? C.amber : C.line}`,
                opacity: dragFrom === i ? 0.4 : 1,
                cursor: reorder ? 'grab' : 'default',
              }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={a.url} alt="" width={64} height={64} style={{ objectFit: 'cover' }} draggable={false} />
              <button
                type="button"
                className="tb-btn"
                draggable={false}
                onClick={() => props.onRemove(a.name)}
                style={{ position: 'absolute', top: 2, right: 2, width: 18, height: 18, borderRadius: '50%', border: 'none', background: 'rgba(0,0,0,0.6)', color: '#fff', fontSize: 11, lineHeight: '18px', padding: 0 }}
                aria-label="remove"
              >
                ×
              </button>
              {reorder && i === 0 ? (
                // Named, not numbered. "1" invites reading the rest as a
                // ranking, which they are not: every entry after the first is
                // just available, and only this one is applied on install.
                <span
                  style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: C.amber, color: C.onAccent, fontFamily: C.mono, fontSize: 8, letterSpacing: '0.06em', textAlign: 'center', padding: '2px 0' }}
                >
                  ON INSTALL
                </span>
              ) : null}
            </div>
            {onFrame ? (
              <button
                type="button"
                className="tb-btn"
                onClick={() => setFraming(framing === a.name ? null : a.name)}
                style={{ width: '100%', marginTop: 3, background: framing === a.name ? C.chip : 'transparent', border: `1px solid ${meta[a.name] ? C.amber : C.line}`, borderRadius: 5, color: meta[a.name] ? C.inkStrong : C.dim, fontFamily: C.mono, fontSize: 9, lineHeight: '15px', padding: 0 }}
              >
                {meta[a.name] ? 'framed' : 'frame'}
              </button>
            ) : null}
            {reorder ? (
              <div style={{ display: 'flex', gap: 2, marginTop: 3 }}>
                <button
                  type="button"
                  className="tb-btn"
                  disabled={i === 0}
                  onClick={() => move(i, i - 1)}
                  aria-label={`move ${a.name} earlier`}
                  style={{ flex: 1, background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 5, color: i === 0 ? C.faint : C.dim, fontFamily: C.mono, fontSize: 10, lineHeight: '14px', padding: 0 }}
                >
                  ‹
                </button>
                <button
                  type="button"
                  className="tb-btn"
                  disabled={i === props.assets.length - 1}
                  onClick={() => move(i, i + 1)}
                  aria-label={`move ${a.name} later`}
                  style={{ flex: 1, background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 5, color: i === props.assets.length - 1 ? C.faint : C.dim, fontFamily: C.mono, fontSize: 10, lineHeight: '14px', padding: 0 }}
                >
                  ›
                </button>
              </div>
            ) : null}
          </div>
        ))}
        <button
          type="button"
          className="tb-btn"
          onClick={() => ref.current?.click()}
          style={{ width: 64, height: 64, borderRadius: 8, border: `1px dashed ${C.line}`, background: C.bg, color: C.faint, fontFamily: C.mono, fontSize: 11 }}
        >
          + add
        </button>
        {/* MULTIPLE. Picking one at a time meant seven trips through the file
            dialog for a distro with seven wallpapers, and the names come from
            the files themselves, so a batch behaves exactly like the same files
            picked one by one: same-name replaces, new names append. */}
        <input ref={ref} type="file" multiple accept="image/webp,image/png,image/jpeg" style={{ display: 'none' }} onChange={(e) => { const picked = Array.from(e.target.files ?? []); if (picked.length) props.onAdd(picked); e.target.value = ''; }} />
      </div>
      {onFrame && framing
        ? (() => {
            const asset = props.assets.find((x) => x.name === framing);
            if (!asset) return null;
            return (
              <WallpaperFramer
                asset={asset}
                meta={meta[framing] ?? {}}
                onChange={(m) => onFrame(framing, m)}
                onClose={() => setFraming(null)}
              />
            );
          })()
        : null}
    </Field>
  );
}

/**
 * Set the fit and the focal point for one wallpaper.
 *
 * ─── WHY THE PREVIEW IS PHONE-SHAPED AND NOT THE IMAGE ───────────────────────
 *
 * The question this answers is not "where is the dragon in this picture", which
 * the thumbnail already shows. It is "what survives being cropped to a phone",
 * and those differ exactly when the source is not phone-shaped, which is the
 * only case where framing does anything. So the box is 9:19.5 and the image
 * moves inside it, the same arrangement the device's own framing screen uses,
 * because an author checking their work against a differently shaped preview is
 * checking it against a phone nobody owns.
 *
 * ─── THE DRAG IS ON THE FITS THAT CAN USE IT ─────────────────────────────────
 *
 * `fill` and `contain` put every pixel of the source on screen, so there is
 * nothing to choose between and the device ignores the focal point for them.
 * Offering a drag that does nothing would be a control lying about its effect,
 * so the preview stops accepting one and says which fits do.
 */
function WallpaperFramer(props: {
  asset: Asset;
  meta: WallpaperMetaJson;
  onChange: (meta: WallpaperMetaJson | null) => void;
  onClose: () => void;
}) {
  const fit = (props.meta.fit ?? 'fill') as WallpaperFit;
  const focalX = props.meta.focalX ?? 0.5;
  const focalY = props.meta.focalY ?? 0.5;
  const zoom = props.meta.zoom ?? 1;
  const framable = fit === 'cover' || fit === 'center';
  const box = React.useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = React.useState(false);

  const patch = (p: Partial<WallpaperMetaJson>) =>
    props.onChange({ fit, focalX, focalY, zoom, ...p });

  const onMove = (e: React.PointerEvent) => {
    if (!dragging || !framable) return;
    const r = box.current?.getBoundingClientRect();
    if (!r || !r.width || !r.height) return;
    // Inverted, and scaled by 0.8, matching the device screen exactly: dragging
    // the picture left moves the window right, and a full sweep crosses most of
    // the image rather than all of it so the ends stay reachable.
    patch({
      focalX: Math.min(1, Math.max(0, focalX - (e.movementX / r.width) * 0.8)),
      focalY: Math.min(1, Math.max(0, focalY - (e.movementY / r.height) * 0.8)),
    });
  };

  const objectFit: React.CSSProperties['objectFit'] =
    fit === 'contain' ? 'contain' : fit === 'fill' ? 'fill' : fit === 'center' ? 'none' : 'cover';

  return (
    <div style={{ marginTop: 14, padding: 14, border: `1px solid ${C.line}`, borderRadius: 10, background: C.bg, display: 'flex', gap: 16, alignItems: 'flex-start' }}>
      <div
        ref={box}
        onPointerDown={(e) => { if (framable) { setDragging(true); e.currentTarget.setPointerCapture(e.pointerId); } }}
        onPointerMove={onMove}
        onPointerUp={() => setDragging(false)}
        onPointerCancel={() => setDragging(false)}
        style={{ width: 108, height: 234, flex: '0 0 auto', borderRadius: 10, overflow: 'hidden', border: `1px solid ${C.line}`, background: '#000', cursor: framable ? (dragging ? 'grabbing' : 'grab') : 'default', touchAction: 'none' }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={props.asset.url}
          alt=""
          draggable={false}
          style={{
            width: '100%',
            height: '100%',
            objectFit,
            objectPosition: `${focalX * 100}% ${focalY * 100}%`,
            transform: `scale(${zoom})`,
            transformOrigin: `${focalX * 100}% ${focalY * 100}%`,
          }}
        />
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.ink, marginBottom: 10, wordBreak: 'break-all' }}>{props.asset.name}</div>

        <div style={{ display: 'flex', gap: 4, marginBottom: 10 }}>
          {WALLPAPER_FITS.map((f) => (
            <button
              key={f}
              type="button"
              className="tb-btn"
              onClick={() => patch({ fit: f })}
              style={{ background: f === fit ? C.amber : 'transparent', color: f === fit ? C.onAccent : C.dim, border: `1px solid ${f === fit ? C.amber : C.line}`, borderRadius: 6, fontFamily: C.mono, fontSize: 10.5, padding: '5px 9px' }}
            >
              {f}
            </button>
          ))}
        </div>

        <div style={{ fontFamily: C.mono, fontSize: 10.5, color: C.faint, lineHeight: 1.6, marginBottom: 10 }}>
          {framable
            ? `drag the preview · focal ${Math.round(focalX * 100)}% ${Math.round(focalY * 100)}%`
            : 'this fit shows the whole image, so there is nothing to reposition'}
        </div>

        {framable ? (
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: C.mono, fontSize: 10.5, color: C.dim, marginBottom: 12 }}>
            zoom
            <input
              type="range"
              min={1}
              max={4}
              step={0.05}
              value={zoom}
              onChange={(e) => patch({ zoom: Number(e.target.value) })}
              style={{ flex: 1 }}
            />
            {zoom.toFixed(2)}
          </label>
        ) : null}

        <div style={{ display: 'flex', gap: 8 }}>
          <button type="button" className="tb-btn" onClick={() => props.onChange(null)} style={{ background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 6, color: C.dim, fontFamily: C.mono, fontSize: 10.5, padding: '5px 11px' }}>
            reset
          </button>
          <button type="button" className="tb-btn" onClick={props.onClose} style={{ background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 6, color: C.dim, fontFamily: C.mono, fontSize: 10.5, padding: '5px 11px' }}>
            done
          </button>
        </div>
      </div>
    </div>
  );
}

function AssetSlot(props: { label: string; asset: Asset | null; onPick: (file: File) => void; onClear: () => void }) {
  const ref = React.useRef<HTMLInputElement>(null);
  return (
    <Field label={props.label} hint="svg, png or webp">
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        <button
          type="button"
          className="tb-btn"
          onClick={() => ref.current?.click()}
          style={{ width: 52, height: 52, borderRadius: 8, border: props.asset ? 'none' : `1px dashed ${C.line}`, background: props.asset ? '#000' : C.bg, overflow: 'hidden', color: C.faint, fontFamily: C.mono, fontSize: 10 }}
        >
          {props.asset ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={props.asset.url} alt="" width={52} height={52} style={{ objectFit: 'contain' }} />
          ) : (
            '+ logo'
          )}
        </button>
        {props.asset ? (
          <button type="button" className="tb-btn" onClick={props.onClear} style={{ background: 'none', border: 'none', color: C.dim, fontFamily: C.mono, fontSize: 11 }}>
            clear
          </button>
        ) : null}
        <input ref={ref} type="file" accept="image/svg+xml,image/png,image/webp" style={{ display: 'none' }} onChange={(e) => { const f = e.target.files?.[0]; if (f) props.onPick(f); e.target.value = ''; }} />
      </div>
    </Field>
  );
}

/**
 * One sku, chosen rather than typed, when Play can be read.
 *
 * ─── DERIVED FIRST, PLAY SECOND, CUSTOM LAST ────────────────────────────────
 *
 * The empty value keeps its old meaning: raw '' means "derive from the distro
 * id", so the default tracks a renamed id instead of pinning a stale string,
 * exactly as the text input behaved. The Play products of the matching prefix
 * come next, because picking an existing product is the case that can never
 * typo. Custom reveals the plain input for a product being named before it is
 * created in Play, which is a legitimate order of operations: the ID is chosen
 * here first and created there second.
 *
 * A select cannot express "Play is down", so when the catalogue could not be
 * read this degrades to the text input it replaced, unchanged, with the status
 * line saying why nothing can be confirmed. The field must never be less
 * usable than it was before Play was consulted.
 *
 * The status line below is ADVISORY and stays out of `allProblems`: a missing
 * product is a to-do in Play Console, not an error in this draft, and blocking
 * publish on it would force products to be created before the pack they sell.
 * `skuProblems` (shape) still gates as before.
 */
function SkuField(props: {
  label: string;
  hint?: string;
  kind: 'distro' | 'icons';
  /** The sku the empty value resolves to, '' when no distro id is set yet. */
  derived: string;
  placeholder: string;
  raw: string;
  setRaw: (v: string) => void;
  play: PlayLite;
}) {
  const listed = props.play.ok
    ? props.play.products.filter((p) => p.productId.startsWith(SKU_PREFIX[props.kind]))
    : [];

  // Custom starts on when the opened draft carries a sku Play does not list;
  // showing that as a select value would invent an option, and hiding it would
  // silently discard it.
  const [custom, setCustom] = React.useState<boolean>(
    () => props.raw !== '' && !listed.some((p) => p.productId === props.raw),
  );

  const effective = props.raw.trim() || props.derived;

  if (!props.play.ok) {
    return (
      <Field label={props.label} hint={props.hint}>
        <TextInput value={props.raw} placeholder={props.placeholder} onChange={props.setRaw} />
        {effective ? <PlayNote play={props.play} sku={effective} /> : null}
      </Field>
    );
  }

  const options = ['', ...listed.map((p) => p.productId), '__custom'];

  // THE LABEL DEPENDS ON WHERE THE ID CAME FROM. '(not active)' is a
  // measurement and may only be said about a product read from Play just now;
  // for a snapshot or an index-derived id, activeOptions is a placeholder zero
  // and rendering it as "not active" would be a fabricated verdict on
  // something nobody checked.
  const labels: Record<string, string> = {
    '': props.derived ? `derived: ${props.derived}` : 'derived from distro id',
    ...Object.fromEntries(
      listed.map((p) => [
        p.productId,
        p.source === 'play'
          ? p.activeOptions === 0
            ? `${p.productId} (not active)`
            : p.productId
          : p.source === 'snapshot'
            ? `${p.productId} (last seen in Play)`
            : `${p.productId} (in the catalogue)`,
      ]),
    ),
    __custom: 'custom ID',
  };

  return (
    <Field label={props.label} hint={props.hint}>
      <SelectInput<string>
        value={custom ? '__custom' : props.raw}
        options={options}
        labels={labels}
        onChange={(v) => {
          if (v === '__custom') {
            setCustom(true);
            return;
          }
          setCustom(false);
          props.setRaw(v);
        }}
      />
      {custom ? (
        <div style={{ marginTop: 8 }}>
          <TextInput value={props.raw} placeholder={props.placeholder} onChange={props.setRaw} />
        </div>
      ) : null}
      {effective ? <PlayNote play={props.play} sku={effective} /> : null}
    </Field>
  );
}

/**
 * Said once above the pricing fields when the ids below did not come from Play.
 *
 * Per-field it would repeat four times for one fact, and the fact is about the
 * whole list rather than about any one product.
 */
function SkuSourceNote({ play }: { play: PlayLite }) {
  if (!play.ok || !play.degraded) return null;
  const at = play.degraded.snapshotAt
    ? new Date(play.degraded.snapshotAt * 1000).toISOString().slice(0, 10)
    : null;
  return (
    <div
      style={{
        fontFamily: C.mono,
        fontSize: 11.5,
        lineHeight: 1.6,
        color: C.warn,
        border: `1px solid ${C.line}`,
        borderRadius: 8,
        padding: '9px 11px',
        marginBottom: 12,
      }}
    >
      Play could not be read, so these product IDs come from{' '}
      {at ? `the last successful read on ${at} and ` : ''}the published catalogue. The IDs are
      real; whether Play can charge for them is unknown until it answers. {play.degraded.reason}
    </div>
  );
}

/** The status line: can [sku] actually be bought? Tone follows playSkuNote. */
function PlayNote({ play, sku }: { play: PlayLite; sku: string }) {
  const note = playSkuNote(play, sku);
  const color = note.tone === 'ok' ? C.green : note.tone === 'warn' ? C.amber : C.faint;
  return (
    <div style={{ fontFamily: C.mono, fontSize: 11.5, lineHeight: 1.5, color, marginTop: 6 }}>
      {note.text}
    </div>
  );
}

/**
 * The import panel: a paste box and a file picker feeding one parse path.
 *
 * The panel owns its text, error, and notes, so closing it clears them, which
 * is the lifetime the feedback should have: notes are the "fix before
 * publishing" list for THIS import, not a permanent banner. The parent owns
 * what applying means; the union it returns is rendered here and nothing else
 * crosses back.
 *
 * A picked file is read into the textarea before applying, so what was
 * imported is visible and can be edited and re-applied, which makes the file
 * path and the paste path the same path with one extra click.
 */
function ImportPanel(props: {
  onApply: (raw: string) => { error: string } | { notes: string[] };
}) {
  const [text, setText] = React.useState('');
  const [error, setError] = React.useState<string | null>(null);
  const [notes, setNotes] = React.useState<string[]>([]);
  const fileRef = React.useRef<HTMLInputElement>(null);

  function run(raw: string) {
    const out = props.onApply(raw);
    if ('error' in out) {
      setError(out.error);
      setNotes([]);
    } else {
      setError(null);
      setNotes(out.notes);
    }
  }

  return (
    <div
      style={{
        border: `1px solid ${C.line}`,
        borderRadius: 10,
        background: C.surface,
        padding: 14,
        marginBottom: 14,
      }}
    >
      <div style={{ fontFamily: C.mono, fontSize: 12.5, color: C.inkStrong }}>
        import theme.json
        <span style={{ color: C.faint }}>
          {' '}
          · replaces the theme being edited. Pricing, card title, and summary are untouched.
        </span>
      </div>
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder='{"id": "kali-theme", "name": "Kali Linux", "palette": { ... } }'
        spellCheck={false}
        style={{
          width: '100%',
          minHeight: 130,
          resize: 'vertical',
          marginTop: 10,
          padding: 10,
          fontFamily: C.mono,
          fontSize: 12,
          lineHeight: 1.6,
          color: C.inkStrong,
          background: C.bg,
          border: `1px solid ${C.line}`,
          borderRadius: 8,
        }}
      />
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
        <button
          type="button"
          className="tb-btn"
          onClick={() => fileRef.current?.click()}
          style={{ fontFamily: C.mono, fontSize: 12, color: C.ink, background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 7, padding: '6px 12px' }}
        >
          pick a .json file
        </button>
        <button
          type="button"
          className="tb-btn"
          disabled={!text.trim()}
          onClick={() => run(text)}
          style={{ fontFamily: C.mono, fontSize: 12, color: text.trim() ? C.inkStrong : C.faint, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 7, padding: '6px 14px' }}
        >
          apply
        </button>
      </div>
      <input
        ref={fileRef}
        type="file"
        accept="application/json,.json"
        style={{ display: 'none' }}
        onChange={(ev) => {
          const f = ev.target.files?.[0];
          ev.target.value = '';
          if (!f) return;
          void f.text().then((raw) => {
            setText(raw);
            run(raw);
          });
        }}
      />
      {error ? (
        <div style={{ fontFamily: C.mono, fontSize: 11.5, lineHeight: 1.6, color: C.red, marginTop: 10 }}>
          {error}
        </div>
      ) : null}
      {notes.length > 0 ? (
        <div style={{ fontFamily: C.mono, fontSize: 11.5, lineHeight: 1.7, color: C.amber, marginTop: 10 }}>
          <div>Imported with notes. Publishing before fixing them ships the theme as imported.</div>
          {notes.map((n, i) => (
            <div key={i}>· {n}</div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
