import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/catalogue';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { BundlesForm } from '@/app/components/bundles-form';
import { Banner, Card, Chip, Empty, PageHead, Table, Td, Th, Tr } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C6 - who owns what.
 *
 * ## The screen answers one question the pack list cannot
 *
 * The pack list says what a pack costs. It cannot say whether anyone can
 * actually buy it, because ownership has three routes: the pack is free, the
 * buyer owns `pack.sku`, or the buyer owns a bundle that grants it. A paid pack
 * whose SKU does not exist in Play and which no bundle grants is unreachable,
 * and nothing anywhere reports that today.
 *
 * ─── THE EDITOR LEADS, THE TABLE FOLLOWS ────────────────────────────────────
 *
 * The previous version put four stat tiles and a full reachability table above
 * the editor, so the thing you came to change was below the fold on a laptop
 * and two screens down on a phone. The counts those tiles carried are now in
 * the meta line and in the rows themselves; the table keeps its place under the
 * list, where it reads as the consequence of the edit above it rather than as a
 * preamble to it.
 *
 * ─── SELECTION IS CLIENT STATE, DELIBERATELY ────────────────────────────────
 *
 * Unlike Distros, Icons, CDN objects and Commerce, this page does not put the
 * selected row in the URL. It is one dirty array with a single save, so a link
 * navigation would remount the form and discard unsaved edits. That decision
 * lives inside `BundlesForm` and is why the list is in there with the editor
 * rather than out here on the server.
 */
export default async function BundlesPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const live = await readLiveIndex(app);

  const grantedBy = (packId: string) =>
    live.entitlements.filter((e) => e.grants.includes('*') || e.grants.includes(packId));

  const paid = live.packs.filter((p) => p.sku);

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Bundles' }]}
      />

      {live.unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so nothing below reflects what is
          published and saving is blocked. {live.unreachable}
        </Banner>
      )}
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Saving is blocked rather than
          overwriting it.
        </Banner>
      )}
      {!live.unreachable && !live.corrupt && live.packs.length === 0 && (
        <Banner tone="warn">
          Nothing is published yet. A bundle needs at least one pack to grant, and
          an index with no packs cannot be signed.
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} bundles`}
        meta={`${live.entitlements.length} ${live.entitlements.length === 1 ? 'bundle' : 'bundles'} · ${paid.length} paid ${paid.length === 1 ? 'pack' : 'packs'} · ${live.packs.length - paid.length} free`}
      />

      <BundlesForm
        app={app}
        packs={live.packs.map((p) => ({ packId: p.packId, title: p.title, sku: p.sku }))}
        initial={live.entitlements.map((e) => ({
          sku: e.sku,
          title: e.title,
          summary: e.summary,
          grants: e.grants,
        }))}
      />

      <div className="mt-3">
        <Card title="How each pack is obtained" flush>
          {live.packs.length === 0 ? (
            <div className="p-4">
              <Empty>Nothing published yet.</Empty>
            </div>
          ) : (
            <Table
              head={
                <>
                  <Th>Pack</Th>
                  <Th>Own product ID</Th>
                  <Th>Granted by</Th>
                  <Th>Reachable</Th>
                </>
              }
            >
              {live.packs.map((p) => {
                const via = grantedBy(p.packId);
                return (
                  <Tr key={p.packId}>
                    <Td mono>{p.packId}</Td>
                    <Td>
                      {p.sku ? <Chip tone="warn">{p.sku}</Chip> : <Chip tone="ok">free</Chip>}
                    </Td>
                    <Td mono dim>
                      {via.length === 0 ? '-' : via.map((e) => e.sku).join(', ')}
                    </Td>
                    <Td>
                      {!p.sku ? (
                        <Chip tone="ok">everyone</Chip>
                      ) : via.length > 0 ? (
                        <Chip tone="ok">{via.length + 1} ways</Chip>
                      ) : (
                        <Chip>its product ID only</Chip>
                      )}
                    </Td>
                  </Tr>
                );
              })}
            </Table>
          )}
        </Card>
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A bundle is one Play product that unlocks several packs. Every grant is
        named: a wildcard would include packs that do not exist yet and could
        never be withdrawn from anyone who already bought it.
      </p>
    </Shell>
  );
}
