'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

import type { PlayLiteProduct } from '@/lib/core/play-lite';

interface PackRef {
  packId: string;
  title: string;
  sku?: string | null;
}

/**
 * One option for the product ID field.
 *
 * DERIVED from PlayLiteProduct rather than restated. This was a hand-copied
 * union of the three sources that existed when it was written, and it went
 * stale silently the day `sku-catalogue.ts` added a fourth. A Pick cannot.
 *
 * `import type` is erased at compile time, so naming a server module here puts
 * nothing in the client bundle.
 */
type ProductRef = Pick<PlayLiteProduct, 'productId' | 'title' | 'activeOptions' | 'source'>;

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
  products,
  productsDegraded,
  initial,
}: {
  app: string;
  packs: PackRef[];
  /** Product IDs from Play, the snapshot, or the signed index. May be empty. */
  products: ProductRef[];
  /** True when these did not come from Play just now. */
  productsDegraded: boolean;
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
          className="rounded-lg bg-site-accent px-4 py-2 text-[13px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
        >
          {busy ? 'Signing index' : dirty ? 'Save and sign' : 'No changes'}
        </button>
        {blocked && dirty && <span className="text-[11.5px] font-semibold text-site-plan">{blocked}</span>}
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          <div className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            {bundles.map((b, i) => {
              const problem = b.grants.length === 0 || !b.sku.trim();
              return (
                <button
                  key={i}
                  onClick={() => setSel(i)}
                  className={`flex w-full items-center gap-2.5 border-b border-site-line px-2.5 py-2 text-left transition last:border-b-0 sm:px-3 ${
                    problem ? 'border-l-2 border-l-site-plan' : ''
                  } ${sel === i ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'}`}
                >
                  <span className="min-w-0 flex-1">
                    <span
                      className={`block truncate font-mono text-[12.5px] ${
                        sel === i ? 'text-site-ink' : 'text-site-ink-2'
                      }`}
                    >
                      {b.sku || 'new bundle'}
                    </span>
                    <span className="block truncate text-[11px] text-site-ink-3">
                      {b.grants.length === 0
                        ? 'grants nothing'
                        : b.title || `${b.grants.length} granted`}
                    </span>
                  </span>
                  <span className="shrink-0 font-mono text-[11px] text-site-ink-3 tnum">
                    {b.grants.length} {b.grants.length === 1 ? 'grant' : 'grants'}
                  </span>
                </button>
              );
            })}

            <button
              onClick={add}
              className="w-full border-t border-dashed border-site-line px-3 py-2.5 text-[13px] font-semibold text-site-ink-3 transition hover:text-site-ink"
            >
              Add a bundle
            </button>
          </div>

          {error && (
            <p className="mt-3 rounded-card bg-site-plan-soft px-3 py-2 text-[13px] leading-relaxed text-site-plan">
              {error}
            </p>
          )}
          {result && (
            <p className="mt-3 rounded-card bg-site-ok-soft px-3 py-2 font-mono text-[11.5px] text-site-ok">
              {result}
            </p>
          )}
        </div>

        {current && (
          <aside className="w-full shrink-0 rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 lg:sticky lg:top-6 lg:w-72">
            <div className="font-mono text-[11px] text-site-ink-3">editing</div>

            <div className="mt-2 space-y-2">
              {/* A DATALIST, NOT A SELECT. A bundle's product ID is
                  legitimately chosen here FIRST and created in Play second, so
                  the field must stay freely typeable; but a product ID is
                  permanent and non-reusable, so typing one blind is how an
                  identifier gets burned. A datalist suggests without
                  constraining, which is exactly the shape of this decision. */}
              <SkuInput
                value={current.sku}
                onChange={(v) => patch(sel, { sku: v })}
                products={products}
                degraded={productsDegraded}
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

            <div className="mt-3 border-t border-site-line pt-2.5">
              <div className="mb-1.5 font-mono text-[11px] text-site-ink-3">
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
                          ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep'
                          : 'border-site-line text-site-ink-3 hover:text-site-ink'
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
                      className="rounded-md border border-site-info/40 bg-site-info-soft px-2 py-1 font-mono text-[11px] text-site-info"
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
                    className="rounded-md border border-site-plan/40 bg-site-plan-soft px-2 py-1 font-mono text-[11px] text-site-plan"
                  >
                    everything
                  </button>
                )}
              </div>

              {current.grants.includes('*') && (
                <p className="mt-2 text-[11px] leading-relaxed text-site-plan">
                  This grants every pack published from now on, forever, to
                  everyone who has already bought it. Remove it and name the
                  packs.
                </p>
              )}
              {current.grants.length === 0 && (
                <p className="mt-2 text-[11px] leading-relaxed text-site-plan">
                  A bundle that grants nothing cannot be signed, so it blocks the
                  save until it grants a pack or is deleted.
                </p>
              )}
              <p className="mt-2 text-[11px] leading-relaxed text-site-ink-3">
                Blue means named but not published yet, which is legal and starts
                granting when it ships.
              </p>
            </div>

            <div className="mt-3 border-t border-site-line pt-2.5">
              <button
                onClick={() => remove(sel)}
                className="text-[11px] text-site-ink-3 transition hover:text-site-plan"
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

/**
 * The product ID field: type freely, with what we know offered underneath.
 *
 * `activeOptions` is only a measurement for a product read from Play just now,
 * so the suffix on each suggestion says where it came from rather than implying
 * Play confirmed something nobody checked. Same rule as the distro builder's
 * SkuField, and for the same reason.
 */
/**
 * What a suggestion says about itself.
 *
 * A SWITCH RATHER THAN A TERNARY CHAIN, because the chain this replaced ended
 * in an else that meant "in the catalogue" and therefore labelled a manual
 * entry as published the moment that source was added. A manual id is the
 * opposite: created in Play Console and attached to nothing here yet.
 *
 * The default is deliberate rather than an oversight. A new source should show
 * a plain title rather than a claim about where it came from.
 */
function sourceLabel(p: ProductRef): string {
  const name = p.title ?? p.productId;
  switch (p.source) {
    case 'play':
      return p.activeOptions === 0 ? `${name} (not active)` : name;
    case 'snapshot':
      return `${name} (last seen in Play)`;
    case 'index':
      return `${name} (in the catalogue)`;
    case 'manual':
      return `${name} (noted by hand)`;
    default:
      return name;
  }
}

function SkuInput({
  value,
  onChange,
  products,
  degraded,
}: {
  value: string;
  onChange: (v: string) => void;
  products: ProductRef[];
  degraded: boolean;
}) {
  const listId = 'bundle-product-ids';
  return (
    <div>
      <label className="block text-micro text-site-ink-3">product ID</label>
      <input
        value={value}
        list={products.length > 0 ? listId : undefined}
        onChange={(e) => onChange(e.target.value)}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        placeholder="bundle_all_distros"
        className="mt-1 w-full rounded-xl border border-site-line bg-site-sunk px-3 py-2 font-mono text-[13px] text-site-ink focus:border-site-accent focus:outline-none"
      />
      {products.length > 0 && (
        <datalist id={listId}>
          {products.map((p) => (
            <option
              key={p.productId}
              value={p.productId}
              label={sourceLabel(p)}
            />
          ))}
        </datalist>
      )}
      <p className="mt-1 text-micro leading-relaxed text-site-ink-3">
        {products.length === 0
          ? 'No product IDs are known yet, so this is typed. It must match Play exactly.'
          : degraded
            ? 'Play could not be read, so these suggestions come from the last successful read and the published catalogue.'
            : 'Suggestions come from Play. A new ID can still be typed and created there afterwards.'}
      </p>
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
      <label className="block text-[11px] text-site-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        className={`mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-2.5 py-1.5 ${
          mono ? 'font-mono' : ''
        }`}
      />
      {hint && <p className="mt-1 text-[11px] leading-relaxed text-site-ink-3">{hint}</p>}
    </div>
  );
}
