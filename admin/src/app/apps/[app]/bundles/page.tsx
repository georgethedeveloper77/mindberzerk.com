import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/catalogue';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { BundlesForm } from '@/app/components/bundles-form';
import { Banner, Card, Chip, Empty, Grid, PageHead, Stat, Table, Td, Th, Tr } from '@/app/components/ui';

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
 * So the table above the editor is the reachability view: every pack, and how it
 * can be obtained.
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
  const unreachable = paid.filter((p) => grantedBy(p.packId).length === 0);

  // A grant that names nothing in the catalogue. Legal on purpose, since a
  // bundle can be announced before its contents ship, so this is a count rather
  // than a warning.
  const pending = live.entitlements
    .flatMap((e) => e.grants)
    .filter((g) => g !== '*' && !live.packs.some((p) => p.packId === g));

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Saving is blocked rather than
          overwriting it.
        </Banner>
      )}
      {live.packs.length === 0 && (
        <Banner tone="warn">
          Nothing is published yet. A bundle needs at least one pack to grant, and
          an index with no packs cannot be signed.
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} bundles`}
        meta={`${live.entitlements.length} bundles · ${paid.length} paid packs`}
      />

      <Grid cols={4}>
        <Stat label="Bundles" value={live.entitlements.length} />
        <Stat label="Paid packs" value={paid.length} sub={`${live.packs.length - paid.length} free`} />
        <Stat
          label="Sold individually only"
          value={unreachable.length}
          tone={unreachable.length ? 'warn' : 'plain'}
        />
        <Stat label="Grants pending" value={pending.length} sub="named, not yet published" />
      </Grid>

      <div className="mt-3 sm:mt-4">
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
                  <Th>Own SKU</Th>
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
                    <Td>{p.sku ? <Chip tone="warn">{p.sku}</Chip> : <Chip tone="ok">free</Chip>}</Td>
                    <Td mono dim>
                      {via.length === 0 ? '-' : via.map((e) => e.sku).join(', ')}
                    </Td>
                    <Td>
                      {!p.sku ? (
                        <Chip tone="ok">everyone</Chip>
                      ) : via.length > 0 ? (
                        <Chip tone="ok">{via.length + 1} ways</Chip>
                      ) : (
                        <Chip>its SKU only</Chip>
                      )}
                    </Td>
                  </Tr>
                );
              })}
            </Table>
          )}
        </Card>
      </div>

      <div className="mt-3 sm:mt-4">
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
      </div>
    </Shell>
  );
}
