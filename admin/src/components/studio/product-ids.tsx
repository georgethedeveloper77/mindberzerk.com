'use client';

import { useMemo, useState } from 'react';

import { addProductIdAction, removeProductIdAction } from '@/app/apps/[app]/commerce/actions';
import type { ManualProduct } from '@/lib/core/product-ids';

/**
 * The product IDs this panel knows by hand.
 *
 * ## Why type an id at all, on a screen that reads Play
 *
 * Every other source in `sku-catalogue` is DERIVED: from Play, from a snapshot
 * of Play, or from ids already published in the signed index. None can know
 * about a product created in Play Console five minutes ago and attached to
 * nothing, which is exactly the state a new distro's product is in when you
 * need to type it into the builder.
 *
 * ## GROUPED BY KIND, AND EACH ROW SAYS WHETHER IT IS DOING ANYTHING
 *
 * A flat list of seven ids with an identical badge on every row is a list you
 * read once and then skip. Two facts make it useful: what kind of product it is
 * (the prefix already encodes that, so grouping is free), and WHAT IT CURRENTLY
 * UNLOCKS, which comes from the live index.
 *
 * That second one is the whole point. Picking an id in a builder does nothing
 * on its own; publishing writes it into the pack's entry in the signed index,
 * and only then does the id sell anything. So a row reading "not linked yet" is
 * a product Play can charge for that unlocks nothing, and a row reading
 * "unlocks kali-theme" is one that works. Neither was visible before.
 *
 * ## Adding one here does not create it in Play
 *
 * Product IDs are permanent and non-reusable, so they are created in Play
 * Console deliberately and this list only mirrors that decision. Removing one
 * does not delete anything either: a pack that already carries the id keeps
 * selling, because that lives in the signed index. This list decides what the
 * pickers OFFER and nothing more.
 */

interface Group {
  key: string;
  label: string;
  hint: string;
  test: (id: string) => boolean;
}

/**
 * The prefixes are a naming convention rather than a schema, so an id that
 * matches nothing still appears, under Other, rather than vanishing from a list
 * whose whole job is to be complete.
 */
const GROUPS: Group[] = [
  {
    key: 'distro',
    label: 'Distros',
    hint: 'the whole distro: theme plus its icons',
    test: (id) => id.startsWith('distro_'),
  },
  {
    key: 'icons',
    label: 'Icon packs',
    hint: 'the icon pack sold on its own',
    test: (id) => id.startsWith('icons_'),
  },
  {
    key: 'bundle',
    label: 'Bundles',
    hint: 'one product unlocking several packs',
    test: (id) => id.startsWith('bundle_'),
  },
];

