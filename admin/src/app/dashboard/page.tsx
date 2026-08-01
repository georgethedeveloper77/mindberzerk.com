import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import {
  AppRow,
  Cond,
  KVRow,
  Ribbon,
  Slab,
  SlabCell,
  SlabGrid,
  SoftButton,
  SoftPanel,
} from '@/components/studio/ui';
import { indexIsSigned, readLiveIndex } from '@/lib/core/catalogue';
import { STUDIO_ID, readLegalStatuses } from '@/lib/studio/legal';
import {
  APP_STORE_DEVELOPER_URL,
  MANAGED,
  PLAY_DEVELOPER_URL,
  REGISTRY,
  appMeta,
  type AppId,
} from '@/lib/core/registry';
import { delta, siteTraffic } from '@/lib/studio/site-traffic';

export const dynamic = 'force-dynamic';

/**
 * THE STUDIO DASHBOARD.
 *
 * ## What it answers, one level above an app
 *
 * Which apps exist, what state each is in, what is currently in the way, and
 * how the public site is doing. Catalogue figures (packs, bytes, composition)
 * stay on the app that owns them; summing them across a portfolio produces
 * numbers that describe one app while pretending to describe the business.
 *
 * ## Unknown is a first-class value here
 *
 * Three of the things this page reports can be unreadable at any moment: the
 * bucket (credentials), Play (403), GA4 (not connected). Each renders as a
 * NAMED absence, never as a zero, and the condition ribbon states the blocker
 * in one line. Rendering a zero for an unreadable figure is how a dashboard
 * teaches you to stop believing it.
 *
 * ## One read must not sink the others
 *
 * Every source is read independently and every failure is caught locally. This
 * is the page you open to find out something is broken, so it has to survive
 * the thing being broken.
 */

interface AppStatus {
  id: AppId;
  packs: number;
  signed: boolean;
  exists: boolean;
  corrupt: boolean;
  error: string | null;
}

async function readApp(id: AppId): Promise<AppStatus> {
  try {
    const live = await readLiveIndex(id);
    // Only ask about a signature when there is an index to sign. A bucket with
    // no index for an app that has not shipped is normal, not a fault.
    const signed = live.exists ? await indexIsSigned(id) : false;
    return {
      id,
      packs: live.packs.length,
      signed,
      exists: live.exists,
      corrupt: live.corrupt,
      error: live.unreachable,
    };
  } catch (e) {
    return { id, packs: 0, signed: false, exists: false, corrupt: false, error: (e as Error).message };
  }
}

/** A sparkline from daily counts. Returns null when there is nothing to draw. */
function sparkline(series: { users: number }[]): string | null {
  if (series.length < 2) return null;
  const max = Math.max(...series.map((d) => d.users), 1);
  const step = 420 / (series.length - 1);
  return series
    .map((d, i) => `${i === 0 ? 'M' : 'L'}${(i * step).toFixed(1)} ${(110 - (d.users / max) * 98).toFixed(1)}`)
    .join(' ');
}

