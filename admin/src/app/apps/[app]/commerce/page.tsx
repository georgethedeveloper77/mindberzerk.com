import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { Shell } from '@/app/components/shell';
import {
  Banner,
  Card,
  Chip,
  Empty,
  Filter,
  Inspector,
  KV,
  PageHead,
  Row,
  Rows,
  Table,
  Td,
  Th,
  Toolbar,
  Tr,
} from '@/app/components/ui';
import { commerceReport, worstTone, type SkuRow } from '@/lib/core/commerce';
import { appName, isAppId } from '@/lib/core/registry';
import { skuKindLabel } from '@/lib/core/skus';

/**
 * COMMERCE - is everything that has a price actually for sale?
 *
 * The panel could already answer "what is published" and "what does it cost".
 * It could not answer the only question that matters to revenue, which is
 * whether the product behind that price exists in Play and can be bought. Those
 * live in two systems that agree only because a human typed the same string
 * into both.
 *
 * ─── SORTED BY SEVERITY, NOT ALPHABETICALLY ─────────────────────────────────
 *
 * This screen exists to surface a disagreement, so the disagreement goes at the
 * top with a red edge down its row. Alphabetical put the one broken product in
 * position four because `d` sorts before `i`, which is the correct order for a
 * list you are reading and the wrong one for a list you are checking.
 *
 * That sort plus the edge is also what retired the old "Needs attention" card:
 * it restated every problem a second time on the same screen, and two copies of
 * a warning is how one of them goes stale.
 *
 * ─── PURCHASE OPTIONS ARE UNPACKED, NOT COUNTED ─────────────────────────────
 *
 * The previous version showed `activeOptions` as a number, so "1 active" and
 * "0 active" was everything you learned. `play.ts` reads far more than that and
 * the page threw it away: which option is a DRAFT, whether the active one is
 * `legacyCompatible`, and how many regions carry a price. Those three are the
 * difference between "it does not sell" and "it does not sell because nobody
 * priced it", which is the difference between a mystery and a task.
 *
 * ─── FREE PACKS HAVE NO ROW ─────────────────────────────────────────────────
 *
 * A pack with no sku is not a product. `commerceReport` already omits them; the
 * count stays in the meta line so the absence is explained rather than looking
 * like packs went missing.
 *
 * `force-dynamic` because this reads Play on every load. It is an admin screen
 * for one person and correctness beats a cached page that says a sku is fine
 * five minutes after it stopped being fine.
 */
export const dynamic = 'force-dynamic';

const FILTERS = ['all', 'broken', 'warned', 'distro', 'icons', 'bundle'] as const;
type FilterName = (typeof FILTERS)[number];

const isFilter = (v: string | undefined): v is FilterName =>
  !!v && (FILTERS as readonly string[]).includes(v);

const RANK = { bad: 0, warn: 1, info: 2 } as const;

