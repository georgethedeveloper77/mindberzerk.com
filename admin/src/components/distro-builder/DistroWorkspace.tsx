'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { BuilderShell, useToast } from '@/components/console';
import { Section, Field, TextInput, NumberInput, SelectInput, Toggle } from '@/components/theme-builder/primitives';
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
import { distroSkuFor, iconsSkuFor, skuProblems } from '@/lib/skus';

/**
 * Every file a theme.json references, as bare filenames.
 *
 * Deliberately tolerant of both shapes it can meet: a bundled theme carries
 * APK-relative paths, a published one carries bare names, and this has to
 * report the same list for both. The last path segment is the answer in either
 * case, and it is also what `PackPaths.installedFile` on the device will accept.
 */
function assetNamesOf(spec: ThemeSpecJson): string[] {
  const out: string[] = [];
  const push = (v: unknown) => {
    if (typeof v === 'string' && v.trim()) out.push(v.split('/').pop()!.trim());
  };

  for (const w of spec.wallpapers ?? []) push(w);

  const logo = spec.logo;
  if (typeof logo === 'string') push(logo);
  else if (logo && typeof logo === 'object') {
    const l = logo as Record<string, unknown>;
    push(l.light);
    push(l.dark);
  }

  const splash = spec.splash;
  if (splash && typeof splash === 'object') push((splash as Record<string, unknown>).logo);

  return [...new Set(out)];
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
   * Asset filenames the OPENED theme referenced, as bare names.
   *
   * ─── THE BUG THIS EXISTS TO STOP, WHICH IS WORSE THAN IT LOOKS ───────────
   *
   * `effectiveSpec` below rewrites `wallpapers` and `logo` from the UPLOADED
   * files, which is correct: a published pack is flat, so the references have
   * to be the bare names of the files actually going into it.
   *
   * But it rewrites them unconditionally. Open Ubuntu, which references three
   * wallpapers and two logos, change the accent colour, and publish without
   * touching the assets tab, and `wallpapers` becomes `[]` and `logo` becomes
   * undefined. The pack publishes cleanly. The flat-path gate never fires,
   * because there are no paths left to be unflat. Every device that installs it
   * gets a distro with no wallpaper and the Mindhunter fallback mark, and
   * nothing anywhere reported a problem.
   *
   * That is strictly worse than the refusal I expected: a refusal tells you
   * what to fix. So the references are captured at open, and any that have no
   * matching upload become a publish-blocking problem naming the file.
   *
   * Flattened on capture because the bundled themes carry APK-relative paths
   * (`assets/themes/ubuntu-24-04/wallpapers/numbat_color.webp`) and what has to
   * be uploaded is `numbat_color.webp`.
   */
  const [requiredAssets] = React.useState<string[]>(() =>
    initial ? assetNamesOf(initial.spec) : [],
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

  const [publishing, setPublishing] = React.useState(false);
  const toast = useToast();

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
  const hasIcons = order.length > 0;

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
    };
  }, [spec, themePackId, wallpapers, logoLight, logoDark]);

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

  // Names as they will ship. Logos are renamed to logo_light/logo_dark on pick,
  // which is why a theme whose logo was already called that matches without the
  // author doing anything.
  const uploadedNames = new Set<string>([
    ...wallpapers.map((w) => w.name),
    ...(logoLight ? [logoLight.name] : []),
    ...(logoDark ? [logoDark.name] : []),
  ]);
  const missingAssets = requiredAssets.filter((n) => !uploadedNames.has(n));

  const assetProblems = missingAssets.map(
    (n) =>
      `${n} is referenced by this theme and no file has been uploaded for it. ` +
      'Publishing now would ship the pack without it, silently.',
  );

  const allProblems = [
    ...baseProblems,
    ...themeProblems,
    ...iconProblems,
    ...skuIssues,
    ...assetProblems,
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
        <button type="button" className="tb-btn" disabled={!valid || publishing} onClick={publish} style={{ fontFamily: C.mono, fontWeight: 700, fontSize: 12.5, color: C.onAccent, background: C.amber, border: 'none', borderRadius: 7, padding: '8px 16px' }}>
          {publishing ? 'publishing…' : 'publish distro'}
        </button>
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
                  <PaletteEditor palette={spec.palette} setPalette={(p) => setSpec((s) => ({ ...s, palette: { ...s.palette, ...p } }))} />
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
                <Section title="icon pack" hint={hasIcons ? `${order.length} assigned` : 'optional - a distro can ship with no icon pack'}>
                  <Field label="icon pack name">
                    <TextInput value={iconName} placeholder={`${spec.name || 'Kali'} icons`} mono={false} onChange={setIconName} />
                  </Field>
                  <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: -4 }}>
                    ships as <span style={{ color: C.dim }}>{iconPackId || '<distro>-icons'}</span>
                    {iconsSku ? <> · sold alone as <span style={{ color: C.dim }}>{iconsSku}</span></> : ' · free'}
                  </div>
                </Section>
                <Section title="app icons" hint="assign an image per app; the rest inherit the theme's icon shape">
                  <AppGrid entries={entries} assignments={assignments} masked={false} onAssign={onAssign} onAddApp={onAddApp} />
                </Section>
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
            <Field label="whole-distro sku" hint="unlocks theme + icons">
              <TextInput value={props.distroSkuRaw} placeholder={props.base ? distroSkuFor(props.base) : 'distro_kali'} onChange={props.setDistroSkuRaw} />
            </Field>
            <Field label="icons-alone sku" hint="unlocks the icon pack only">
              <TextInput value={props.iconsSkuRaw} placeholder={props.base ? iconsSkuFor(props.base) : 'icons_kali'} onChange={props.setIconsSkuRaw} />
            </Field>
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