export default async function DashboardPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const [statuses, traffic, legal] = await Promise.all([
    Promise.all(MANAGED.map((a) => readApp(a.id as AppId))),
    siteTraffic(30),
    readLegalStatuses(),
  ]);
  const byId = new Map(statuses.map((s) => [s.id as string, s]));

  const live = REGISTRY.filter((a) => a.state === 'live' || a.state === 'external').length;
  const building = REGISTRY.filter((a) => a.state === 'build');

  const unreachable = statuses.filter((s) => s.error);
  const unsigned = statuses.filter((s) => s.exists && !s.signed);
  const corrupt = statuses.filter((s) => s.corrupt);
  const bucketReadable = unreachable.length === 0;
  const totalPacks = statuses.reduce((n, s) => n + s.packs, 0);

  const smtpReady = !!(process.env.SITE_SMTP_HOST && process.env.SITE_CONTACT_TO);
  const contactEmail = process.env.NEXT_PUBLIC_CONTACT_EMAIL ?? 'info@mindberzerk.com';

  const visitors = traffic.connected ? traffic.data.visitors : null;
  const change = traffic.connected ? delta(traffic.data.visitors, traffic.data.previous) : null;
  const path = traffic.connected ? sparkline(traffic.data.series) : null;
  const topSource = traffic.connected ? traffic.data.sources[0] ?? null : null;

  return (
    <StudioShell>
      <Slab
        eyebrow="Studio"
        title={`${REGISTRY.length} apps. Two stores. One catalogue.`}
        sub="Everything the studio ships, and everything currently in the way of shipping more."
      >
        <SlabGrid>
          <SlabCell label="Live on a store" value={live} of={`of ${REGISTRY.length}`} note="published and downloadable" />
          <SlabCell
            label="In build"
            value={building.length}
            note={building.map((a) => a.name).join(', ') || 'nothing in build'}
          />
          {bucketReadable ? (
            <SlabCell
              label="Packs on the CDN"
              value={totalPacks}
              note={`across ${MANAGED.length} managed apps`}
            />
          ) : (
            <SlabCell label="Packs on the CDN" value="unknown" measured={false} note="bucket unreachable" />
          )}
          {visitors === null ? (
            <SlabCell label="Visitors, 30 days" value="not measured" measured={false} note="analytics not connected" />
          ) : (
            <SlabCell
              label="Visitors, 30 days"
              value={visitors.toLocaleString()}
              note={change === null ? 'no prior window' : `${change > 0 ? '+' : ''}${change}% vs previous`}
            />
          )}
        </SlabGrid>

        {/* BLOCKERS FIRST. The ribbon is scanned left to right and the things
            that need doing have to be the things you hit first. */}
        <Ribbon>
          {corrupt.map((s) => (
            <Cond key={`c-${s.id}`} tone="bad">{s.id}: index.json does not parse</Cond>
          ))}
          {unsigned.map((s) => (
            <Cond key={`u-${s.id}`} tone="bad">{s.id}: index published unsigned</Cond>
          ))}
          {unreachable.map((s) => (
            <Cond key={`r-${s.id}`} tone="bad">{s.id}: bucket unreachable</Cond>
          ))}
          {legal.filter((l) => !l.published && !l.unknown).length > 0 && (
            <Cond tone="warn">
              {legal.filter((l) => !l.published && !l.unknown).length} legal documents unpublished
            </Cond>
          )}
          {!traffic.connected && <Cond tone="warn">Site analytics not connected</Cond>}
          {!smtpReady && <Cond tone="warn">Contact form falling back to mailto</Cond>}
          {bucketReadable && <Cond tone="ok">Bucket readable</Cond>}
          {unsigned.length === 0 && unreachable.length === 0 && corrupt.length === 0 && (
            <Cond tone="ok">Every catalogue signed</Cond>
          )}
        </Ribbon>
      </Slab>

      <SoftPanel
        title="Apps"
        note="from the registry"
        right={<SoftButton href="/apps/g-launcher/registry">Edit registry</SoftButton>}
        flush
      >
        {REGISTRY.map((a) => {
          const s = byId.get(a.id) ?? null;
          const status = !s ? (
            a.managed ? null : (
              <span>administered elsewhere</span>
            )
          ) : s.error ? (
            <span className="font-semibold text-site-plan">bucket unreachable</span>
          ) : s.corrupt ? (
            <span className="font-semibold text-site-plan">index corrupt</span>
          ) : !s.exists ? (
            <span>nothing published</span>
          ) : (
            <span className={s.signed ? 'font-semibold text-site-ok' : 'font-semibold text-site-plan'}>
              {s.signed ? `${s.packs} ${s.packs === 1 ? 'pack' : 'packs'} signed` : 'index unsigned'}
            </span>
          );

          return (
            <AppRow
              key={a.id}
              app={a}
              status={status}
              action={a.managed ? <SoftButton href={`/apps/${a.id}`}>Open</SoftButton> : undefined}
            />
          );
        })}
      </SoftPanel>

      <div className="grid gap-4 lg:grid-cols-[1.5fr_1fr]">
        <SoftPanel title="Site traffic" note="mindberzerk.com">
          {!traffic.connected ? (
            <div className="rounded-[15px] border-[1.5px] border-dashed border-site-line bg-site-sunk p-5">
              <b className="mb-1.5 block text-[13.5px] font-bold text-site-ink">Analytics is not connected.</b>
              <p className="max-w-[52ch] text-[12.5px] leading-relaxed text-site-ink-3">{traffic.reason}</p>
              {/* A GHOST, NOT A CHART. Flat bars in the hairline colour, so it
                  reads as the shape of a thing that is missing rather than as
                  data nobody bothered to label. */}
              <div className="my-4 flex h-16 items-end gap-1.5 opacity-40" aria-hidden>
                {[38, 56, 44, 70, 52, 64, 48, 76, 58, 66, 50, 72].map((h, i) => (
                  <span key={i} className="flex-1 rounded-t bg-site-line" style={{ height: `${h}%` }} />
                ))}
              </div>
              <SoftButton href="https://analytics.google.com/analytics/web/" variant="primary" external>
                Open GA4 admin
              </SoftButton>
            </div>
          ) : (
            <div>
              <div className="flex items-start gap-5">
                <div className="w-[118px] shrink-0">
                  <div className="text-[11.5px] font-semibold text-site-ink-3">Visitors</div>
                  <div className="font-site-display text-[36px] font-extrabold leading-none tracking-[-0.04em] text-site-ink">
                    {traffic.data.visitors.toLocaleString()}
                  </div>
                  {change !== null && (
                    <span
                      className={`mt-2 inline-flex items-center gap-1 rounded-full px-2.5 py-[3px] text-[11.5px] font-bold ${
                        change >= 0 ? 'bg-site-ok-soft text-site-ok' : 'bg-site-plan-soft text-site-plan'
                      }`}
                    >
                      {change >= 0 ? '+' : ''}
                      {change}%
                    </span>
                  )}
                  <div className="mt-3 text-[11px] leading-relaxed text-site-ink-3">
                    vs {traffic.data.previous.toLocaleString()}
                    <br />
                    previous 30 days
                  </div>
                </div>
                <div className="min-w-0 flex-1">
                  {path ? (
                    <svg viewBox="0 0 420 118" className="h-[118px] w-full" preserveAspectRatio="none" aria-hidden>
                      <defs>
                        <linearGradient id="spark" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--color-site-accent)" stopOpacity="0.3" />
                          <stop offset="100%" stopColor="var(--color-site-accent)" stopOpacity="0" />
                        </linearGradient>
                      </defs>
                      <path d={path} fill="none" stroke="var(--color-site-accent)" strokeWidth="2.5" strokeLinecap="round" />
                      <path d={`${path} L420 118 L0 118 Z`} fill="url(#spark)" />
                    </svg>
                  ) : (
                    <p className="text-[12px] text-site-ink-3">Not enough days yet to draw a trend.</p>
                  )}
                </div>
              </div>

              {traffic.data.sources.length > 0 && (
                <div className="mt-3.5 border-t border-site-line pt-2">
                  {traffic.data.sources.map((s) => {
                    const top = traffic.data.sources[0].users || 1;
                    return (
                      <div key={s.source} className="flex items-center gap-2.5 py-2">
                        <span className="w-28 shrink-0 truncate text-[12.5px] font-medium text-site-ink">
                          {s.source}
                        </span>
                        <span className="h-2 min-w-0 flex-1 overflow-hidden rounded-full bg-site-sunk">
                          <span
                            className="block h-full rounded-full bg-site-accent"
                            style={{ width: `${Math.round((s.users / top) * 100)}%` }}
                          />
                        </span>
                        <span className="w-12 shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                          {s.users.toLocaleString()}
                        </span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </SoftPanel>

        <SoftPanel
          title="Legal"
          note="terms and privacy"
          right={<SoftButton href={`/legal/${STUDIO_ID}`}>Studio</SoftButton>}
        >
          {/* REAL STATE NOW. `readLegal` accepts the reserved studio id, so
              whether a document exists is a question this page can finally ask
              rather than guess. Unknown is its own pill: a bucket that will not
              answer is not the same fact as a document nobody has written, and
              only one of the two is a task. */}
          <div className="flex flex-col">
            {legal.map((l) => (
              <div key={l.id} className="flex items-center gap-3 border-b border-site-line py-2.5 last:border-b-0">
                <span
                  aria-hidden
                  className="grid size-[30px] shrink-0 place-items-center rounded-[9px] font-site-display text-[12px] font-extrabold text-white"
                  style={{
                    background:
                      l.id === STUDIO_ID
                        ? 'conic-gradient(from 210deg at 60% 40%, #6d4ae8, #a04ae8, #e8703a, #6d4ae8)'
                        : `linear-gradient(140deg, ${appMeta(l.id)?.tint ?? '#6d4ae8'}, color-mix(in srgb, ${appMeta(l.id)?.tint ?? '#6d4ae8'} 55%, #1c1526))`,
                  }}
                >
                  {l.id === STUDIO_ID ? 'M' : appMeta(l.id)?.mark ?? '?'}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[13px] font-medium text-site-ink">
                    {l.name}, terms and privacy
                  </span>
                  <span className="block truncate font-mono text-[10.5px] text-site-ink-3">
                    site/legal/{l.id}.json
                  </span>
                </span>
                {l.unknown ? (
                  <span className="rounded-full bg-site-sunk px-2 py-[2.5px] text-[10px] font-bold uppercase tracking-[0.05em] text-site-ink-3">
                    unknown
                  </span>
                ) : l.published ? (
                  <span className="rounded-full bg-site-ok-soft px-2 py-[2.5px] text-[10px] font-bold uppercase tracking-[0.05em] text-site-ok">
                    published
                  </span>
                ) : (
                  <span className="rounded-full bg-site-plan-soft px-2 py-[2.5px] text-[10px] font-bold uppercase tracking-[0.05em] text-site-plan">
                    not written
                  </span>
                )}
                <SoftButton href={l.id === STUDIO_ID ? `/legal/${STUDIO_ID}` : `/apps/${l.id}/legal`}>
                  Edit
                </SoftButton>
              </div>
            ))}
          </div>
        </SoftPanel>
      </div>

      <div className="grid gap-4 pb-2 lg:grid-cols-2">
        <SoftPanel title="Signing and delivery" note="one bucket, one key">
          <KVRow k="Bucket" v={<span className="font-mono">{process.env.R2_BUCKET ?? 'mindberzerk-cdn'}</span>} />
          <KVRow k="Key id" v={<span className="font-mono">{process.env.PACK_KEY_ID ?? 'mh-2026-07'}</span>} />
          <KVRow k="CDN" v={<span className="font-mono">{process.env.CDN_BASE_URL ?? 'cdn.mindberzerk.com'}</span>} />
          <KVRow
            k="Bucket reads"
            v={bucketReadable ? 'working' : 'rejected'}
            tone={bucketReadable ? 'ok' : 'bad'}
          />
        </SoftPanel>

        <SoftPanel
          title="Stores"
          note="publisher pages"
          right={
            <>
              <SoftButton href={PLAY_DEVELOPER_URL} external>
                Play
              </SoftButton>
              <SoftButton href={APP_STORE_DEVELOPER_URL} external>
                App Store
              </SoftButton>
            </>
          }
        >
          <KVRow k="Contact delivery" v={smtpReady ? 'SMTP configured' : 'mailto fallback'} tone={smtpReady ? 'ok' : 'warn'} />
          <KVRow k="Messages go to" v={<span className="font-mono">{contactEmail}</span>} />
          <KVRow
            k="Top source, 30 days"
            v={topSource ? `${topSource.source}, ${topSource.users.toLocaleString()}` : 'not measured'}
          />
        </SoftPanel>
      </div>
    </StudioShell>
  );
}