export function ProductIds({
  app,
  initial,
  linked,
}: {
  app: string;
  initial: ManualProduct[];
  /**
   * What each id unlocks in the LIVE INDEX, keyed by product id. Computed on
   * the server, because it is a fact about what is published rather than about
   * this list.
   */
  linked: Record<string, string[]>;
}) {
  const [products, setProducts] = useState(initial);
  const [id, setId] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const grouped = useMemo(() => {
    const rest = [...products];
    const out: { group: Group; rows: ManualProduct[] }[] = [];
    for (const g of GROUPS) {
      const rows = rest.filter((p) => g.test(p.productId));
      for (const r of rows) rest.splice(rest.indexOf(r), 1);
      if (rows.length) out.push({ group: g, rows });
    }
    if (rest.length) {
      out.push({
        group: { key: 'other', label: 'Other', hint: 'no recognised prefix', test: () => true },
        rows: rest,
      });
    }
    return out;
  }, [products]);

  const unlinked = products.filter((p) => (linked[p.productId] ?? []).length === 0).length;

  async function add() {
    if (!id.trim()) return;
    setBusy(true);
    setError(null);
    const res = await addProductIdAction(app, id, note);
    if (res.ok) {
      setProducts(res.products);
      setId('');
      setNote('');
    } else {
      setError(res.error);
    }
    setBusy(false);
  }

  async function remove(productId: string) {
    setBusy(true);
    setError(null);
    const res = await removeProductIdAction(app, productId);
    if (res.ok) setProducts(res.products);
    else setError(res.error);
    setBusy(false);
  }

  const input =
    'w-full rounded-xl border border-site-line bg-site-sunk px-3 py-2 text-[13px] text-site-ink focus:border-site-accent focus:outline-none';

  return (
    <div>
      <div className="flex flex-col gap-2.5 sm:flex-row">
        <input
          value={id}
          onChange={(e) => setId(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') add();
          }}
          placeholder="distro_linux_mint_22"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          className={`${input} font-mono sm:w-[262px]`}
        />
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') add();
          }}
          placeholder="what it sells, in your words"
          className={input}
        />
        <button
          onClick={add}
          disabled={busy || !id.trim()}
          className="shrink-0 rounded-xl bg-site-accent px-4 py-2 text-[13px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
        >
          Add
        </button>
      </div>

      {error && (
        <p className="mt-2.5 rounded-xl bg-site-plan-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-plan">
          {error}
        </p>
      )}

      {products.length === 0 ? (
        <p className="mt-3 text-[12px] leading-relaxed text-site-ink-3">
          The list is empty because every seeded ID was forgotten. Create the product in Play
          Console first, then add its ID here so the builders can offer it.
        </p>
      ) : (
        <div className="mt-4 flex flex-col gap-4">
          {grouped.map(({ group, rows }) => (
            <div key={group.key}>
              <div className="mb-1.5 flex items-baseline gap-2">
                <span className="text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
                  {group.label}
                </span>
                <span className="text-[11px] text-site-ink-3">{group.hint}</span>
              </div>

              <div className="overflow-hidden rounded-xl border border-site-line">
                {rows.map((p) => {
                  const unlocks = linked[p.productId] ?? [];
                  return (
                    <div
                      key={p.productId}
                      className="flex flex-wrap items-center gap-x-3 gap-y-1 border-t border-site-line px-3 py-2.5 first:border-t-0"
                    >
                      <span className="w-[200px] shrink-0 truncate font-mono text-[12px] text-site-ink">
                        {p.productId}
                      </span>

                      <span className="min-w-[120px] flex-1 truncate text-[12.5px] text-site-ink-3">
                        {p.note || <span className="italic">no note</span>}
                      </span>

                      {/* WHAT IT ACTUALLY DOES. An id that unlocks nothing is a
                          product Play can charge for that delivers nothing, and
                          that is worth seeing without opening a builder. */}
                      {unlocks.length > 0 ? (
                        <span className="shrink-0 truncate rounded-full bg-site-ok-soft px-2.5 py-0.5 font-mono text-[10.5px] text-site-ok">
                          unlocks {unlocks.join(', ')}
                        </span>
                      ) : (
                        <span className="shrink-0 rounded-full bg-site-sunk px-2.5 py-0.5 text-[10.5px] text-site-ink-3">
                          not linked yet
                        </span>
                      )}

                      {/* addedAt 0 means seeded rather than saved. A dot, not a
                          badge: it repeats on every row and a full label there
                          drowns the one thing that varies. */}
                      {p.addedAt === 0 && (
                        <span
                          title="Transcribed from Play Console, not read from it"
                          className="size-1.5 shrink-0 rounded-full bg-site-ink-3/50"
                        />
                      )}

                      <button
                        onClick={() => remove(p.productId)}
                        disabled={busy}
                        className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan disabled:opacity-40"
                      >
                        Forget
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      <p className="mt-3.5 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
        {unlinked > 0 && (
          <>
            {unlinked} of these unlock nothing yet. An ID only sells something once a pack carrying
            it is published, so picking one in a builder is half the job and publishing is the other
            half.{' '}
          </>
        )}
        Adding an ID here does not create it in Play, and forgetting one does not delete it. A
        dotted row was transcribed from Play Console rather than read from it, and your own list
        replaces the seeded one the first time you add or forget anything.
      </p>
    </div>
  );
}
