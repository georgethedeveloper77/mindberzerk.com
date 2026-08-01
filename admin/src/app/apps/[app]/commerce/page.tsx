import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SoftPanel } from '@/components/studio/ui';
import { commerceReport, worstTone, type SkuRow } from '@/lib/core/commerce';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
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
 * That sort plus the edge is also what retired an old "Needs attention" card:
 * it restated every problem a second time on the same screen, and two copies of
 * a warning is how one of them goes stale.
 *
 * ─── PURCHASE OPTIONS ARE UNPACKED, NOT COUNTED ─────────────────────────────
 *
 * An earlier version showed `activeOptions` as a number, so "1 active" and "0
 * active" was everything you learned. `play.ts` reads far more than that and
 * the page threw it away: which option is a DRAFT, whether the active one is
 * `legacyCompatible`, and how many regions carry a price. Those three are the
 * difference between "it does not sell" and "it does not sell because nobody
 * priced it", which is the difference between a mystery and a task.
 *
 * ─── FREE PACKS HAVE NO ROW ─────────────────────────────────────────────────
 *
 * A pack with no sku is not a product. `commerceReport` already omits them; the
 * count stays in the header so the absence is explained rather than looking
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
  const playSide = report.indexError ? (report.play.ok ? report.play.products : []) : report.orphans;

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

  const matches = (r: SkuRow, f: FilterName) => {
    switch (f) {
      case 'broken':
        return worstTone(r.problems) === 'bad';
      case 'warned':
        return worstTone(r.problems) === 'warn';
      case 'distro':
      case 'icons':
      case 'bundle':
        return r.kind === f;
      default:
        return true;
    }
  };

  const shown = sorted.filter((r) => matches(r, active));
  const selected = shown.find((r) => r.sku === sel) ?? shown[0] ?? null;

  const meta = appMeta(app);
  const href = (sku: string) =>
    `/apps/${app}/commerce?${active === 'all' ? '' : `filter=${active}&`}sel=${sku}#detail`;

  return (
    <StudioShell app={app}>
      {report.indexError && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The CDN bucket could not be read, so the catalogue side of every row is missing rather
          than empty. {report.indexError}
        </p>
      )}
      {!report.indexError && !report.indexOk && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          There is no signed index for this app yet, so nothing is published and nothing can be
          bought.
        </p>
      )}
      {!report.play.ok && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          Play could not be read, so the store side of every row is unknown rather than broken.{' '}
          {report.play.error}
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Commerce"
        meta={`${report.rows.length} ${report.rows.length === 1 ? 'product' : 'products'} · ${report.paidPackCount} paid ${report.paidPackCount === 1 ? 'pack' : 'packs'} · ${report.freePackCount} free`}
      >
        {/* THE HEALTH OF THE JOIN, as one line. Four stat tiles said less: two
            restated the header, and the two that mattered were the ones you had
            to read the table to trust. */}
        <div className="mt-4 flex flex-wrap gap-x-5 gap-y-1.5 rounded-xl border border-white/10 bg-white/5 px-3.5 py-2.5 font-mono text-[11px] text-white/45">
          <span>
            sellable{' '}
            <span className="tnum text-white/80">
              {report.play.ok ? `${sellable} of ${report.rows.length}` : 'unknown'}
            </span>
          </span>
          <span>
            broken <span className={`tnum ${broken ? 'text-[#ff8b83]' : 'text-white/80'}`}>{broken}</span>
          </span>
          <span>
            warned <span className={`tnum ${warned ? 'text-[#ffb27a]' : 'text-white/80'}`}>{warned}</span>
          </span>
          <span>
            play{' '}
            <span className={report.play.ok ? 'text-[#5ee0a8]' : 'text-[#ffb27a]'}>
              {report.play.ok ? 'reachable' : 'unreachable'}
            </span>
          </span>
        </div>
      </AppSlab>

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const n = sorted.filter((r) => matches(r, f)).length;
          const on = active === f;
          return (
            <Link
              key={f}
              href={`/apps/${app}/commerce${f === 'all' ? '' : `?filter=${f}`}`}
              className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition ${
                on
                  ? 'border-site-accent/30 bg-site-accent-soft text-site-accent-deep'
                  : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
              }`}
            >
              {f}
              <span className="font-mono text-[11px] opacity-70">{n}</span>
            </Link>
          );
        })}
      </div>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_306px]">
        <div className="flex min-w-0 flex-col gap-4">
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            {shown.length === 0 ? (
              <p className="px-[18px] py-10 text-center text-[13px] text-site-ink-3">
                {report.rows.length === 0 ? 'No products. Every pack is free.' : `No ${active} products.`}
              </p>
            ) : (
              shown.map((r) => {
                const tone = worstTone(r.problems);
                const on = selected?.sku === r.sku;
                const price =
                  r.play?.purchaseOptions.find((o) => o.state === 'ACTIVE' && o.samplePrice)
                    ?.samplePrice ?? null;
                return (
                  <Link
                    key={r.sku}
                    href={href(r.sku)}
                    className={`relative flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition first:border-t-0 ${
                      on ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'
                    }`}
                  >
                    {/* The severity edge, which is the whole reason for the
                        sort. Selection takes the accent so the two never
                        compete for the same three pixels. */}
                    <span
                      aria-hidden
                      className={`absolute inset-y-0 left-0 w-[3px] ${
                        on
                          ? 'bg-site-accent'
                          : tone === 'bad' || tone === 'warn'
                            ? 'bg-site-plan'
                            : ''
                      }`}
                    />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-mono text-[12.5px] font-semibold text-site-ink">
                        {r.sku}
                      </span>
                      <span className="mt-0.5 block truncate text-[11px] text-site-ink-3">
                        {r.unlocks.length === 0 ? 'unlocks nothing' : `unlocks ${r.unlocks.join(', ')}`}
                      </span>
                    </span>
                    <PlayChip row={r} playOk={report.play.ok} />
                    <span
                      className={`w-[78px] shrink-0 text-right font-mono text-[11.5px] ${
                        price ? 'text-site-ink' : 'text-site-ink-3'
                      }`}
                    >
                      {price ?? '-'}
                    </span>
                  </Link>
                );
              })
            )}
          </section>

          {playSide.length > 0 && (
            <SoftPanel
              title={report.indexError ? 'Configured in Play' : 'In Play, not in the catalogue'}
              right={<span className="font-mono text-[11.5px] text-site-ink-3">{playSide.length}</span>}
              flush
            >
              {playSide.map((p) => (
                <div
                  key={p.productId}
                  className="flex items-center gap-3 border-t border-site-line px-[18px] py-2.5 first:border-t-0"
                >
                  <span className="w-[170px] shrink-0 truncate font-mono text-[11.5px] text-site-ink">
                    {p.productId}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[12.5px] text-site-ink-2">
                    {p.title ?? <span className="text-site-ink-3">no listing</span>}
                  </span>
                  <span
                    className={`shrink-0 font-mono text-[11.5px] ${
                      p.activeOptions === 0 ? 'text-site-plan' : 'text-site-ink-3'
                    }`}
                  >
                    {p.activeOptions} active
                  </span>
                </div>
              ))}
            </SoftPanel>
          )}

          {report.unlistedPaid.length > 0 && (
            <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[12px] leading-relaxed text-site-plan">
              Hidden from the storefront but still published and still purchasable by anyone who
              already owns them: {report.unlistedPaid.join(', ')}.
            </p>
          )}

          <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
            A product ID is permanent. Play never releases one for reuse, so a rename means a new ID
            and a new store listing while the old one stays owned by everyone who bought it.
          </p>
        </div>

        {selected && (
          <aside
            id="detail"
            className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4"
          >
            <div className="px-4 pb-4 pt-3.5">
              <div className="break-all font-mono text-[13px] font-semibold text-site-ink">
                {selected.sku}
              </div>
              {selected.title !== selected.sku && (
                <div className="mt-1 truncate text-[11.5px] text-site-ink-2">{selected.title}</div>
              )}

              {selected.problems.length > 0 && (
                <div className="mt-3 flex flex-col gap-2">
                  {selected.problems.map((p, i) => (
                    <p
                      key={i}
                      className={`rounded-xl px-3 py-2.5 text-[11.5px] leading-relaxed ${
                        p.tone === 'bad' || p.tone === 'warn'
                          ? 'bg-site-plan-soft text-site-plan'
                          : 'bg-site-sunk text-site-ink-3'
                      }`}
                    >
                      {p.text}
                    </p>
                  ))}
                </div>
              )}

              {/* The three fields an earlier page read and discarded. A product
                  can be present, look complete in a list, and still be
                  unsellable, and this is where that is visible. */}
              {report.play.ok && selected.play && selected.play.purchaseOptions.length > 0 && (
                <div className="mt-3 border-t border-site-line pt-3">
                  <div className="mb-2 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
                    Purchase options
                  </div>
                  <div className="flex flex-col gap-2">
                    {selected.play.purchaseOptions.map((o) => (
                      <div
                        key={o.purchaseOptionId}
                        className="rounded-xl border border-site-line bg-site-sunk px-2.5 py-2"
                      >
                        <div className="flex items-baseline justify-between gap-2">
                          <span className="truncate font-mono text-[11px] text-site-ink-2">
                            {o.purchaseOptionId}
                          </span>
                          <span
                            className={`shrink-0 rounded-full px-2 py-0.5 text-[9.5px] font-bold uppercase tracking-wide ${
                              o.state === 'ACTIVE'
                                ? 'bg-site-ok-soft text-site-ok'
                                : 'bg-site-plan-soft text-site-plan'
                            }`}
                          >
                            {o.state}
                          </span>
                        </div>
                        <div className="mt-1 font-mono text-[10.5px] leading-relaxed text-site-ink-3">
                          {o.kind} · {o.legacyCompatible ? 'legacy ok' : 'not legacy'} ·{' '}
                          {o.pricedRegions} {o.pricedRegions === 1 ? 'region' : 'regions'} priced
                          {o.samplePrice ? ` · ${o.samplePrice}` : ''}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="mt-3 border-t border-site-line">
                <KVRow k="kind" v={skuKindLabel(selected.kind)} />
                <KVRow
                  k="in Play"
                  v={report.play.ok ? (selected.play ? 'yes' : 'no') : 'unknown'}
                  tone={report.play.ok && !selected.play ? 'bad' : undefined}
                />
                <KVRow
                  k="unlocks"
                  v={
                    <span className="font-mono">
                      {selected.unlocks.length === 0 ? 'nothing' : selected.unlocks.join(', ')}
                    </span>
                  }
                />
                {selected.grants.length > 0 && (
                  <KVRow k="via bundle" v={<span className="font-mono">{selected.grants.join(', ')}</span>} />
                )}
              </div>

              {selected.problems.length === 0 && (
                <p className="mt-3 rounded-xl bg-site-ok-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-ok">
                  Nothing to fix. The index, the storefront and Play agree.
                </p>
              )}
            </div>
          </aside>
        )}
      </div>
    </StudioShell>
  );
}

/** One chip: can this be bought right now, as far as anyone can tell? */
function PlayChip({ row, playOk }: { row: SkuRow; playOk: boolean }) {
  const [text, skin] = !playOk
    ? ['unknown', 'bg-site-sunk text-site-ink-3']
    : !row.play
      ? ['missing', 'bg-site-plan-soft text-site-plan']
      : row.play.activeOptions === 0
        ? ['not active', 'bg-site-plan-soft text-site-plan']
        : [
            row.play.activeOptions === 1 ? 'active' : `${row.play.activeOptions} active`,
            'bg-site-ok-soft text-site-ok',
          ];
  return (
    <span
      className={`shrink-0 rounded-full px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] ${skin}`}
    >
      {text}
    </span>
  );
}
