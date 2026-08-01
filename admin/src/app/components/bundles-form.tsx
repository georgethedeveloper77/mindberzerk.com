'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface PackRef {
  packId: string;
  title: string;
  sku?: string | null;
}

export interface BundleDraft {
  sku: string;
  title: string;
  summary: string;
  grants: string[];
}

/**
 * PHASE C6 - the bundle editor, now a list plus an editor panel.
 *
 * ## The whole array is sent, every time
 *
 * There is no per-bundle save. The screen loads the live entitlements, edits
 * them locally, and posts the lot. A partial update would need concurrency
 * control to be safe; with one admin, last-write-wins over the whole array is
 * simpler and the failure mode (two tabs open) is visible rather than subtle.
 *
 * ## SELECTION IS CLIENT STATE HERE, AND ONLY HERE
 *
 * Every other list in the panel puts the selected row in the URL, which keeps
 * those pages server components and survives a refresh. This one cannot. The
 * whole screen is a single dirty array with one save at the end, so a link
 * navigation would remount the form and discard every unsaved edit without
 * saying so. Rows key off the array INDEX rather than the sku, because a new
 * bundle has no sku until someone types one.
 *
 * ## What the model actually is
 *
 * A device owns a pack if the pack is free, OR the buyer owns `pack.sku`, OR the
 * buyer owns a bundle whose grants include the pack id. So a pack's own SKU and
 * a bundle are two independent routes to the same pack, which is why granting a
 * free pack is legal and does nothing.
 *
 * ## `*` HAS NO BUTTON ANY MORE
 *
 * A wildcard grant promises every pack published from now until the app dies,
 * to everyone who ever bought the bundle, and it cannot be withdrawn. That is
 * settled policy: entitlements name their packs. `commerce.ts` already reports
 * a wildcard as a bad problem, so a one-tap control for it was an invitation to
 * create the exact defect the panel reports.
 *
 * An EXISTING `*` still renders, as a removable chip with the reason, because a
 * legacy grant that the UI cannot show is a legacy grant nobody can fix.
 */
