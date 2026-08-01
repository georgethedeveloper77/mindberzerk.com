'use client';

import { useState } from 'react';

import { addProductIdAction, removeProductIdAction } from '@/app/apps/[app]/commerce/actions';
import type { ManualProduct } from '@/lib/core/product-ids';

/**
 * The product IDs this panel knows by hand.
 *
 * ## Why type an id at all, on a screen that reads Play
 *
 * Every other source in `sku-catalogue` is DERIVED: from Play, from a snapshot
 * of Play, or from ids already published in the signed index. None of them can
 * know about a product created in Play Console five minutes ago and attached to
 * nothing, which is exactly the state a new distro's product is in when you
 * need to type it into the builder.
 *
 * So this is the bridge: add it once here, and the distro builder, the icon
 * builder, Upload pack and Bundles all offer it from then on.
 *
 * ## Adding one here does not create it in Play
 *
 * Product IDs are permanent and non-reusable, so they are created in Play
 * Console deliberately and this list only mirrors that decision. Removing one
 * here does not delete anything either: a pack that already carries the id
 * keeps selling, because that lives in the signed index. This list decides what
 * the pickers OFFER and nothing more.
 */
export function ProductIds({ app, initial }: { app: string; initial: ManualProduct[] }) {
  const [products, setProducts] = useState(initial);
  const [id, setId] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
          className={`${input} font-mono sm:w-[280px]`}
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
          Console first, then add its ID here so the builders can offer it instead of you typing it
          twice.
        </p>
      ) : (
        <div className="mt-3">
          {products.map((p) => (
            <div
              key={p.productId}
              className="flex items-center gap-3 border-t border-site-line py-2.5 first:border-t-0"
            >
              <span className="w-[220px] shrink-0 truncate font-mono text-[12px] text-site-ink">
                {p.productId}
              </span>
              <span className="min-w-0 flex-1 truncate text-[12.5px] text-site-ink-3">
                {p.note || <span className="italic">no note</span>}
              </span>
              {/* addedAt 0 means this row came from the seed rather than from a
                  save. Worth saying: it explains why seven ids appeared without
                  anyone typing them, and it warns that the seed is a
                  transcription of Play rather than a reading of it. */}
              {p.addedAt === 0 && (
                <span className="hidden shrink-0 rounded-full bg-site-sunk px-2 py-0.5 text-[9.5px] font-bold uppercase tracking-[0.05em] text-site-ink-3 sm:inline">
                  from Play, transcribed
                </span>
              )}
              <button
                onClick={() => remove(p.productId)}
                disabled={busy}
                className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan disabled:opacity-40"
              >
                Forget
              </button>
            </div>
          ))}
        </div>
      )}

      <p className="mt-3 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
        Adding an ID here does not create it in Play, and forgetting one does not delete it: a pack
        that already carries the ID keeps selling. This list only decides what the builders offer.
        Rows marked as transcribed were seeded from Play Console and are replaced by your own list
        the first time you add or forget anything.
      </p>
    </div>
  );
}
