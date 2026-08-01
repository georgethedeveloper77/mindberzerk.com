'use client';

import { useCallback, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { expandPicked, LICENSE_ATTESTATION, type RefusedFile } from '@/lib/g-launcher/bulk-icons';
import {
  CORE_PACKAGES,
  buildHeroPackJson,
  fileNameFor,
  guessPackage,
  isPackageName,
} from '@/lib/g-launcher/icon-pack';
import { renderHeroIcon } from '@/lib/core/image-trim';
import { playSkuNote, type PlayLite } from '@/lib/core/play-lite';
import { SKU_PREFIX, iconsSkuFor, skuProblems } from '@/lib/core/skus';
import type { RehydratedPack } from '@/lib/core/cdn';

/**
 * RESTYLED ONTO THE SOFT REGISTER. This file was the one builder that did NOT
 * move when `theme-builder/console.tsx` was retargeted, because it never used
 * the `C` map: it writes Tailwind classes directly, so the console's dark-only
 * tokens were baked into the markup rather than resolved through one variable
 * map. Every colour here is a `site-` token now, which has a value in both
 * modes.
 *
 * PHASE C8 - the hero pack builder, corrected to the launcher's reader.
 *
 * ## What changed after reading HeroIconResolver / IconRenderer
 *
 * The per-icon fit and scale controls are GONE, because the format has neither.
 * `renderHero` draws hero art at native size and ignores foregroundScale, and
 * the `icons` map is packageName -> filename with no per-entry options. What
 * remains is one pack-level `masked` flag: false (the default) for final art
 * with its own transparency, true for square full-bleed art the theme masks.
 *
 * ## The preview mirrors renderHero, not a guess
 *
 *  - masked=false: draw the PNG as-is on a neutral field, because that is
 *    literally `drawLayer(canvas, hero, sizePx, 1.0f, null)`.
 *  - masked=true: clip to the theme's shape and fill the plate behind, because
 *    that is the `clipPath(maskPath)`, `fillBackground`, `drawLayer` branch.
 *
 * So the plate colour and corner radius only affect the preview when masked is
 * on, exactly as they only affect the device then.
 *
 * ## It reuses /api/publish/pack unchanged
 *
 * Browser produces PNGs plus pack.json; posted as files[]/paths[] with
 * packType: hero. Same manifest, signature and rollback floor as every pack.
 */

interface Entry {
  id: string;
  file: File;
  pkg: string;
  url: string | null;
  blob: Blob | null;
  aspect: number;
  error: string | null;
  busy: boolean;
}

/**
 * Decode one `data:` URL into a Blob, synchronously.
 *
 * Synchronous is the whole point. It means a published pack becomes real
 * entries inside a `useState` initialiser, with no effect, no loading state and
 * no window in which the builder is mounted but empty. It also means nothing
 * re-runs when the parent re-renders: `router.refresh()` fires after every
 * publish, and an effect keyed on `initial` would wipe the author's unsaved
 * edits each time it did.
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

/**
 * A published pack's icons as builder entries.
 *
 * `url` is the data URL itself rather than an object URL, deliberately. It is a
 * valid `src`, so the preview works with no extra step, and there is no handle
 * to revoke. `render` calls `URL.revokeObjectURL(entry.url)` when an entry is
 * replaced, and that is a harmless no-op on a `data:` URL, so a rehydrated icon
 * can be swapped for a new upload with no special case anywhere.
 *
 * `aspect` is 1 because these bytes already went through `renderHeroIcon` before
 * they were published, which letterboxes everything to a square. The
 * not-square warning would be a lie here.
 */
function entriesFrom(initial: RehydratedPack | null | undefined): Entry[] {
  if (!initial) return [];
  return initial.icons.map((ic) => {
    const blob = blobFromDataUrl(ic.dataUrl);
    return {
      id: `published-${ic.pkg}`,
      file: new File([blob], ic.file, { type: blob.type || 'image/png' }),
      pkg: ic.pkg,
      url: ic.dataUrl,
      blob,
      aspect: 1,
      error: null,
      busy: false,
    };
  });
}

export function IconBuilder({
  app,
  publishedIds,
  publishedVersion,
  initial,
  play,
}: {
  app: string;
  publishedIds: string[];
  publishedVersion: Record<string, number>;
  /** A published pack to edit, or null for a new one. See `lib/cdn.ts`. */
  initial?: RehydratedPack | null;
  /**
   * What Play actually sells, slimmed, read on the server. `ok: false`
   * degrades the product ID field to the plain input it used to be, with the
   * reason, because publishing does not depend on Play and the field must not
   * become less usable than before Play was consulted.
   */
  play: PlayLite;
}) {
  const router = useRouter();

  const [packId, setPackId] = useState(initial?.packId ?? '');
  const [name, setName] = useState(initial?.name ?? '');
  const [minAppVersion, setMinAppVersion] = useState(String(initial?.minAppVersion ?? 6));
  const [masked, setMasked] = useState(initial?.masked ?? false);
  const [sku, setSku] = useState(initial?.sku ?? '');
  // Custom mode starts on only when the opened pack carries a sku that is
  // neither in Play nor this pack's derived id; every option path covers the
  // rest, and hiding a real sku behind a mismatched select would discard it.
  const [customSku, setCustomSku] = useState<boolean>(() => {
    const s = initial?.sku ?? '';
    if (s === '' || !play.ok) return false;
    if (play.products.some((p) => p.productId === s)) return false;
    return s !== (initial?.packId ? iconsSkuFor(initial.packId) : '');
  });
  const [plate, setPlate] = useState('#E95420'); // preview only, not in pack.json
  const [radius, setRadius] = useState(22); // preview only, percent
  const [entries, setEntries] = useState<Entry[]>(() => entriesFrom(initial));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);

  // Named refusals from the last intake: license-marked SVGs, unreadable zips,
  // skipped non-images. Replaced per pick rather than accumulated, because the
  // question they answer is "what happened to what I just dropped".
  const [refused, setRefused] = useState<RefusedFile[]>([]);

  // The human half of the license gate; the scan in bulk-icons is the other.
  // Starts true only when editing a pack that already shipped, since that
  // attestation was made when it was first published.
  const [licensed, setLicensed] = useState<boolean>(() => !!initial);

  // Display-only. At folder scale the rows needing a human are the point, and
  // they should not be buried under forty that guessed fine.
  const [unmappedFirst, setUnmappedFirst] = useState(false);

  // Advisory, never blocking: a shape Play would refuse is worth saying loudly,
  // but this builder does not get to decide what a valid product ID is. The
  // signing route's `isSafeSku` is the gate, and Play is the final word.
  const skuIssues = sku.trim() === '' ? [] : skuProblems(sku.trim(), 'icons');

  const existing = publishedVersion[packId];
  const version = existing ? existing + 1 : 1;

  const render = useCallback(async (entry: Entry): Promise<Entry> => {
    try {
      const out = await renderHeroIcon(entry.file);
      if (entry.url) URL.revokeObjectURL(entry.url);
      return { ...entry, url: out.url, blob: out.blob, aspect: out.aspect, error: null, busy: false };
    } catch (e) {
      return { ...entry, url: null, blob: null, error: (e as Error).message, busy: false };
    }
  }, []);

  async function addFiles(files: FileList | null) {
    if (!files?.length) return;
    // Expansion first: zips flatten, folders lose their noise, license-marked
    // SVGs are refused by name. Only what survives enters the pipeline.
    const intake = await expandPicked(Array.from(files));
    setRefused(intake.refused);
    if (intake.files.length === 0) return;
    const stamp = Date.now();
    const added: Entry[] = intake.files.map((file, i) => ({
      id: `${stamp}-${i}-${file.name}`,
      file,
      pkg: guessPackage(file.name) ?? '',
      url: null,
      blob: null,
      aspect: 1,
      error: null,
      busy: true,
    }));
    setEntries((e) => [...e, ...added]);
    // Sequential: each decode reads back a full image, and forty at once stalls
    // a mid-range phone long enough to look like a crash.
    for (const entry of added) {
      const done = await render(entry);
      setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
    }
  }

  function patchPkg(id: string, pkg: string) {
    setEntries((all) => all.map((e) => (e.id === id ? { ...e, pkg } : e)));
  }

  const duplicates = useMemo(() => {
    const seen = new Set<string>();
    const dupes = new Set<string>();
    for (const e of entries) {
      if (seen.has(e.pkg)) dupes.add(e.pkg);
      seen.add(e.pkg);
    }
    return dupes;
  }, [entries]);

  const ready = useMemo(
    () =>
      entries.length > 0 &&
      entries.every((e) => e.blob && isPackageName(e.pkg)) &&
      duplicates.size === 0 &&
      /^[a-z0-9._-]+$/.test(packId) &&
      licensed &&
      !busy,
    [entries, duplicates, packId, licensed, busy],
  );

  const covered = new Set(entries.map((e) => e.pkg));
  const missing = CORE_PACKAGES.filter((c) => !covered.has(c.pkg));

  // CSS that mirrors renderHero's two branches for the preview tile.
  const tileStyle: React.CSSProperties = masked
    ? { background: plate, borderRadius: `${radius}%` }
    : {
        // neutral checkerboard so transparent art is legible without implying a plate
        backgroundImage:
          'linear-gradient(45deg,#20252d 25%,transparent 25%),linear-gradient(-45deg,#20252d 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#20252d 75%),linear-gradient(-45deg,transparent 75%,#20252d 75%)',
        backgroundSize: '10px 10px',
        backgroundPosition: '0 0,0 5px,5px -5px,-5px 0',
        borderRadius: '18%',
      };

  async function publish() {
    setBusy(true);
    setError(null);
    setResult(null);

    const body = new FormData();
    body.set('app', app);
    body.set('packId', packId);
    body.set('packType', 'hero');
    body.set('version', String(version));
    body.set('minAppVersion', minAppVersion);
    body.set('title', name || packId);
    body.set('summary', `${entries.length} hero icons`);
    // WAS HARDCODED EMPTY, which meant every icon pack this builder has ever
    // published was free, permanently and silently. `icons_kali`,
    // `icons_garuda` and `icons_pop_cosmic` exist in Play Console and could not
    // be attached to anything, so the standalone icon-pack product had a price
    // in the store and no pack behind it.
    //
    // Blank still means free, which is correct and is the common case.
    body.set('sku', sku.trim());

    for (const e of entries) {
      if (!e.blob) continue;
      const fileName = fileNameFor(e.pkg);
      body.append('files', new File([e.blob], fileName, { type: 'image/png' }));
      body.append('paths', fileName);
    }

    const pack = buildHeroPackJson(
      packId,
      name || packId,
      masked,
      entries.map((e) => ({ pkg: e.pkg, file: fileNameFor(e.pkg) })),
    );
    body.append(
      'files',
      new File([JSON.stringify(pack, null, 2)], 'pack.json', { type: 'application/json' }),
    );
    body.append('paths', 'pack.json');

    try {
      const res = await fetch('/api/publish/pack', { method: 'POST', body });
      const json = await res.json();
      if (!res.ok) setError(json.error ?? 'Publish failed');
      else {
        setResult(`${json.packId} v${json.version} · ${json.fileCount} files · ${(json.sizeBytes / 1024).toFixed(0)} KB`);
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      {/* ── pack ─────────────────────────────────────────────────────────── */}
      <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Pack id</label>
            <input
              value={packId}
              onChange={(e) => setPackId(e.target.value)}
              placeholder="hero-ubuntu"
              autoCapitalize="none"
              spellCheck={false}
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
            />
          </div>
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ubuntu hero icons"
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2"
            />
          </div>
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Min app version</label>
            <input
              value={minAppVersion}
              onChange={(e) => setMinAppVersion(e.target.value)}
              inputMode="numeric"
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
            />
          </div>
        </div>

        {/* ── PRICE ────────────────────────────────────────────────────────
            Blank is free, and free is the common case: the bundled packs and
            every hero pack that ships with a free distro carry no SKU.

            WHEN PLAY CAN BE READ, this is a picker rather than an input: a
            Play product ID is PERMANENT, Play never releases one for reuse,
            and picking an existing product is the case that can never typo.
            The derived `icons_<slug>` id is offered even when Play does not
            have it yet, because naming the product here first and creating it
            in Play second is a legitimate order of operations; the status line
            says exactly what remains to be done in Play Console. Custom
            reveals the plain input.

            WHEN PLAY CANNOT BE READ, this is the input it always was, plus
            the reason nothing can be confirmed. The suggestion button only
            exists on this path; in the picker the derived id is an option. */}
        <div className="mt-3">
          <label className="block text-[11.5px] text-site-ink-3">
            Play product ID <span className="text-site-ink-3/60">· blank means free</span>
          </label>
          {play.ok ? (
            (() => {
              const derived = packId ? iconsSkuFor(packId) : '';
              const listed = play.products.filter((p) =>
                p.productId.startsWith(SKU_PREFIX.icons),
              );
              const rows: { value: string; label: string }[] = [
                { value: '', label: 'free (no product)' },
                ...(derived && !listed.some((p) => p.productId === derived)
                  ? [{ value: derived, label: `${derived} (create in Play)` }]
                  : []),
                ...listed.map((p) => ({
                  value: p.productId,
                  label:
                    p.activeOptions === 0 ? `${p.productId} (not active)` : p.productId,
                })),
                ...(sku &&
                sku !== derived &&
                !listed.some((p) => p.productId === sku)
                  ? [{ value: sku, label: `${sku} (not in Play)` }]
                  : []),
                { value: '__custom', label: 'custom ID' },
              ];
              return (
                <>
                  <select
                    value={customSku ? '__custom' : sku}
                    onChange={(e) => {
                      const v = e.target.value;
                      if (v === '__custom') {
                        setCustomSku(true);
                        return;
                      }
                      setCustomSku(false);
                      setSku(v);
                    }}
                    className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                  >
                    {rows.map((r) => (
                      <option key={r.value} value={r.value}>
                        {r.label}
                      </option>
                    ))}
                  </select>
                  {customSku && (
                    <input
                      value={sku}
                      onChange={(e) => setSku(e.target.value)}
                      placeholder="icons_kali"
                      autoCapitalize="none"
                      spellCheck={false}
                      className="mt-2 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                    />
                  )}
                </>
              );
            })()
          ) : (
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <input
                value={sku}
                onChange={(e) => setSku(e.target.value)}
                placeholder="icons_kali"
                autoCapitalize="none"
                spellCheck={false}
                className="min-w-0 flex-1 rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
              />
              {packId && !sku && (
                <button
                  onClick={() => setSku(iconsSkuFor(packId))}
                  className="shrink-0 rounded-lg border border-site-line bg-site-sunk px-2.5 py-2 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
                >
                  {iconsSkuFor(packId)}
                </button>
              )}
            </div>
          )}
          {skuIssues.map((p) => (
            <p key={p} className="mt-1 text-[11.5px] text-site-plan">
              {p}
            </p>
          ))}
          {sku.trim() !== '' && skuIssues.length === 0 && (
            <PlayNoteLine play={play} sku={sku.trim()} />
          )}
        </div>

        {/* masked is the one real switch the format has */}
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <button
            onClick={() => setMasked((m) => !m)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-[13px] transition ${
              masked ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep' : 'border-site-line text-site-ink-2'
            }`}
          >
            <span
              className={`grid size-4 place-items-center rounded ${masked ? 'bg-site-accent text-white' : 'border border-site-line'}`}
            >
              {masked ? '\u2713' : ''}
            </span>
            masked
          </button>
          <span className="text-[11.5px] leading-relaxed text-site-ink-3">
            {masked
              ? 'Art is square and full-bleed; the theme clips its shape and draws the plate behind.'
              : 'Art has its own silhouette and transparency, drawn as authored. This is the usual case.'}
          </span>
        </div>

        {masked && (
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-[11.5px] text-site-ink-3">Preview plate</label>
              <div className="mt-1 flex items-center gap-2">
                <span className="size-9 shrink-0 rounded-lg border border-site-line" style={{ background: plate }} />
                <input
                  value={plate}
                  onChange={(e) => setPlate(e.target.value)}
                  className="w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                />
              </div>
              <p className="mt-1 text-[11.5px] text-site-ink-3">Preview only. The real plate comes from the theme.</p>
            </div>
            <div>
              <label className="block text-[11.5px] text-site-ink-3">Preview corner radius {radius}%</label>
              <input
                type="range"
                min={0}
                max={50}
                value={radius}
                onChange={(e) => setRadius(Number(e.target.value))}
                className="mt-3 w-full"
              />
            </div>
          </div>
        )}

        <p className="mt-3 text-[11.5px] text-site-ink-3">
          {existing
            ? `v${existing} is published. This publishes v${version} and replaces every file in it.`
            : 'New pack, publishing as v1.'}
        </p>
      </section>

      {/* ── input ────────────────────────────────────────────────────────── */}
      <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
        <div className="flex flex-wrap items-center gap-2">
          <input
            type="file"
            multiple
            accept=".svg,.png,.webp,.jpg,.jpeg,.zip,image/svg+xml,image/png,image/webp,image/jpeg,application/zip"
            onChange={(e) => {
              void addFiles(e.target.files);
              e.target.value = '';
            }}
            className="block min-w-0 flex-1 text-[13px] text-site-ink-3 file:mr-3 file:rounded-lg file:border-0 file:bg-site-accent-soft file:px-3 file:py-2 file:text-[13px] file:text-site-accent-deep"
          />
          {/* A folder pick is its own input: `webkitdirectory` and `multiple`
              on one input mean "folder" wins everywhere it is supported and
              loose files become unpickable. Set via callback ref because the
              attribute is non-standard and not in React's input props. */}
          <input
            type="file"
            ref={(el) => el?.setAttribute('webkitdirectory', '')}
            onChange={(e) => {
              void addFiles(e.target.files);
              e.target.value = '';
            }}
            className="hidden"
            id="icon-folder-pick"
          />
          <label
            htmlFor="icon-folder-pick"
            className="shrink-0 cursor-pointer rounded-lg border border-site-line bg-site-sunk px-3 py-2 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
          >
            Add a folder
          </label>
        </div>
        <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
          SVG, PNG, WEBP, or JPEG, loose, in a folder, or in a zip. Each drawing
          is fitted to a 192 square at its own proportions and written as PNG.
          No trimming or rescaling: what you drew is what ships. Packages are
          guessed from filenames and reviewed below; nothing uploads until you
          publish.
        </p>
        <label className="mt-3 flex cursor-pointer items-start gap-2 text-[11.5px] leading-relaxed text-site-ink-2">
          <input
            type="checkbox"
            checked={licensed}
            onChange={(e) => setLicensed(e.target.checked)}
            className="mt-0.5"
          />
          <span>{LICENSE_ATTESTATION}</span>
        </label>
        {refused.length > 0 && (
          <div className="mt-3 space-y-1">
            {refused.map((r, i) => (
              <p key={i} className="text-[11.5px] leading-relaxed text-site-plan">
                {r.name} {r.reason}
              </p>
            ))}
          </div>
        )}
      </section>

      {/* ── entries ──────────────────────────────────────────────────────── */}
      {entries.length > 0 && (
        <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
          <header className="flex items-center gap-2 border-b border-site-line px-3 py-2.5 sm:px-4">
            <h2 className="text-[13px] font-medium">{entries.length} icons</h2>
            <span className="text-[11.5px] text-site-ink-3">
              {entries.filter((e) => isPackageName(e.pkg)).length} mapped
            </span>
            {entries.some((e) => !isPackageName(e.pkg)) && (
              <button
                onClick={() => setUnmappedFirst((v) => !v)}
                className={`ml-auto text-[11.5px] transition ${unmappedFirst ? 'text-site-ink' : 'text-site-ink-3 hover:text-site-ink'}`}
              >
                {unmappedFirst ? 'Original order' : 'Unmapped first'}
              </button>
            )}
          </header>

          {/* The common packages as picks, so correcting a guess is a choice
              rather than typing a reverse-DNS string on a laptop keyboard.
              Free text still works: the datalist only suggests. */}
          <datalist id="core-pkgs">
            {CORE_PACKAGES.map((c) => (
              <option key={c.pkg} value={c.pkg}>
                {c.label}
              </option>
            ))}
          </datalist>

          <div className="divide-y divide-site-line">
            {(unmappedFirst
              ? [...entries].sort(
                  (a, b) => Number(isPackageName(a.pkg)) - Number(isPackageName(b.pkg)),
                )
              : entries
            ).map((e) => (
              <div key={e.id} className="flex flex-wrap items-center gap-3 px-3 py-2.5 sm:px-4">
                <div className="grid size-12 shrink-0 place-items-center overflow-hidden border border-site-line" style={tileStyle}>
                  {/* Busy renders NOTHING. The tile is 48px with a border and a
                      background, so an empty one already reads as "not yet",
                      and the failure case below has its own mark to be
                      distinguished from. A character here was a third state
                      competing with two that already say enough. */}
                  {e.busy ? null : e.url ? (
                    <img src={e.url} alt="" className="size-12" />
                  ) : (
                    <span className="text-[11.5px] text-site-plan">!</span>
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <input
                    value={e.pkg}
                    onChange={(ev) => patchPkg(e.id, ev.target.value)}
                    placeholder="com.example.app"
                    autoCapitalize="none"
                    spellCheck={false}
                    list="core-pkgs"
                    className={`w-full rounded-lg border bg-site-sunk px-2.5 py-1.5 font-mono ${
                      !e.pkg
                        ? 'border-site-plan/50'
                        : !isPackageName(e.pkg) || duplicates.has(e.pkg)
                          ? 'border-site-plan'
                          : 'border-site-line'
                    }`}
                  />
                  <p className="mt-0.5 truncate text-[11.5px] text-site-ink-3">
                    {e.file.name}
                    {e.aspect < 0.8 || e.aspect > 1.25 ? ' · not square, padded' : ''}
                    {duplicates.has(e.pkg) ? ' · duplicate package' : ''}
                    {e.error ? ` · ${e.error}` : ''}
                  </p>
                </div>

                <button
                  onClick={() => {
                    if (e.url) URL.revokeObjectURL(e.url);
                    setEntries((all) => all.filter((x) => x.id !== e.id));
                  }}
                  className="text-[11.5px] text-site-ink-3 transition hover:text-site-plan"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── coverage ─────────────────────────────────────────────────────── */}
      {entries.length > 0 && missing.length > 0 && (
        <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
          <div className="mb-2 flex items-center gap-2">
            <h2 className="text-[13px] font-medium">Core set</h2>
            <span className="text-[11.5px] text-site-ink-3">
              {CORE_PACKAGES.length - missing.length} of {CORE_PACKAGES.length} covered
            </span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {missing.map((c) => (
              <span key={c.pkg} title={c.pkg} className="rounded-md border border-site-line px-2 py-1 font-mono text-[11.5px] text-site-ink-3">
                {c.label}
              </span>
            ))}
          </div>
          <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
            The dock and first drawer page are the only icons a user sees. Ranked
            by what the install base runs, not by what a desktop theme ships. A
            real ranking arrives with the analytics export.
          </p>
        </section>
      )}

      {error && (
        <p className="rounded-card border border-site-plan/40 bg-site-plan-soft px-3 py-2 text-[13px] leading-relaxed text-site-plan">
          {error}
        </p>
      )}
      {result && (
        <p className="rounded-card border border-site-ok/40 bg-site-ok-soft px-3 py-2 font-mono text-[11.5px] text-site-ok">
          {result}
        </p>
      )}

      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] md:static">
        <button
          onClick={publish}
          disabled={!ready}
          className="w-full rounded-lg bg-site-accent px-4 py-3 text-[13px] font-medium text-white shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Signing and uploading' : `Publish ${entries.length} icons as v${version}`}
        </button>
        {!licensed && entries.length > 0 && (
          <p className="mt-2 text-[11.5px] text-site-plan">
            Publishing needs the license attestation above.
          </p>
        )}
        {publishedIds.length > 0 && !packId && (
          <p className="mt-2 text-[11.5px] text-site-ink-3">Published hero packs: {publishedIds.join(', ')}</p>
        )}
      </div>
    </div>
  );
}

/**
 * The status line under the product ID: can this sku actually be bought?
 * Advisory only, same three states as the Commerce page. It replaces the old
 * static "check the Commerce page after publishing" sentence, which is now the
 * answer rather than the errand.
 */
function PlayNoteLine({ play, sku }: { play: PlayLite; sku: string }) {
  const note = playSkuNote(play, sku);
  const cls =
    note.tone === 'ok' ? 'text-site-ok' : note.tone === 'warn' ? 'text-site-plan' : 'text-site-ink-3';
  return <p className={`mt-1 text-[11.5px] leading-relaxed ${cls}`}>{note.text}</p>;
}
