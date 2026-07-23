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
 * PHASE C4 — publishing, from a phone or a laptop. PHASE C5 — on the tokens.
 *
 * ## Two inputs, because mobile browsers cannot do directories
 *
 * `webkitdirectory` is unsupported on iOS Safari and Android Chrome. It does not
 * error; the picker just offers individual files and the tree is silently lost,
 * which for a pack is fatal — the relative paths ARE part of the signed manifest
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
 * ## C5 changed nothing but the classes
 *
 * Colours now come from the token layer, and the per-input `text-base sm:text-sm`
 * dance is gone because globals.css sets it for every input in the panel — iOS
 * Safari zooms the page when a font under 16px takes focus and never zooms back,
 * so that rule belongs in one place rather than on every field.
 */
export function PublishForm({
  app,
  packs,
}: {
  app: string;
  packs: PublishedPack[];
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
            `${(json.sizeBytes / 1024).toFixed(1)} KB\nindex ${json.previousGeneratedAt} → ${json.generatedAt}`,
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

  const ready = fileCount > 0 && packId && version && !versionTooLow && !busy;

  const fileInput =
    'block w-full text-data text-ink-3 file:mr-3 file:rounded-lg file:border-0 ' +
    'file:bg-surface-3 file:px-3 file:py-2 file:text-data file:text-ink';

  return (
    <div className="space-y-3">
      {/* Source */}
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
                first. A wrapping folder inside the zip is stripped on the server.
              </p>
            )}
          </>
        )}

        {fileCount > 0 && (
          <p className="mt-2.5 font-mono text-micro text-ink-3 tnum">
            {mode === 'zip'
              ? zipFile?.name
              : `${fileCount} file${fileCount === 1 ? '' : 's'}`}{' '}
            · {(totalBytes / 1024).toFixed(1)} KB
          </p>
        )}
      </section>

      {/* Metadata */}
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
          <Field label="SKU (blank = free)" value={sku} onChange={setSku} mono />
        </div>
        <Field label="Summary" value={summary} onChange={setSummary} />
      </section>

      {versionTooLow && published && (
        <p className="rounded-card border border-warn/40 bg-warn-dim px-3 py-2 text-data leading-relaxed text-warn">
          v{published.version} is already published. A device refuses a pack whose
          version does not increase, and it does so silently. Use{' '}
          {published.version + 1} or higher.
        </p>
      )}

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

      {/* Sticky on mobile: the form is taller than a phone screen, and a submit
          button you have to scroll to find is one people stop trusting. */}
      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] md:static">
        <button
          onClick={onSubmit}
          disabled={!ready}
          className="w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Signing and uploading…' : 'Sign and publish'}
        </button>
      </div>
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
