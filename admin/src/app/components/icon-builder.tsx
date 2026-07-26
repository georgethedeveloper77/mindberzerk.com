'use client';

import { useCallback, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import {
  CORE_PACKAGES,
  buildHeroPackJson,
  fileNameFor,
  guessPackage,
  isPackageName,
} from '@/lib/icon-pack';
import { renderHeroIcon } from '@/lib/image-trim';
import { iconsSkuFor, skuProblems } from '@/lib/skus';

/**
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
 *    that is the `clipPath(maskPath) … fillBackground … drawLayer` branch.
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

export function IconBuilder({
  app,
  publishedIds,
  publishedVersion,
}: {
  app: string;
  publishedIds: string[];
  publishedVersion: Record<string, number>;
}) {
  const router = useRouter();

  const [packId, setPackId] = useState('');
  const [name, setName] = useState('');
  const [minAppVersion, setMinAppVersion] = useState('6');
  const [masked, setMasked] = useState(false);
  const [sku, setSku] = useState('');
  const [plate, setPlate] = useState('#E95420');
  const [radius, setRadius] = useState(22); // preview only, percent
  const [entries, setEntries] = useState<Entry[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);

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
    const added: Entry[] = Array.from(files).map((file, i) => ({
      id: `${Date.now()}-${i}-${file.name}`,
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
      !busy,
    [entries, duplicates, packId, busy],
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
      <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div>
            <label className="block text-micro text-ink-3">Pack id</label>
            <input
              value={packId}
              onChange={(e) => setPackId(e.target.value)}
              placeholder="hero-ubuntu"
              autoCapitalize="none"
              spellCheck={false}
              className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2 font-mono"
            />
          </div>
          <div>
            <label className="block text-micro text-ink-3">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ubuntu hero icons"
              className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2"
            />
          </div>
          <div>
            <label className="block text-micro text-ink-3">Min app version</label>
            <input
              value={minAppVersion}
              onChange={(e) => setMinAppVersion(e.target.value)}
              inputMode="numeric"
              className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2 font-mono"
            />
          </div>
        </div>

        {/* ── PRICE ────────────────────────────────────────────────────────
            Blank is free, and free is the common case: the bundled packs and
            every hero pack that ships with a free distro carry no SKU.

            The suggestion button exists because a Play product ID is PERMANENT.
            Play never releases one for reuse, so a typo here is a store listing
            you live with, and `icons_<slug>` is the convention the signed index,
            `isSafeSku` and the commerce page all already assume. */}
        <div className="mt-3">
          <label className="block text-micro text-ink-3">
            Play product ID <span className="text-ink-3/60">· blank means free</span>
          </label>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <input
              value={sku}
              onChange={(e) => setSku(e.target.value)}
              placeholder="icons_kali"
              autoCapitalize="none"
              spellCheck={false}
              className="min-w-0 flex-1 rounded-lg border border-line bg-surface-2 px-3 py-2 font-mono"
            />
            {packId && !sku && (
              <button
                onClick={() => setSku(iconsSkuFor(packId))}
                className="shrink-0 rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-data text-ink-2 transition hover:bg-surface-3"
              >
                {iconsSkuFor(packId)}
              </button>
            )}
          </div>
          {skuIssues.map((p) => (
            <p key={p} className="mt-1 text-micro text-warn">
              {p}
            </p>
          ))}
          {sku.trim() !== '' && skuIssues.length === 0 && (
            <p className="mt-1 text-micro text-ink-3">
              Nothing installs this pack until the product is active in Play. Check
              it on the Commerce page after publishing.
            </p>
          )}
        </div>

        {/* masked is the one real switch the format has */}
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <button
            onClick={() => setMasked((m) => !m)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-data transition ${
              masked ? 'border-accent/40 bg-accent-dim text-accent' : 'border-line text-ink-2'
            }`}
          >
            <span
              className={`grid size-4 place-items-center rounded ${masked ? 'bg-accent text-accent-ink' : 'border border-line'}`}
            >
              {masked ? '\u2713' : ''}
            </span>
            masked
          </button>
          <span className="text-micro leading-relaxed text-ink-3">
            {masked
              ? 'Art is square and full-bleed; the theme clips its shape and draws the plate behind.'
              : 'Art has its own silhouette and transparency, drawn as authored. This is the usual case.'}
          </span>
        </div>

        {masked && (
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-micro text-ink-3">Preview plate</label>
              <div className="mt-1 flex items-center gap-2">
                <span className="size-9 shrink-0 rounded-lg border border-line" style={{ background: plate }} />
                <input
                  value={plate}
                  onChange={(e) => setPlate(e.target.value)}
                  className="w-full rounded-lg border border-line bg-surface-2 px-3 py-2 font-mono"
                />
              </div>
              <p className="mt-1 text-micro text-ink-3">Preview only. The real plate comes from the theme.</p>
            </div>
            <div>
              <label className="block text-micro text-ink-3">Preview corner radius {radius}%</label>
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

        <p className="mt-3 text-micro text-ink-3">
          {existing
            ? `v${existing} is published. This publishes v${version} and replaces every file in it.`
            : 'New pack, publishing as v1.'}
        </p>
      </section>

      {/* ── input ────────────────────────────────────────────────────────── */}
      <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
        <input
          type="file"
          multiple
          accept=".svg,.png,.webp,image/svg+xml,image/png,image/webp"
          onChange={(e) => addFiles(e.target.files)}
          className="block w-full text-data text-ink-3 file:mr-3 file:rounded-lg file:border-0 file:bg-surface-3 file:px-3 file:py-2 file:text-data file:text-ink"
        />
        <p className="mt-2 text-micro leading-relaxed text-ink-3">
          SVG or PNG. Each drawing is fitted to a 192 square at its own
          proportions and written as PNG. No trimming or rescaling: what you drew
          is what ships. Nothing uploads until you publish.
        </p>
      </section>

      {/* ── entries ──────────────────────────────────────────────────────── */}
      {entries.length > 0 && (
        <section className="rounded-card border border-line-soft bg-surface-1">
          <header className="flex items-center gap-2 border-b border-line-soft px-3 py-2.5 sm:px-4">
            <h2 className="text-data font-medium">{entries.length} icons</h2>
            <span className="ml-auto text-micro text-ink-3">
              {entries.filter((e) => isPackageName(e.pkg)).length} mapped
            </span>
          </header>

          <div className="divide-y divide-line-soft">
            {entries.map((e) => (
              <div key={e.id} className="flex flex-wrap items-center gap-3 px-3 py-2.5 sm:px-4">
                <div className="grid size-12 shrink-0 place-items-center overflow-hidden border border-line" style={tileStyle}>
                  {e.busy ? (
                    <span className="text-micro text-ink-3">…</span>
                  ) : e.url ? (
                    <img src={e.url} alt="" className="size-12" />
                  ) : (
                    <span className="text-micro text-bad">!</span>
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <input
                    value={e.pkg}
                    onChange={(ev) => patchPkg(e.id, ev.target.value)}
                    placeholder="com.example.app"
                    autoCapitalize="none"
                    spellCheck={false}
                    className={`w-full rounded-lg border bg-surface-2 px-2.5 py-1.5 font-mono ${
                      !e.pkg
                        ? 'border-warn/50'
                        : !isPackageName(e.pkg) || duplicates.has(e.pkg)
                          ? 'border-bad/60'
                          : 'border-line'
                    }`}
                  />
                  <p className="mt-0.5 truncate text-micro text-ink-3">
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
                  className="text-micro text-ink-3 transition hover:text-bad"
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
        <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
          <div className="mb-2 flex items-center gap-2">
            <h2 className="text-data font-medium">Core set</h2>
            <span className="text-micro text-ink-3">
              {CORE_PACKAGES.length - missing.length} of {CORE_PACKAGES.length} covered
            </span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {missing.map((c) => (
              <span key={c.pkg} title={c.pkg} className="rounded-md border border-line px-2 py-1 font-mono text-micro text-ink-3">
                {c.label}
              </span>
            ))}
          </div>
          <p className="mt-2 text-micro leading-relaxed text-ink-3">
            The dock and first drawer page are the only icons a user sees. Ranked
            by what the install base runs, not by what a desktop theme ships. A
            real ranking arrives with the analytics export.
          </p>
        </section>
      )}

      {error && (
        <p className="rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
          {error}
        </p>
      )}
      {result && (
        <p className="rounded-card border border-ok/40 bg-ok-dim px-3 py-2 font-mono text-micro text-ok">
          {result}
        </p>
      )}

      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] md:static">
        <button
          onClick={publish}
          disabled={!ready}
          className="w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Signing and uploading…' : `Publish ${entries.length} icons as v${version}`}
        </button>
        {publishedIds.length > 0 && !packId && (
          <p className="mt-2 text-micro text-ink-3">Published hero packs: {publishedIds.join(', ')}</p>
        )}
      </div>
    </div>
  );
}
