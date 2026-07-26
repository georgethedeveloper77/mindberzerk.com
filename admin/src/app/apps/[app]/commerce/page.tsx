import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, Card, Chip, Grid, PageHead, Stat, Table, Td, Th, Tr } from '@/app/components/ui';
import { commerceReport, worstTone, type SkuRow } from '@/lib/commerce';
import { appName, isAppId } from '@/lib/registry';
import { skuKindLabel } from '@/lib/skus';

/**
 * COMMERCE — is everything that has a price actually for sale?
 *
 * The panel could already answer "what is published" and "what does it cost".
 * It could not answer the only question that matters to revenue, which is
 * whether the product behind that price exists in Play and can be bought. Those
 * live in two systems that agree only because a human typed the same string
 * into both, and they are already out of step: one distro sits in Play with no
 * active purchase option, so its buy button has never worked and nothing
 * anywhere reports it.
 *
 * `force-dynamic` because this reads Play on every load. It is an admin screen
 * for one person and correctness beats a cached page that says a sku is fine
 * five minutes after it stopped being fine.
 */
export const dynamic = 'force-dynamic';

export default async function CommercePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const report = await commerceReport(app);

  // With the bucket unreachable there is no catalogue to compare against, so
  // "orphan" would be a lie about every product. Show the Play side plainly
  // instead: it is the half that still loaded, and it is worth seeing.
  const playSide = report.indexError
    ? report.play.ok
      ? report.play.products
      : []
    : report.orphans;

  const sellable = report.rows.filter((r) => r.sellable).length;
  const broken = report.rows.filter((r) => worstTone(r.problems) === 'bad');
  const warned = report.rows.filter((r) => worstTone(r.problems) === 'warn');

  return (
    <Shell app={app} subtitle={report.packageName ?? 'no package name'}>
      {report.indexError && (
        <Banner tone="bad">
          The CDN bucket could not be read, so the catalogue side of every row is missing
          rather than empty. {report.indexError}
        </Banner>
      )}

      {!report.indexError && !report.indexOk && (
        <Banner tone="warn">
          There is no signed index for this app yet, so nothing is published and nothing can
          be bought.
        </Banner>
      )}

      {!report.play.ok && (
        <Banner tone="warn">
          Play could not be read, so the store side of every row is unknown rather than
          broken. {report.play.error}
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} commerce`}
        meta={`${report.rows.length} ${report.rows.length === 1 ? 'product' : 'products'} · ${report.paidPackCount} paid · ${report.freePackCount} free`}
      />

      <Grid cols={4}>
        <Stat label="Products" value={report.rows.length} />
        <Stat
          label="Sellable"
          value={report.play.ok ? `${sellable} / ${report.rows.length}` : '—'}
          sub={report.play.ok ? 'active in Play' : 'Play unreachable'}
          tone={report.play.ok && sellable < report.rows.length ? 'warn' : 'plain'}
        />
        <Stat
          label="Broken"
          value={broken.length}
          sub="cannot be bought"
          tone={broken.length ? 'warn' : 'plain'}
        />
        <Stat label="Paid packs" value={report.paidPackCount} />
      </Grid>

      {!report.indexError && (broken.length > 0 || warned.length > 0) && (
        <div className="mt-3 sm:mt-4">
          <Card title="Needs attention">
            <div className="space-y-3">
              {[...broken, ...warned].map((r) => (
                <Problems key={r.sku} row={r} />
              ))}
            </div>
          </Card>
        </div>
      )}

      {!report.indexError && (
      <div className="mt-3 sm:mt-4">
        <Card title="Products" flush>
          <Table
            head={
              <>
                <Th>Product ID</Th>
                <Th>Kind</Th>
                <Th>Unlocks</Th>
                <Th>Play</Th>
                <Th>Price</Th>
              </>
            }
          >
            {report.rows.map((r) => {
              const active = r.play?.purchaseOptions.filter((o) => o.state === 'ACTIVE') ?? [];
              const price = active.find((o) => o.samplePrice)?.samplePrice ?? null;

              return (
                <Tr key={r.sku}>
                  <Td mono>{r.sku}</Td>
                  <Td>
                    <Chip>{skuKindLabel(r.kind)}</Chip>
                  </Td>
                  <Td>
                    {r.unlocks.length === 0 ? (
                      <span className="text-ink-3">nothing</span>
                    ) : (
                      <span className="text-ink-2">{r.unlocks.join(', ')}</span>
                    )}
                  </Td>
                  <Td>
                    {!report.play.ok ? (
                      <Chip>unknown</Chip>
                    ) : !r.play ? (
                      <Chip tone="bad">missing</Chip>
                    ) : r.play.activeOptions === 0 ? (
                      <Chip tone="bad">not active</Chip>
                    ) : (
                      <Chip tone="ok">
                        {r.play.activeOptions === 1 ? 'active' : `${r.play.activeOptions} active`}
                      </Chip>
                    )}
                  </Td>
                  <Td num>{price ?? <span className="text-ink-3">—</span>}</Td>
                </Tr>
              );
            })}
          </Table>
        </Card>
      </div>
      )}

      {playSide.length > 0 && (
        <div className="mt-3 sm:mt-4">
          <Card
            title={report.indexError ? 'Configured in Play' : 'In Play, not in the catalogue'}
            flush
          >
            <Table
              head={
                <>
                  <Th>Product ID</Th>
                  <Th>Title</Th>
                  <Th num>Active</Th>
                </>
              }
            >
              {playSide.map((p) => (
                <Tr key={p.productId}>
                  <Td mono>{p.productId}</Td>
                  <Td>{p.title ?? <span className="text-ink-3">no listing</span>}</Td>
                  <Td num>{p.activeOptions}</Td>
                </Tr>
              ))}
            </Table>
          </Card>
        </div>
      )}

      {report.unlistedPaid.length > 0 && (
        <p className="mt-3 text-micro leading-relaxed text-ink-3">
          Hidden from the storefront but still published and still purchasable by anyone
          who already owns them: {report.unlistedPaid.join(', ')}.
        </p>
      )}

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A product ID is permanent. Play never releases one for reuse, so a rename means a
        new ID and a new store listing while the old one stays owned by everyone who bought
        it.
      </p>
    </Shell>
  );
}

/** One sku's problems, worst first. Not a table: these are sentences. */
function Problems({ row }: { row: SkuRow }) {
  return (
    <div className="border-l-2 border-line pl-3">
      <div className="font-mono text-data text-ink">{row.sku}</div>
      <ul className="mt-1 space-y-1">
        {row.problems.map((p, i) => (
          <li
            key={i}
            className={
              p.tone === 'bad'
                ? 'text-micro leading-relaxed text-bad'
                : p.tone === 'warn'
                  ? 'text-micro leading-relaxed text-warn'
                  : 'text-micro leading-relaxed text-ink-3'
            }
          >
            {p.text}
          </li>
        ))}
      </ul>
    </div>
  );
}
