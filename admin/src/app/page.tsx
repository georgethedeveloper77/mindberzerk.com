import { adminGate } from '@/app/components/admin-gate';
import { indexIsSigned, readLiveIndex } from '@/lib/catalogue';
import { MANAGED, REGISTRY, type AppId } from '@/lib/registry';
import { Shell } from './components/shell';
import { Banner, Button, Chip, KV, Metric, PageHead, Panel, when } from './components/ui';

export const dynamic = 'force-dynamic';

/**
 * ALL APPS - the portfolio, and ONLY the portfolio.
 *
 * ## What this page stopped doing, and why
 *
 * It used to lead with packs live, bytes on the CDN, index signed and last
 * publish, summed across every managed app. Those are CATALOGUE figures, and
 * summing them across a portfolio produces numbers that mean nothing: two apps
 * where one has a catalogue and the other has never published gives "2 packs
 * live" as a portfolio metric, which is really G Launcher's 2 with a zero
 * added. It reads as a measurement of the whole business and is a measurement
 * of one app.
 *
 * Those figures belong on the app that owns them, and that is exactly where
 * they are: `/apps/g-launcher` carries packs, storage, composition and the task
 * list for its own catalogue. This page answers the question one level up:
 * WHICH APPS EXIST, what state is each in, and is any of them shouting.
 *
 * ## So the metrics are counts of apps, not counts of packs
 *
 * Live, building, planned, external. Those come from the registry, which is the
 * only thing here that is genuinely portfolio-shaped, and they stay meaningful
 * as the registry grows with every app that ships on the stores.
 *
 * ## Per-app cards carry a status line, not a dashboard
 *
 * Each managed app shows whether its bucket answered and whether its index is
 * signed, because that is the one fact you want without clicking. Everything
 * else is one tap away on the app's own overview. An app card is a door with a
 * light on it, not a second dashboard.
 *
 * ## Reading every app must not let one break the others
 *
 * `readLiveIndex` reaches R2, so a missing credential has to be survivable:
 * this is the page you load to find out something is wrong. The read reports
 * `unreachable` rather than throwing, and that flag is read explicitly; the
 * try/catch is a backstop for `indexIsSigned` and anything that starts throwing
 * later.
 */

interface AppStatus {
  id: AppId;
  packs: number;
  signed: boolean;
  exists: boolean;
  corrupt: boolean;
  generatedAt: number;
  error: string | null;
}

async function readApp(id: AppId): Promise<AppStatus> {
  try {
    const live = await readLiveIndex(id);
    // Only ask about the signature when there is an index to sign. A bucket with
    // no index for an app that has not shipped is the normal case, not a fault.
    const signed = live.exists ? await indexIsSigned(id) : false;
    return {
      id,
      packs: live.packs.length,
      signed,
      exists: live.exists,
      corrupt: live.corrupt,
      generatedAt: live.generatedAt,
      error: live.unreachable,
    };
  } catch (e) {
    return {
      id,
      packs: 0,
      signed: false,
      exists: false,
      corrupt: false,
      generatedAt: 0,
      error: (e as Error).message,
    };
  }
}

