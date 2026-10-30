'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { strFromU8, unzipSync } from 'fflate';

import {
  applyImportAction,
  previewImportAction,
} from '@/app/apps/[app]/distros/actions';
import type { ImportFile, ImportRow } from '@/lib/g-launcher/distro-io';

/**
 * IMPORT DISTROS: many theme.json files at once, reviewed before they save.
 *
 * Accepts single `.json` files, a `.zip` of them (what Export produces, or the
 * repo's `themes/g-launcher` folder zipped), or a pasted JSON array. Zips are
 * opened HERE, in the browser, so the server only ever sees text.
 *
 * Every row says what it would change and whether it would load, and nothing
 * is written until Save. Save writes DRAFTS: publishing stays its own step.
 */
export function ImportDistros({ app }: { app: string }) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [files, setFiles] = React.useState<ImportFile[]>([]);
  const [rows, setRows] = React.useState<ImportRow[] | null>(null);
  const [chosen, setChosen] = React.useState<Set<string>>(new Set());
  const [busy, setBusy] = React.useState(false);
  const [message, setMessage] = React.useState<string | null>(null);
  const [paste, setPaste] = React.useState('');
  const [drag, setDrag] = React.useState(false);

  const reset = () => {
    setFiles([]);
    setRows(null);
    setChosen(new Set());
    setMessage(null);
    setPaste('');
  };

  const review = async (next: ImportFile[]) => {
    if (!next.length) return;
    setBusy(true);
    setMessage(null);
    const out = await previewImportAction(app, next);
    setBusy(false);
    if (!out.ok) {
      setMessage(out.detail);
      return;
    }
    setFiles(next);
    setRows(out.rows);
    // New and changed rows that will load are ticked; unchanged and broken
    // ones are not, so Save does exactly what the table says by default.
    setChosen(
      new Set(
        out.rows
          .filter((r) => r.id && (r.kind === 'new' || r.kind === 'update'))
          .map((r) => r.id!),
      ),
    );
  };

  const read = async (list: FileList | File[]) => {
    const out: ImportFile[] = [];
    for (const f of Array.from(list)) {
      if (f.name.toLowerCase().endsWith('.zip')) {
        try {
          const entries = unzipSync(new Uint8Array(await f.arrayBuffer()));
          for (const [name, bytes] of Object.entries(entries)) {
            // Folders and macOS resource forks are not theme files.
            if (!name.toLowerCase().endsWith('.json') || name.includes('__MACOSX/')) continue;
            out.push({ name: name.split('/').pop() ?? name, text: strFromU8(bytes) });
          }
        } catch {
          setMessage(`${f.name} is not a zip that can be opened.`);
          return;
        }
      } else {
        out.push({ name: f.name, text: await f.text() });
      }
    }
    await review(out);
  };

  const save = async () => {
    setBusy(true);
    const out = await applyImportAction(app, files, [...chosen]);
    setBusy(false);
    if (!out.ok) {
      setMessage(out.detail);
      return;
    }
    const failed = out.results.filter((r) => !r.ok);
    const written = out.results.filter((r) => r.ok && r.detail !== 'unchanged').length;
    setMessage(
      failed.length
        ? `${written} saved. ${failed.map((f) => `${f.id}: ${f.detail}`).join(' · ')}`
        : `${written} ${written === 1 ? 'draft' : 'drafts'} saved. Nothing was published.`,
    );
    router.refresh();
    if (!failed.length) setRows(null);
  };

  const toggle = (id: string) =>
    setChosen((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  return (
    <>
      <button
        type="button"
        onClick={() => {
          reset();
          setOpen(true);
        }}
        className="inline-flex items-center gap-1.5 rounded-[10px] border border-site-line bg-site-card px-3.5 py-2 text-[13px] font-semibold text-site-ink transition hover:bg-site-sunk"
      >
        Import
      </button>

      {open && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Import distros"
          className="fixed inset-0 z-50 grid place-items-center bg-black/50 p-4"
          onClick={(e) => {
            if (e.target === e.currentTarget && !busy) setOpen(false);
          }}
        >
          <div className="max-h-[90vh] w-full max-w-[920px] overflow-y-auto rounded-[18px] border border-site-line bg-site-card p-5 shadow-site-soft">
            <div className="flex items-center gap-3">
              <h2 className="font-site-display text-[16px] font-bold text-site-ink">Import distros</h2>
              <span className="flex-1" />
              <button
                type="button"
                onClick={() => setOpen(false)}
                disabled={busy}
                className="rounded-lg px-2 py-1 text-[13px] text-site-ink-3 hover:text-site-ink"
              >
                Close
              </button>
            </div>

            {!rows && (
              <div className="mt-4 grid gap-3">
                <label
                  onDragOver={(e) => {
                    e.preventDefault();
                    setDrag(true);
                  }}
                  onDragLeave={() => setDrag(false)}
                  onDrop={(e) => {
                    e.preventDefault();
                    setDrag(false);
                    void read(e.dataTransfer.files);
                  }}
                  className={`grid cursor-pointer place-items-center rounded-[14px] border-[1.5px] border-dashed px-4 py-8 text-center text-[13px] transition ${
                    drag ? 'border-site-accent bg-site-accent-soft text-site-ink' : 'border-site-line text-site-ink-2'
                  }`}
                >
                  <span>
                    Drop <b>.theme.json</b> files or a <b>.zip</b> of them, or <u>choose files</u>
                  </span>
                  <input
                    type="file"
                    multiple
                    accept=".json,.zip,application/json,application/zip"
                    className="sr-only"
                    onChange={(e) => e.target.files && void read(e.target.files)}
                  />
                </label>
                <textarea
                  value={paste}
                  onChange={(e) => setPaste(e.target.value)}
                  placeholder="or paste one theme.json, or a JSON array of them"
                  rows={4}
                  className="w-full rounded-[12px] border border-site-line bg-site-sunk p-3 font-mono text-[12px] text-site-ink"
                />
                <div className="flex justify-end">
                  <button
                    type="button"
                    disabled={!paste.trim() || busy}
                    onClick={() => void review([{ name: 'pasted', text: paste }])}
                    className="rounded-[10px] border border-site-line px-3.5 py-2 text-[13px] font-semibold text-site-ink disabled:opacity-40"
                  >
                    Review pasted
                  </button>
                </div>
              </div>
            )}

            {rows && (
              <div className="mt-4 overflow-x-auto rounded-[14px] border border-site-line">
                <table className="w-full min-w-[760px] text-left text-[12.5px]">
                  <thead className="bg-site-sunk font-mono text-[10.5px] uppercase tracking-[0.06em] text-site-ink-3">
                    <tr>
                      <th className="w-8 px-3 py-2" />
                      <th className="px-3 py-2">File</th>
                      <th className="px-3 py-2">Distro</th>
                      <th className="px-3 py-2">What changes</th>
                      <th className="px-3 py-2">Checks</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r, i) => {
                      const can = !!r.id && (r.kind === 'new' || r.kind === 'update');
                      return (
                        <tr key={`${r.file}-${i}`} className="border-t border-site-line align-top">
                          <td className="px-3 py-2.5">
                            <input
                              type="checkbox"
                              aria-label={`Import ${r.file}`}
                              disabled={!can}
                              checked={!!r.id && chosen.has(r.id)}
                              onChange={() => r.id && toggle(r.id)}
                            />
                          </td>
                          <td className="px-3 py-2.5 font-mono text-[11.5px] text-site-ink-2">{r.file}</td>
                          <td className="px-3 py-2.5">
                            <div className="font-semibold text-site-ink">{r.title ?? '?'}</div>
                            <div className="font-mono text-[11px] text-site-ink-3">
                              {r.id ?? 'no id'} · {r.kind}
                            </div>
                          </td>
                          <td className="px-3 py-2.5 font-mono text-[11.5px] text-site-ink-2">
                            {r.kind === 'same'
                              ? 'no changes'
                              : r.changes.length
                                ? r.changes.join(' · ')
                                : '-'}
                            {r.minTo != null && r.minTo !== r.minFrom && (
                              <div className="text-site-plan">
                                needs build {r.minFrom ?? '-'} → {r.minTo}
                              </div>
                            )}
                          </td>
                          <td className="px-3 py-2.5 text-[11.5px]">
                            {r.errors.length ? (
                              <ul className="text-site-bad">
                                {r.errors.map((e) => (
                                  <li key={e}>{e}</li>
                                ))}
                              </ul>
                            ) : (
                              <span className="text-site-ok">valid</span>
                            )}
                            {r.warnings.length > 0 && (
                              <ul className="mt-1 text-site-plan">
                                {r.warnings.map((w) => (
                                  <li key={w}>{w}</li>
                                ))}
                              </ul>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}

            {message && <p className="mt-3 text-[12.5px] text-site-ink-2">{message}</p>}

            {rows && (
              <div className="mt-4 flex items-center gap-2 border-t border-site-line pt-4">
                <span className="font-mono text-[11.5px] text-site-ink-3">
                  {chosen.size} selected · saves drafts, publishes nothing
                </span>
                <span className="flex-1" />
                <button
                  type="button"
                  onClick={reset}
                  disabled={busy}
                  className="rounded-[10px] border border-site-line px-3.5 py-2 text-[13px] font-semibold text-site-ink"
                >
                  Start over
                </button>
                <button
                  type="button"
                  onClick={() => void save()}
                  disabled={busy || chosen.size === 0}
                  className="rounded-[10px] bg-site-accent px-3.5 py-2 text-[13px] font-semibold text-white disabled:opacity-40"
                >
                  {busy ? 'Saving' : `Save ${chosen.size} ${chosen.size === 1 ? 'draft' : 'drafts'}`}
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