export default async function CommercePage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ sel?: string; filter?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { sel, filter } = await searchParams;
  const active: FilterName = isFilter(filter) ? filter : 'all';

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
  const broken = report.rows.filter((r) => worstTone(r.problems) === 'bad').length;
  const warned = report.rows.filter((r) => worstTone(r.problems) === 'warn').length;

  // Worst first, then by sku so the order is stable between loads. A clean row
  // sorts last on purpose: it needs nothing from you.
  const sorted = [...report.rows].sort((a, b) => {
    const at = worstTone(a.problems);
    const bt = worstTone(b.problems);
    const ar = at ? RANK[at] : 3;
    const br = bt ? RANK[bt] : 3;
    return ar !== br ? ar - br : a.sku.localeCompare(b.sku);
  });

  const shown = sorted.filter((r) => {
    switch (active) {
      case 'broken':
        return worstTone(r.problems) === 'bad';
      case 'warned':
        return worstTone(r.problems) === 'warn';
      case 'distro':
      case 'icons':
      case 'bundle':
        return r.kind === active;
      default:
        return true;
    }
  });

  const selected = shown.find((r) => r.sku === sel) ?? shown[0] ?? null;

  const href = (sku: string) =>
    `/apps/${app}/commerce?${active === 'all' ? '' : `filter=${active}&`}sel=${sku}#detail`;

  return (
    <Shell app={app} subtitle={report.packageName ?? 'no package name'}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Commerce' }]}
      />

      {report.indexError && (
        <Banner tone="bad">
          The CDN bucket could not be read, so the catalogue side of every row is
          missing rather than empty. {report.indexError}
        </Banner>
      )}
      {!report.indexError && !report.indexOk && (
        <Banner tone="warn">
          There is no signed index for this app yet, so nothing is published and
          nothing can be bought.
        </Banner>
      )}
      {!report.play.ok && (
        <Banner tone="warn">
          Play could not be read, so the store side of every row is unknown
          rather than broken. {report.play.error}
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} commerce`}
        meta={`${report.rows.length} ${report.rows.length === 1 ? 'product' : 'products'} · ${report.paidPackCount} paid ${report.paidPackCount === 1 ? 'pack' : 'packs'} · ${report.freePackCount} free`}
      />

      {/* The health of the join, as one line. Four stat tiles said less: two of
          them restated the meta above, and the two that mattered were the ones
          you had to read the table to trust. */}
      <div className="mb-3 flex flex-wrap gap-x-4 gap-y-1 rounded-card border border-line-soft px-3 py-2 font-mono text-micro text-ink-3">
        <span>
          sellable{' '}
          <span className="text-ink-2 tnum">
            {report.play.ok ? `${sellable} / ${report.rows.length}` : 'unknown'}
          </span>
        </span>
        <span>
          broken <span className={broken ? 'text-bad tnum' : 'text-ink-2 tnum'}>{broken}</span>
        </span>
        <span>
          warned <span className={warned ? 'text-warn tnum' : 'text-ink-2 tnum'}>{warned}</span>
        </span>
        <span>
          play{' '}
          <span className={report.play.ok ? 'text-ok' : 'text-warn'}>
            {report.play.ok ? 'reachable' : 'unreachable'}
          </span>
        </span>
      </div>

      <Toolbar>
        {FILTERS.map((f) => (
          <Filter
            key={f}
            href={`/apps/${app}/commerce${f === 'all' ? '' : `?filter=${f}`}`}
            active={active === f}
          >
            {f}
          </Filter>
        ))}
      </Toolbar>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          {shown.length === 0 ? (
            <Empty>
              {report.rows.length === 0
                ? 'No products. Every pack is free.'
                : `No ${active} products.`}
            </Empty>
          ) : (
            <Rows>
              {shown.map((r) => {
                const tone = worstTone(r.problems);
                const price =
                  r.play?.purchaseOptions.find((o) => o.state === 'ACTIVE' && o.samplePrice)
                    ?.samplePrice ?? null;
                return (
                  <Row
                    key={r.sku}
                    href={href(r.sku)}
                    selected={selected?.sku === r.sku}
                    tone={tone === 'bad' ? 'bad' : tone === 'warn' ? 'warn' : undefined}
                    title={<span className="font-mono">{r.sku}</span>}
                    subtitle={
                      r.unlocks.length === 0
                        ? 'unlocks nothing'
                        : `unlocks ${r.unlocks.join(', ')}`
                    }
                    chip={<PlayChip row={r} playOk={report.play.ok} />}
                    right={price ?? '-'}
                  />
                );
              })}
            </Rows>
          )}

          {playSide.length > 0 && (
            <div className="mt-3">
              <Card
                title={report.indexError ? 'Configured in Play' : 'In Play, not in the catalogue'}
                flush
                right={
                  <span className="font-mono text-micro text-ink-3">{playSide.length}</span>
                }
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
              Hidden from the storefront but still published and still purchasable
              by anyone who already owns them: {report.unlistedPaid.join(', ')}.
            </p>
          )}

          <p className="mt-3 text-micro leading-relaxed text-ink-3">
            A product ID is permanent. Play never releases one for reuse, so a
            rename means a new ID and a new store listing while the old one stays
            owned by everyone who bought it.
          </p>
        </div>

        {selected && (
          <Inspector>
            <div className="break-all font-mono text-data text-ink">{selected.sku}</div>
            {selected.title !== selected.sku && (
              <div className="mt-0.5 truncate text-micro text-ink-2">{selected.title}</div>
            )}

            {selected.problems.length > 0 && (
              <div className="mt-2.5 space-y-2">
                {selected.problems.map((p, i) => (
                  <p
                    key={i}
                    className={`border-l-2 pl-2 text-micro leading-relaxed ${
                      p.tone === 'bad'
                        ? 'border-bad text-bad'
                        : p.tone === 'warn'
                          ? 'border-warn text-warn'
                          : 'border-line text-ink-3'
                    }`}
                  >
                    {p.text}
                  </p>
                ))}
              </div>
            )}

            {/* The three fields the old page read and discarded. A product can
                be present, look complete in a list, and still be unsellable,
                and this is where that is visible. */}
            {report.play.ok && selected.play && selected.play.purchaseOptions.length > 0 && (
              <div className="mt-2.5 border-t border-line-soft pt-2.5">
                <div className="mb-1.5 font-mono text-micro text-ink-3">purchase options</div>
                <div className="space-y-1.5">
                  {selected.play.purchaseOptions.map((o) => (
                    <div
                      key={o.purchaseOptionId}
                      className="rounded-md border border-line-soft px-2 py-1.5"
                    >
                      <div className="flex items-baseline justify-between gap-2">
                        <span className="truncate font-mono text-micro text-ink-2">
                          {o.purchaseOptionId}
                        </span>
                        <span
                          className={`shrink-0 font-mono text-micro ${
                            o.state === 'ACTIVE' ? 'text-ok' : 'text-warn'
                          }`}
                        >
                          {o.state}
                        </span>
                      </div>
                      <div className="font-mono text-micro text-ink-3">
                        {o.kind} · {o.legacyCompatible ? 'legacy ok' : 'not legacy'} ·{' '}
                        {o.pricedRegions} {o.pricedRegions === 1 ? 'region' : 'regions'} priced
                        {o.samplePrice ? ` · ${o.samplePrice}` : ''}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="mt-2.5 border-t border-line-soft pt-1">
              <KV k="kind" v={skuKindLabel(selected.kind)} />
              <KV k="in Play" v={report.play.ok ? (selected.play ? 'yes' : 'no') : 'unknown'} />
              <KV
                k="unlocks"
                v={selected.unlocks.length === 0 ? 'nothing' : selected.unlocks.join(', ')}
              />
              {selected.grants.length > 0 && (
                <KV k="via bundle" v={selected.grants.join(', ')} />
              )}
            </div>

            {selected.problems.length === 0 && (
              <p className="mt-2 text-micro leading-relaxed text-ok">
                Nothing to fix. The index, the storefront and Play agree.
              </p>
            )}
          </Inspector>
        )}
      </div>
    </Shell>
  );
}

/** One chip: can this be bought right now, as far as anyone can tell? */
function PlayChip({ row, playOk }: { row: SkuRow; playOk: boolean }) {
  if (!playOk) return <Chip>unknown</Chip>;
  if (!row.play) return <Chip tone="bad">missing</Chip>;
  if (row.play.activeOptions === 0) return <Chip tone="bad">not active</Chip>;
  return (
    <Chip tone="ok">
      {row.play.activeOptions === 1 ? 'active' : `${row.play.activeOptions} active`}
    </Chip>
  );
}
