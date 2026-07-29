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
 * PHASE C6 - the bundle editor.
 *
 * ## The whole array is sent, every time
 *
 * There is no per-bundle save. The screen loads the live entitlements, edits
 * them locally, and posts the lot. A partial update would need concurrency
 * control to be safe; with one admin, last-write-wins over the whole array is
 * simpler and the failure mode (two tabs open) is visible rather than subtle.
 *
 * ## What the model actually is
 *
 * A device owns a pack if the pack is free, OR the buyer owns `pack.sku`, OR the
 * buyer owns a bundle whose grants include the pack id or `*`. So a pack's own
 * SKU and a bundle are two independent routes to the same pack, which is why
 * granting a free pack is legal and does nothing, and why `*` is worth its own
 * control: it covers packs that do not exist yet, which no checkbox can.
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
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);

  // Comparing against the loaded value rather than tracking a dirty flag: it
  // survives an edit that is undone by hand, which a flag does not.
  const dirty = JSON.stringify(bundles) !== JSON.stringify(initial);

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

  function toggleEverything(i: number) {
    setBundles((b) =>
      b.map((e, n) => {
        if (n !== i) return e;
        // Replacing rather than adding: `*` already covers every named grant, so
        // keeping both would leave a list that disagrees with itself.
        return e.grants.includes('*') ? { ...e, grants: [] } : { ...e, grants: ['*'] };
      }),
    );
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
            `index ${json.previousGeneratedAt} → ${json.generatedAt}`,
        );
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
      {bundles.map((b, i) => {
        const all = b.grants.includes('*');
        return (
          <section
            key={i}
            className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4"
          >
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <Field
                label="SKU"
                value={b.sku}
                onChange={(v) => patch(i, { sku: v })}
                mono
                hint="Must match the Play product id exactly"
              />
              <Field label="Title" value={b.title} onChange={(v) => patch(i, { title: v })} />
            </div>
            <div className="mt-3">
              <Field
                label="Summary"
                value={b.summary}
                onChange={(v) => patch(i, { summary: v })}
              />
            </div>

            <div className="mt-3">
              <div className="mb-1.5 flex items-center gap-2">
                <span className="text-micro text-ink-3">Grants</span>
                <button
                  onClick={() => toggleEverything(i)}
                  className={`rounded-md border px-1.5 py-px font-mono text-micro transition ${
                    all
                      ? 'border-accent/40 bg-accent-dim text-accent'
                      : 'border-line text-ink-3 hover:text-ink-2'
                  }`}
                >
                  everything
                </button>
                <span className="text-micro text-ink-3">
                  {all ? 'present and future packs' : `${b.grants.length} selected`}
                </span>
              </div>

              {!all && (
                <div className="flex flex-wrap gap-1.5">
                  {packs.map((p) => {
                    const on = b.grants.includes(p.packId);
                    return (
                      <button
                        key={p.packId}
                        onClick={() => toggleGrant(i, p.packId)}
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
                      purpose: a bundle can be announced before its contents
                      ship. They are shown so they are not mistaken for typos. */}
                  {b.grants
                    .filter((g) => g !== '*' && !packs.some((p) => p.packId === g))
                    .map((g) => (
                      <button
                        key={g}
                        onClick={() => toggleGrant(i, g)}
                        title="Not published yet. Legal, and it will start granting when it ships."
                        className="rounded-md border border-info/40 bg-info-dim px-2 py-1 font-mono text-micro text-info"
                      >
                        {g} ?
                      </button>
                    ))}
                </div>
              )}
            </div>

            <div className="mt-3 flex items-center gap-3">
              <button
                onClick={() => setBundles((x) => x.filter((_, n) => n !== i))}
                className="text-micro text-ink-3 transition hover:text-bad"
              >
                Delete bundle
              </button>
              {b.grants.length === 0 && (
                <span className="text-micro text-warn">
                  Grants nothing, so it cannot be saved
                </span>
              )}
            </div>
          </section>
        );
      })}

      <button
        onClick={() =>
          setBundles((b) => [...b, { sku: '', title: '', summary: '', grants: [] }])
        }
        className="w-full rounded-card border border-dashed border-line px-3 py-3 text-data text-ink-3 transition hover:border-line hover:text-ink-2"
      >
        Add a bundle
      </button>

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
          onClick={save}
          disabled={!dirty || busy}
          className="w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Signing index' : dirty ? 'Save and sign' : 'No changes'}
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
        className={`mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2 ${
          mono ? 'font-mono' : ''
        }`}
      />
      {hint && <p className="mt-1 text-micro text-ink-3">{hint}</p>}
    </div>
  );
}
