'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { BuilderShell, useToast } from '@/components/console';
import { Section, Field, TextInput, NumberInput, SelectInput, Segmented, Toggle } from '@/components/theme-builder/primitives';
import { PaletteEditor, LayoutEditor, IconStyleEditor, PassthroughEditor } from '@/components/theme-builder/editors';
import { ThemePreview } from '@/components/theme-builder/ThemePreview';
import { GeneratedJson } from '@/components/theme-builder/GeneratedJson';
import { AppGrid, type Assignment } from './AppGrid';
import { publishDistroAction } from '@/app/apps/[app]/distros/actions';
import {
  blankDraft,
  importTheme,
  isSafePackId,
  validateDraft,
  type ChromeName,
  type ShellName,
  type ThemeDraft,
  type ThemeSpecJson,
  CHROMES,
  SHELLS,
} from '@/lib/theme-spec';
import { COMMON_APPS, validateHeroPack, type HeroIconEntry } from '@/lib/hero-pack';
import { playSkuNote, type PlayLite } from '@/lib/play-lite';
import { SKU_PREFIX, distroSkuFor, iconsSkuFor, skuProblems } from '@/lib/skus';

/**
 * Did the opened theme reference any wallpaper, and any logo.
 *
 * REPLACES `assetNamesOf`, which returned the bare FILENAMES a theme referenced
 * so they could be matched one-for-one against what the author uploaded. That
 * match could never succeed. Wallpaper uploads are named `wall_<timestamp>` and
 * the references are authored names, so a theme that already had wallpapers had
 * its publish button disabled forever. Names are no longer compared; only
 * presence is, per kind.
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

type Tab = 'theme' | 'icons' | 'pricing';

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

export function DistroWorkspace({
  app,
  initial = null,
  heroPacks = [],
  heroPacksUnreadable = false,
  play,
}: {
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

  // The distro id, from which both pack ids and both SKUs derive. An existing
  // theme's pack id IS that id, so opening one seeds it and every derived
  // field falls out unchanged.
  const [base, setBase] = React.useState(initial?.id ?? '');

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

  // theme assets
  const [wallpapers, setWallpapers] = React.useState<Asset[]>([]);
  const [logoLight, setLogoLight] = React.useState<Asset | null>(null);
  const [logoDark, setLogoDark] = React.useState<Asset | null>(null);

  // icons
  const [entries, setEntries] = React.useState<{ pkg: string; label: string }[]>(() => [...COMMON_APPS]);
  const [assignments, setAssignments] = React.useState<Record<string, Assignment>>({});
  const [iconName, setIconName] = React.useState('');

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
    return { notes: imported.notes };
  }

  const setS = (p: Partial<ThemeSpecJson>) => setSpec((s) => ({ ...s, ...p }));

  const themePackId = base ? `${base}-theme` : '';
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

  const order = React.useMemo(
    () => entries.filter((e) => assignments[e.pkg]).map((e) => ({ pkg: e.pkg, file: assignments[e.pkg].file })),
    [entries, assignments],
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
      logo,
      // `?? undefined` rather than null: `pruneIcons` in theme-spec drops absent
      // keys, and a distro with no hero pack should ship no key at all rather
      // than an explicit null that reads as a deliberate empty.
      icons: { ...spec.icons, heroPack: heroPackId ?? undefined },
    };
  }, [spec, themePackId, wallpapers, logoLight, logoDark, heroPackId]);

  const themeDraft: ThemeDraft = {
    id: themePackId,
    title: cardTitle || spec.name,
    summary: cardSummary,
    sku: distroSku,
    bundled: false,
    packVersion: 1,
    updatedAt: 0,
    spec: effectiveSpec,
  };

  const baseProblems: string[] = [];
  if (!base) baseProblems.push('Set a distro id (e.g. kali)');
  else if (!isSafePackId(base)) baseProblems.push('Distro id must be lowercase letters, digits, . _ or -');

  const themeProblems = base ? validateDraft(themeDraft) : [];
  const iconProblems = hasIcons
    ? validateHeroPack(
        {
          id: iconPackId,
          name: iconName || `${spec.name} icons`,
          minAppVersion: spec.minAppVersion,
          masked: false,
          sku: iconsSku,
        },
        entries.map<HeroIconEntry>((e) => ({ pkg: e.pkg, label: e.label, file: assignments[e.pkg]?.file ?? '' })),
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
  function onAddApp(pkg: string, label: string) {
    setEntries((prev) => (prev.some((e) => e.pkg === pkg) ? prev : [{ pkg, label }, ...prev]));
  }

  async function pickAsset(file: File, name: string, set: (a: Asset) => void) {
    const blob = file;
    set({ name, blob, url: URL.createObjectURL(blob) });
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
            }
          : null,
        distroSku,
        distroTitle: cardTitle || spec.name,
        distroSummary: cardSummary,
      };

      const fd = new FormData();
      fd.append('meta', JSON.stringify(meta));
      for (const w of wallpapers) fd.append(`asset:${w.name}`, w.blob, w.name);
      if (logoLight) fd.append(`asset:${logoLight.name}`, logoLight.blob, logoLight.name);
      if (logoDark && logoDark.name !== logoLight?.name) fd.append(`asset:${logoDark.name}`, logoDark.blob, logoDark.name);
      for (const o of order) fd.append(`icon:${o.file}`, assignments[o.pkg].blob, o.file);

      const res = await publishDistroAction(fd);
      if (res.ok) toast.success(`Published ${base}: theme v${res.themeVersion}${res.iconVersion ? `, icons v${res.iconVersion}` : ''}`);
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


        <div className="dw-grid">
          <div>
            {tab === 'theme' ? (
              <>
                <Section title="distro" hint="one id; the theme and icon packs derive from it">
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0 14px' }}>
                    <Field label="distro id" hint="lowercase, e.g. kali">
                      <TextInput value={base} placeholder="kali" onChange={(v) => setBase(v.trim())} />
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
                    <Field label="display font">
                      <TextInput value={spec.typography?.display ?? ''} placeholder="Ubuntu" onChange={(v) => setS({ typography: { ...spec.typography, display: v || null } })} />
                    </Field>
                    <Field label="mono font">
                      <TextInput value={spec.typography?.mono ?? ''} placeholder="UbuntuMono" onChange={(v) => setS({ typography: { ...spec.typography, mono: v || null } })} />
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
                </Section>

                <Section title="icon shape" hint="the general look; specific app icons live in the Icons tab">
                  <IconStyleEditor icons={spec.icons ?? {}} setIcons={(p) => setSpec((s) => ({ ...s, icons: { ...(s.icons ?? {}), ...p } }))} />
                </Section>

                <Section title="wallpapers & logo" hint="uploaded and shipped inside the pack as bare files">
                  <AssetList
                    label="wallpapers"
                    assets={wallpapers}
                    onAdd={(file) => pickAsset(file, `wall_${Date.now().toString(36)}.${extFor(file)}`, (a) => setWallpapers((w) => [...w, a]))}
                    onRemove={(name) => setWallpapers((w) => w.filter((x) => x.name !== name))}
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

      <Section title="pricing" hint="a paid distro is two products: the whole distro, and its icons alone">
        <div style={{ marginBottom: 14 }}>
          <Toggle value={props.free} label="Free distro (no purchase)" onChange={props.setFree} />
        </div>
        {!props.free ? (
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
function AssetList(props: { label: string; assets: Asset[]; onAdd: (file: File) => void; onRemove: (name: string) => void }) {
  const ref = React.useRef<HTMLInputElement>(null);
  return (
    <Field label={props.label} hint="webp or png; shipped at full resolution">
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center' }}>
        {props.assets.map((a) => (
          <div key={a.name} style={{ position: 'relative', width: 64, height: 64, borderRadius: 8, overflow: 'hidden', border: `1px solid ${C.line}` }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={a.url} alt="" width={64} height={64} style={{ objectFit: 'cover' }} />
            <button
              type="button"
              className="tb-btn"
              onClick={() => props.onRemove(a.name)}
              style={{ position: 'absolute', top: 2, right: 2, width: 18, height: 18, borderRadius: '50%', border: 'none', background: 'rgba(0,0,0,0.6)', color: '#fff', fontSize: 11, lineHeight: '18px', padding: 0 }}
              aria-label="remove"
            >
              ×
            </button>
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
        <input ref={ref} type="file" accept="image/webp,image/png,image/jpeg" style={{ display: 'none' }} onChange={(e) => { const f = e.target.files?.[0]; if (f) props.onAdd(f); e.target.value = ''; }} />
      </div>
    </Field>
  );
}

function AssetSlot(props: { label: string; asset: Asset | null; onPick: (file: File) => void; onClear: () => void }) {
  const ref = React.useRef<HTMLInputElement>(null);
  return (
    <Field label={props.label} hint="svg or png">
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
  const labels: Record<string, string> = {
    '': props.derived ? `derived: ${props.derived}` : 'derived from distro id',
    ...Object.fromEntries(
      listed.map((p) => [
        p.productId,
        p.activeOptions === 0 ? `${p.productId} (not active)` : p.productId,
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
