'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';

interface PublishedPack {
  packId: string;
  packType: string;
  version: number;
  title: string;
  summary: string;
  sku?: string | null;
}

/**
 * PHASE C4 - publishing, from a phone or a laptop.
 *
 * ## Two inputs, because mobile browsers cannot do directories
 *
 * `webkitdirectory` is unsupported on iOS Safari and Android Chrome. It does not
 * error; the picker just offers individual files and the tree is silently lost,
 * which for a pack is fatal - the relative paths ARE part of the signed manifest
 * and the device resolves `wallpapers/bg.webp` by exactly that string.
 *
 * So the mode is chosen by capability, not by preference, and defaults to zip on
 * anything that cannot do better. The zip path works everywhere and is the only
 * one that exists on a phone.
 *
 * ## Everything is pre-filled from what is already published
 *
 * Picking a pack that exists fills in the type, title, summary, sku, and the
 * NEXT version. That last one is the important one: republishing at the same
 * version produces content every device refuses silently, and the guard is here
 * as well as server-side because catching it before the upload saves a minute
 * and catching it after saves an afternoon.
 *
 * [catalogueUnknown] is that guard's honesty clause. With the bucket
 * unreadable the published list is EMPTY rather than absent, so every pack
 * looks new and the version guard cannot fire at all. Rather than let a form
 * silently lose its only safety check, the panel says so and the submit is
 * disabled: the server would refuse the write anyway, and finding that out
 * after filling in twelve fields and uploading several MB is the worst place to
 * find it out.
 *
 * ## THE PATTERN: editor left, consequence right
 *
 * The right-hand panel is what this publish will produce, assembled from what
 * is filled in so far: the pack id, the version and what it replaces, the file
 * count and the byte total. Same slot the list screens use for their inspector,
 * so the panel has one place where "what am I looking at" lives.
 */
