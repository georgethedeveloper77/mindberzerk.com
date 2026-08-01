import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { BundlesForm } from '@/app/components/bundles-form';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SoftPanel } from '@/components/studio/ui';
import { readLiveIndex } from '@/lib/core/catalogue';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { skuCatalogue } from '@/lib/core/sku-catalogue';

export const dynamic = 'force-dynamic';

/**
 * BUNDLES - who owns what.
 *
 * ## The screen answers one question the pack list cannot
 *
 * The pack list says what a pack costs. It cannot say whether anyone can
 * actually buy it, because ownership has three routes: the pack is free, the
 * buyer owns `pack.sku`, or the buyer owns a bundle that grants it. A paid pack
 * whose product ID does not exist in Play and which no bundle grants is
 * unreachable, and nothing else reports that.
 *
 * ─── THE EDITOR LEADS, THE TABLE FOLLOWS ────────────────────────────────────
 *
 * An earlier version put four stat tiles and a full reachability table above
 * the editor, so the thing you came to change was below the fold on a laptop
 * and two screens down on a phone. Those counts live in the slab now; the table
 * keeps its place under the editor, where it reads as the consequence of the
 * edit above it rather than as a preamble to it.
 *
 * ─── PRODUCT IDS COME FROM THE MERGED CATALOGUE ─────────────────────────────
 *
 * A bundle's own product ID was a free-text field, in a panel where a product
 * ID is permanent and non-reusable, so a typo is a burned identifier and a
 * store listing that has to be rebuilt. `skuCatalogue` offers what Play knows,
 * what it last knew, and what the signed index already uses, each labelled by
 * source. The field stays typeable, because a bundle's ID is legitimately
 * chosen here first and created in Play second.
 *
 * ─── SELECTION IS CLIENT STATE, DELIBERATELY ────────────────────────────────
 *
 * Unlike Distros, Icons, CDN objects and Commerce, this page does not put the
 * selected row in the URL. It is one dirty array with a single save, so a link
 * navigation would remount the form and discard unsaved edits. That decision
 * lives inside `BundlesForm`, which is why the list sits in there with the
 * editor rather than out here on the server.
 */
export default async function BundlesPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const meta = appMeta(app);
  const [live, skus] = await Promise.all([
    readLiveIndex(app),
    skuCatalogue(app, meta?.pkg ?? null),
  ]);

  const grantedBy = (packId: string) =>
    live.entitlements.filter((e) => e.grants.includes('*') || e.grants.includes(packId));

  const paid = live.packs.filter((p) => p.sku);
  const unreachablePacks = paid.filter((p) => grantedBy(p.packId).length === 0);

  return (
    <StudioShell app={app}>
      {live.unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so nothing below reflects what is published and saving is
          blocked. {live.unreachable}
        </p>
      )}
      {live.corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is present but does not parse. Saving is blocked rather than overwriting it.
        </p>
      )}
      {!live.unreachable && !live.corrupt && live.packs.length === 0 && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          Nothing is published yet. A bundle needs at least one pack to grant, and an index with no
          packs cannot be signed.
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Bundles"
        meta={`${live.entitlements.length} ${live.entitlements.length === 1 ? 'bundle' : 'bundles'} · ${paid.length} paid ${paid.length === 1 ? 'pack' : 'packs'} · ${live.packs.length - paid.length} free`}
      />

      <BundlesForm
        app={app}
        packs={live.packs.map((p) => ({ packId: p.packId, title: p.title, sku: p.sku }))}
        products={skus.ok ? skus.products : []}
        productsDegraded={skus.ok ? !!skus.degraded : true}
        initial={live.entitlements.map((e) => ({
          sku: e.sku,
          title: e.title,
          summary: e.summary,
          grants: e.grants,
        }))}
      />

      <SoftPanel
        title="How each pack is obtained"
        note="free, its own product ID, or a bundle"
        right={
          unreachablePacks.length > 0 ? (
            <span className="rounded-full bg-site-plan-soft px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-site-plan">
              {unreachablePacks.length} on one route only
            </span>
          ) : undefined
        }
        flush
      >
        {live.packs.length === 0 ? (
          <p className="px-[18px] py-8 text-center text-[13px] text-site-ink-3">
            Nothing published yet.
          </p>
        ) : (
          live.packs.map((p) => {
            const via = grantedBy(p.packId);
            return (
              <div
                key={p.packId}
                className="flex flex-wrap items-center gap-3 border-t border-site-line px-[18px] py-2.5 first:border-t-0"
              >
                <span className="min-w-[160px] flex-1 truncate font-mono text-[12px] text-site-ink">
                  {p.packId}
                </span>

                {/* THE PRODUCT ID, SHOWN AS THE STRING ITSELF rather than as a
                    chip reading "paid". It is the value that has to match Play
                    exactly and it is permanent, so it should be readable and
                    copyable from here without opening anything. */}
                <span className="w-[190px] shrink-0 truncate font-mono text-[11.5px]">
                  {p.sku ? (
                    <span className="rounded-md bg-site-accent-soft px-2 py-1 text-site-accent-deep">
                      {p.sku}
                    </span>
                  ) : (
                    <span className="text-site-ink-3">free</span>
                  )}
                </span>

                <span className="w-[190px] shrink-0 truncate font-mono text-[11.5px] text-site-ink-3">
                  {via.length === 0 ? '-' : via.map((e) => e.sku).join(', ')}
                </span>

                <span
                  className={`shrink-0 rounded-full px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] ${
                    !p.sku || via.length > 0
                      ? 'bg-site-ok-soft text-site-ok'
                      : 'bg-site-sunk text-site-ink-3'
                  }`}
                >
                  {!p.sku
                    ? 'everyone'
                    : via.length > 0
                      ? `${via.length + 1} ways`
                      : 'its product ID only'}
                </span>
              </div>
            );
          })
        )}
      </SoftPanel>

      <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
        A bundle is one Play product that unlocks several packs. Every grant is named: a wildcard
        would include packs that do not exist yet and could never be withdrawn from anyone who
        already bought it.
      </p>
    </StudioShell>
  );
}