export default async function AllAppsPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const statuses = await Promise.all(MANAGED.map((a) => readApp(a.id as AppId)));
  const byId = new Map(statuses.map((s) => [s.id as string, s]));

  const live = REGISTRY.filter((a) => a.state === 'live').length;
  const building = REGISTRY.filter((a) => a.state === 'build').length;
  const planned = REGISTRY.filter((a) => a.state === 'planned').length;
  const external = REGISTRY.filter((a) => a.state === 'external').length;

  const unreachable = statuses.filter((s) => s.error);
  const unsigned = statuses.filter((s) => s.exists && !s.signed);
  const corrupt = statuses.filter((s) => s.corrupt);

  return (
    <Shell>
      {corrupt.map((s) => (
        <Banner key={s.id} tone="bad">
          {s.id}: index.json is present but does not parse. Publishing is blocked
          rather than overwriting it, because a bad merge drops every pack from
          the store.
        </Banner>
      ))}
      {unsigned.map((s) => (
        <Banner key={s.id} tone="bad">
          {s.id}: index.json is published without index.sig. Every device refuses
          it and keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      ))}
      {unreachable.map((s) => (
        <Banner key={s.id} tone="bad">
          {s.id}: the bucket could not be read, so its card below shows what is
          unknown rather than what is published. {s.error}
        </Banner>
      ))}

      <PageHead
        title="All apps"
        meta={`${REGISTRY.length} in the registry · ${MANAGED.length} managed here`}
        actions={<Button href="/site" variant="primary">Site content</Button>}
      />

      {/* COUNTS OF APPS, NOT OF PACKS. A portfolio metric has to be about the
          portfolio; anything summed out of one app's catalogue belongs on that
          app's own overview, where it is not pretending to describe the rest. */}
      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
        <Metric label="Live on the store" value={live} sub="published" tone={live ? 'ok' : 'plain'} />
        <Metric label="In build" value={building} sub="not shipped yet" />
        <Metric label="Planned" value={planned} sub="no package yet" />
        <Metric label="External" value={external} sub="own Firebase project" />
      </div>

      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-2">
        {REGISTRY.map((a) => {
          const s = byId.get(a.id) ?? null;
          return (
            <section key={a.id} className="rounded-card bg-surface-1 p-3 sm:p-4">
              <div className="flex items-center gap-2.5">
                <span
                  className="grid size-7 shrink-0 place-items-center rounded-lg font-mono text-data font-bold text-surface-0"
                  style={{ background: a.tint }}
                >
                  {a.mark}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-data font-medium text-ink">{a.name}</span>
                  <span className="block truncate font-mono text-micro text-ink-3">
                    {a.pkg ?? 'no package yet'}
                  </span>
                </span>
                <Chip
                  tone={
                    a.state === 'live'
                      ? 'ok'
                      : a.state === 'build'
                        ? 'info'
                        : a.state === 'external'
                          ? 'info'
                          : 'plain'
                  }
                >
                  {a.state}
                </Chip>
              </div>

              {a.blurb && (
                <p className="mt-2 text-micro leading-relaxed text-ink-3">{a.blurb}</p>
              )}

              {/* THE STATUS LINE, and only for apps this panel administers.
                  An externally administered app has no catalogue here, so a
                  status line about one would be an invented fact. */}
              {s && (
                <div className="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1 font-mono text-micro">
                  {s.error ? (
                    <span className="text-warn">bucket unreachable</span>
                  ) : s.corrupt ? (
                    <span className="text-bad">index corrupt</span>
                  ) : !s.exists ? (
                    <span className="text-ink-3">nothing published</span>
                  ) : (
                    <>
                      <span className={s.signed ? 'text-ok' : 'text-bad'}>
                        {s.signed ? 'index signed' : 'index unsigned'}
                      </span>
                      <span className="text-ink-3">
                        {s.packs} {s.packs === 1 ? 'pack' : 'packs'}
                      </span>
                      <span className="text-ink-3">updated {when(s.generatedAt)}</span>
                    </>
                  )}
                </div>
              )}

              <div className="mt-3 flex flex-wrap items-center gap-2">
                {a.managed ? (
                  <Button href={`/apps/${a.id}`}>Open</Button>
                ) : (
                  <span className="text-micro text-ink-3">
                    Administered outside this panel.
                  </span>
                )}
                {a.pkg && a.state === 'live' && (
                  <Button href={`https://play.google.com/store/apps/details?id=${a.pkg}`}>
                    Store listing
                  </Button>
                )}
              </div>
            </section>
          );
        })}
      </div>

      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-2">
        <Panel title="Signing and delivery">
          {/* GENUINELY PORTFOLIO-LEVEL: one bucket, one signing key and one CDN
              serve every managed app, so these belong here rather than being
              repeated on each app's overview. */}
          <KV k="Bucket" v={process.env.R2_BUCKET ?? 'mindberzerk-cdn'} />
          <KV k="Key id" v={process.env.PACK_KEY_ID ?? 'mh-2026-07'} />
          <KV k="CDN" v={process.env.CDN_BASE_URL ?? 'cdn.mindberzerk.com'} />
          <KV k="Apps with a catalogue" v={`${statuses.filter((s) => s.exists).length} of ${MANAGED.length}`} />
        </Panel>

        <Panel title="Publisher">
          <p className="text-micro leading-relaxed text-ink-3">
            The public site lists every app from this same registry, so adding an
            app here is what makes it appear there. Installs and revenue live in
            Play and Firebase, which are the systems of record.
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            <Button href="/site">Site content</Button>
            <Button href="https://play.google.com/console/u/0/developers">Play Console</Button>
          </div>
        </Panel>
      </div>
    </Shell>
  );
}