export function PublishForm({
  app,
  packs,
  catalogueUnknown = false,
}: {
  app: string;
  packs: PublishedPack[];
  /** The catalogue could not be read, so the version guard cannot be trusted. */
  catalogueUnknown?: boolean;
}) {
  const router = useRouter();
  const dirRef = useRef<HTMLInputElement>(null);
  const zipRef = useRef<HTMLInputElement>(null);

  const [supportsDir, setSupportsDir] = useState(false);
  const [mode, setMode] = useState<'zip' | 'dir'>('zip');

  const [packId, setPackId] = useState('');
  const [packType, setPackType] = useState('theme');
  const [version, setVersion] = useState('1');
  const [minAppVersion, setMinAppVersion] = useState('6');
  const [title, setTitle] = useState('');
  const [summary, setSummary] = useState('');
  const [sku, setSku] = useState('');

  const [dirFiles, setDirFiles] = useState<File[]>([]);
  const [zipFile, setZipFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Feature-detect rather than sniff the user agent. `webkitdirectory` is a
    // real property on the input element where it is supported, and a UA string
    // check would be wrong the first time a browser changes.
    const el = document.createElement('input');
    const ok = 'webkitdirectory' in el;
    setSupportsDir(ok);
    if (ok) setMode('dir');
  }, []);

  const published = useMemo(
    () => packs.find((p) => p.packId === packId),
    [packs, packId],
  );
  const versionTooLow =
    published !== undefined && Number(version) <= published.version;

  function prefillFrom(folderName: string) {
    if (!packId) setPackId(folderName);
    const existing = packs.find((p) => p.packId === folderName);
    if (!existing) return;
    setVersion(String(existing.version + 1));
    setPackType(existing.packType);
    setTitle(existing.title);
    setSummary(existing.summary);
    setSku(existing.sku ?? '');
  }

  function onPickDir(e: React.ChangeEvent<HTMLInputElement>) {
    const picked = Array.from(e.target.files ?? []);
    setDirFiles(picked);
    const relative = (picked[0] as File & { webkitRelativePath?: string })
      ?.webkitRelativePath;
    if (relative) prefillFrom(relative.split('/')[0]);
  }

  function onPickZip(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0] ?? null;
    setZipFile(file);
    if (file) prefillFrom(file.name.replace(/\.zip$/i, ''));
  }

  const fileCount = mode === 'zip' ? (zipFile ? 1 : 0) : dirFiles.length;
  const totalBytes =
    mode === 'zip'
      ? (zipFile?.size ?? 0)
      : dirFiles.reduce((n, f) => n + f.size, 0);

  async function onSubmit() {
    setBusy(true);
    setError(null);
    setResult(null);

    const body = new FormData();
    body.set('app', app);
    body.set('packId', packId);
    body.set('packType', packType);
    body.set('version', version);
    body.set('minAppVersion', minAppVersion);
    body.set('title', title || packId);
    body.set('summary', summary);
    body.set('sku', sku);

    if (mode === 'zip' && zipFile) {
      body.set('archive', zipFile);
    } else {
      for (const file of dirFiles) {
        const relative =
          (file as File & { webkitRelativePath?: string }).webkitRelativePath ??
          file.name;
        // Drop the leading folder segment: the directory name is the packId and
        // lives in the URL, not in the signed path.
        const path = relative.includes('/')
          ? relative.slice(relative.indexOf('/') + 1)
          : relative;
        body.append('files', file);
        body.append('paths', path);
      }
    }

    try {
      const res = await fetch('/api/publish/pack', { method: 'POST', body });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error ?? 'Publish failed');
      } else {
        setResult(
          `${json.packId} v${json.version} · ${json.fileCount} files · ` +
            `${(json.sizeBytes / 1024).toFixed(1)} KB\nindex ${json.previousGeneratedAt} to ${json.generatedAt}`,
        );
        setDirFiles([]);
        setZipFile(null);
        if (dirRef.current) dirRef.current.value = '';
        if (zipRef.current) zipRef.current.value = '';
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const blocked = catalogueUnknown
    ? 'The catalogue is unreadable, so the version cannot be checked'
    : fileCount === 0
      ? 'Nothing picked'
      : !packId
        ? 'No pack id'
        : versionTooLow
          ? `v${published?.version} is already published`
          : null;
  const ready = !blocked && !busy;

  const fileInput =
    'block w-full text-data text-ink-3 file:mr-3 file:rounded-lg file:border-0 ' +
    'file:bg-surface-3 file:px-3 file:py-2 file:text-data file:text-ink';

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <button
          onClick={onSubmit}
          disabled={!ready}
          className="rounded-lg bg-accent px-4 py-2 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-40"
        >
          {busy ? 'Signing and uploading' : 'Sign and publish'}
        </button>
        {blocked && <span className="text-micro text-ink-3">{blocked}</span>}
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1 space-y-3">
          {/* ── source ─────────────────────────────────────────────────── */}
          <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
            {supportsDir && (
              <div className="mb-3 flex rounded-lg bg-surface-2 p-0.5 text-data">
                {(['dir', 'zip'] as const).map((m) => (
                  <button
                    key={m}
                    onClick={() => setMode(m)}
                    className={`flex-1 rounded-md px-3 py-1.5 transition ${
                      mode === m ? 'bg-surface-3 text-ink' : 'text-ink-3'
                    }`}
                  >
                    {m === 'dir' ? 'Folder' : 'Zip'}
                  </button>
                ))}
              </div>
            )}

            {mode === 'dir' ? (
              <input
                ref={dirRef}
                type="file"
                onChange={onPickDir}
                // @ts-expect-error non-standard, desktop only, feature-detected above
                webkitdirectory=""
                directory=""
                multiple
                className={fileInput}
              />
            ) : (
              <>
                <input
                  ref={zipRef}
                  type="file"
                  accept=".zip,application/zip"
                  onChange={onPickZip}
                  className={fileInput}
                />
                {!supportsDir && (
                  <p className="mt-2 text-micro leading-relaxed text-ink-3">
                    This browser cannot pick folders, so zip the pack directory
                    first. A wrapping folder inside the zip is stripped on the
                    server.
                  </p>
                )}
              </>
            )}
          </section>

          {/* ── metadata ───────────────────────────────────────────────── */}
          <section className="space-y-3 rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <Field label="Pack id" value={packId} onChange={setPackId} mono />
              <div>
                <label className="block text-micro text-ink-3">Type</label>
                <select
                  value={packType}
                  onChange={(e) => setPackType(e.target.value)}
                  className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2"
                >
                  <option value="theme">theme</option>
                  <option value="brand">brand</option>
                  <option value="hero">hero</option>
                  <option value="icon">icon</option>
                </select>
              </div>
              {/* inputMode numeric so a phone shows the number pad rather than QWERTY */}
              <Field label="Version" value={version} onChange={setVersion} mono numeric />
              <Field
                label="Min app version"
                value={minAppVersion}
                onChange={setMinAppVersion}
                mono
                numeric
              />
              <Field label="Title" value={title} onChange={setTitle} />
              <Field label="Product ID (blank = free)" value={sku} onChange={setSku} mono />
            </div>
            <Field label="Summary" value={summary} onChange={setSummary} />
          </section>

          {result && (
            <p className="whitespace-pre-line rounded-card border border-ok/40 bg-ok-dim px-3 py-2 font-mono text-micro leading-relaxed text-ok">
              {result}
            </p>
          )}
          {error && (
            <p className="rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
              {error}
            </p>
          )}
        </div>

        {/* ── what this will publish ───────────────────────────────────── */}
        <aside className="w-full shrink-0 rounded-card border border-line-soft bg-surface-1 p-3 lg:sticky lg:top-6 lg:w-64">
          <div className="font-mono text-micro text-ink-3">what this publishes</div>

          <div className="mt-2 border-t border-line-soft pt-1">
            <Row k="pack id" v={packId || '-'} />
            <Row k="type" v={packType} />
            <Row k="version" v={version || '-'} />
            <Row k="min app" v={minAppVersion || '-'} />
            <Row k="product" v={sku.trim() || 'free'} />
            <Row
              k="files"
              v={
                fileCount === 0
                  ? '-'
                  : mode === 'zip'
                    ? '1 zip'
                    : `${fileCount} ${fileCount === 1 ? 'file' : 'files'}`
              }
            />
            <Row k="size" v={totalBytes ? `${(totalBytes / 1024).toFixed(1)} KB` : '-'} />
          </div>

          {mode === 'zip' && zipFile && (
            <p className="mt-2 break-all font-mono text-micro leading-relaxed text-ink-3">
              {zipFile.name}
            </p>
          )}

          {published && !versionTooLow && (
            <p className="mt-2 text-micro leading-relaxed text-ink-2">
              Replaces v{published.version} in the catalogue. The old version
              stays in the bucket and shows up as an orphan on CDN objects.
            </p>
          )}

          {versionTooLow && published && (
            <p className="mt-2 text-micro leading-relaxed text-warn">
              v{published.version} is already published. A device refuses a pack
              whose version does not increase, and it does so silently. Use{' '}
              {published.version + 1} or higher.
            </p>
          )}

          {catalogueUnknown && (
            <p className="mt-2 text-micro leading-relaxed text-bad">
              The catalogue could not be read, so this panel does not know
              whether this pack exists or what version it is at. Publishing is
              disabled until the bucket answers.
            </p>
          )}

          {!published && !catalogueUnknown && packId && (
            <p className="mt-2 text-micro leading-relaxed text-ink-3">
              Nothing is published under this id yet, so this creates it.
            </p>
          )}
        </aside>
      </div>
    </div>
  );
}

function Row({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-line-soft py-1.5 text-data last:border-b-0">
      <span className="text-ink-3">{k}</span>
      <span className="truncate text-right font-mono text-micro text-ink-2 tnum">{v}</span>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  mono,
  numeric,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  mono?: boolean;
  numeric?: boolean;
}) {
  return (
    <div>
      <label className="block text-micro text-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        inputMode={numeric ? 'numeric' : undefined}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        className={`mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2 ${
          mono ? 'font-mono' : ''
        }`}
      />
    </div>
  );
}