export function BundlesForm({
  app,
  packs,
  initial,
}: {
  app: string;
  packs: PackRef[];
  initial: BundleDraft[];
}) {
  const router = useRouter();
  const [bundles, setBundles] = useState<BundleDraft[]>(initial);
  const [sel, setSel] = useState<number>(initial.length > 0 ? 0 : -1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);

  // Comparing against the loaded value rather than tracking a dirty flag: it
  // survives an edit that is undone by hand, which a flag does not.
  const dirty = JSON.stringify(bundles) !== JSON.stringify(initial);

  // `signIndex` refuses an entitlement with no grants, so a save carrying one
  // is a round trip to a certain 400. The button says which bundle instead.
  const emptyIndex = bundles.findIndex((b) => b.grants.length === 0);
  const namelessIndex = bundles.findIndex((b) => !b.sku.trim());
  const blocked =
    emptyIndex >= 0
      ? `${bundles[emptyIndex].sku || 'A bundle'} grants nothing`
      : namelessIndex >= 0
        ? 'A bundle has no product ID'
        : null;

  function patch(i: number, next: Partial<BundleDraft>) {
    setBundles((b) => b.map((e, n) => (n === i ? { ...e, ...next } : e)));
  }

  function toggleGrant(i: number, packId: string) {
    setBundles((b) =>
      b.map((e, n) => {
        if (n !== i) return e;
        const has = e.grants.includes(packId);
        return {
          ...e,
          grants: has ? e.grants.filter((g) => g !== packId) : [...e.grants, packId],
        };
      }),
    );
  }

  function add() {
    setBundles((b) => [...b, { sku: '', title: '', summary: '', grants: [] }]);
    setSel(bundles.length);
  }

  function remove(i: number) {
    setBundles((b) => b.filter((_, n) => n !== i));
    // Clamp rather than clear: deleting the last row should leave the panel on
    // the new last row, not on nothing.
    setSel((s) => (s > i ? s - 1 : Math.min(s, bundles.length - 2)));
  }

  async function save() {
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const res = await fetch('/api/publish/bundles', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app, entitlements: bundles }),
      });
      const json = await res.json();
      if (!res.ok) setError(json.error ?? 'Save failed');
      else {
        setResult(
          `${json.bundles} bundle${json.bundles === 1 ? '' : 's'} signed · ` +
            `index ${json.previousGeneratedAt} to ${json.generatedAt}`,
        );
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const current = sel >= 0 && sel < bundles.length ? bundles[sel] : null;

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <button
          onClick={save}
          disabled={!dirty || busy || !!blocked}
          className="rounded-lg bg-accent px-4 py-2 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-40"
        >
          {busy ? 'Signing index' : dirty ? 'Save and sign' : 'No changes'}
        </button>
        {blocked && dirty && <span className="text-micro text-warn">{blocked}</span>}
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          <div className="overflow-hidden rounded-card border border-line-soft bg-surface-1">
            {bundles.map((b, i) => {
              const problem = b.grants.length === 0 || !b.sku.trim();
              return (
                <button
                  key={i}
                  onClick={() => setSel(i)}
                  className={`flex w-full items-center gap-2.5 border-b border-line-soft px-2.5 py-2 text-left transition last:border-b-0 sm:px-3 ${
                    problem ? 'border-l-2 border-l-warn' : ''
                  } ${sel === i ? 'bg-surface-2' : 'hover:bg-surface-2/60'}`}
                >
                  <span className="min-w-0 flex-1">
                    <span
                      className={`block truncate font-mono text-data ${
                        sel === i ? 'text-ink' : 'text-ink-2'
                      }`}
                    >
                      {b.sku || 'new bundle'}
                    </span>
                    <span className="block truncate text-micro text-ink-3">
                      {b.grants.length === 0
                        ? 'grants nothing'
                        : b.title || `${b.grants.length} granted`}
                    </span>
                  </span>
                  <span className="shrink-0 font-mono text-micro text-ink-3 tnum">
                    {b.grants.length} {b.grants.length === 1 ? 'grant' : 'grants'}
                  </span>
                </button>
              );
            })}

            <button
              onClick={add}
              className="w-full border-t border-dashed border-line px-3 py-2.5 text-data text-ink-3 transition hover:text-ink-2"
            >
              Add a bundle
            </button>
          </div>

          {error && (
            <p className="mt-3 rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
              {error}
            </p>
          )}
          {result && (
            <p className="mt-3 rounded-card border border-ok/40 bg-ok-dim px-3 py-2 font-mono text-micro text-ok">
              {result}
            </p>
          )}
        </div>

        {current && (
          <aside className="w-full shrink-0 rounded-card border border-line-soft bg-surface-1 p-3 lg:sticky lg:top-6 lg:w-72">
            <div className="font-mono text-micro text-ink-3">editing</div>

            <div className="mt-2 space-y-2">
              <Field
                label="product ID"
                value={current.sku}
                onChange={(v) => patch(sel, { sku: v })}
                mono
                hint="Must match the Play product id exactly"
              />
              <Field
                label="title"
                value={current.title}
                onChange={(v) => patch(sel, { title: v })}
              />
              <Field
                label="summary"
                value={current.summary}
                onChange={(v) => patch(sel, { summary: v })}
              />
            </div>

            <div className="mt-3 border-t border-line-soft pt-2.5">
              <div className="mb-1.5 font-mono text-micro text-ink-3">
                grants · {current.grants.filter((g) => g !== '*').length} of {packs.length} packs
              </div>
              <div className="flex flex-wrap gap-1.5">
                {packs.map((p) => {
                  const on = current.grants.includes(p.packId);
                  return (
                    <button
                      key={p.packId}
                      onClick={() => toggleGrant(sel, p.packId)}
                      title={p.sku ? p.title : `${p.title} is free, so this grant does nothing`}
                      className={`rounded-md border px-2 py-1 font-mono text-micro transition ${
                        on
                          ? 'border-accent/40 bg-accent-dim text-accent'
                          : 'border-line text-ink-3 hover:text-ink-2'
                      } ${!p.sku && on ? 'line-through' : ''}`}
                    >
                      {p.packId}
                    </button>
                  );
                })}

                {/* Grants naming a pack that is not published are legal on
                    purpose: a bundle can be announced before its contents ship.
                    Shown so they are not mistaken for typos. */}
                {current.grants
                  .filter((g) => g !== '*' && !packs.some((p) => p.packId === g))
                  .map((g) => (
                    <button
                      key={g}
                      onClick={() => toggleGrant(sel, g)}
                      title="Not published yet. Legal, and it will start granting when it ships."
                      className="rounded-md border border-info/40 bg-info-dim px-2 py-1 font-mono text-micro text-info"
                    >
                      {g} ?
                    </button>
                  ))}

                {/* No button creates this. It is here so a legacy wildcard can
                    be seen and removed, which a UI that simply omitted it could
                    not do. */}
                {current.grants.includes('*') && (
                  <button
                    onClick={() => toggleGrant(sel, '*')}
                    title="Remove the wildcard and name the packs instead"
                    className="rounded-md border border-bad/40 bg-bad-dim px-2 py-1 font-mono text-micro text-bad"
                  >
                    everything
                  </button>
                )}
              </div>

              {current.grants.includes('*') && (
                <p className="mt-2 text-micro leading-relaxed text-bad">
                  This grants every pack published from now on, forever, to
                  everyone who has already bought it. Remove it and name the
                  packs.
                </p>
              )}
              {current.grants.length === 0 && (
                <p className="mt-2 text-micro leading-relaxed text-warn">
                  A bundle that grants nothing cannot be signed, so it blocks the
                  save until it grants a pack or is deleted.
                </p>
              )}
              <p className="mt-2 text-micro leading-relaxed text-ink-3">
                Blue means named but not published yet, which is legal and starts
                granting when it ships.
              </p>
            </div>

            <div className="mt-3 border-t border-line-soft pt-2.5">
              <button
                onClick={() => remove(sel)}
                className="text-micro text-ink-3 transition hover:text-bad"
              >
                Delete bundle
              </button>
            </div>
          </aside>
        )}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  mono,
  hint,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  mono?: boolean;
  hint?: string;
}) {
  return (
    <div>
      <label className="block text-micro text-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        className={`mt-1 w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 ${
          mono ? 'font-mono' : ''
        }`}
      />
      {hint && <p className="mt-1 text-micro leading-relaxed text-ink-3">{hint}</p>}
    </div>
  );
}
