import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import {
  Banner,
  Button,
  Card,
  Chip,
  Grid,
  KV,
  PageHead,
  Stat,
  bytes,
  when,
} from '@/app/components/ui';
import { indexIsSigned, readLiveIndex, type AppId } from '@/lib/catalogue';
import { commerceReport, worstTone } from '@/lib/commerce';
import { appMeta, appName, isAppId } from '@/lib/registry';
import { ensureSeededSafe } from '@/lib/themes';

export const dynamic = 'force-dynamic';

/**
 * THE APP LANDING. Health, not analytics.
 *
 * This route redirected to Packs, and before that it 404'd. Neither answered
 * the question you actually open this panel with, which on the evidence of
 * every session so far is "is anything broken", not "how many installs".
 *
 * ─── WHY THE NUMBERS YOU EXPECT ARE NOT HERE ────────────────────────────────
 *
 * Installs, active users, engagement, countries and revenue are deliberately
 * absent, and the reason is already written on the portfolio overview: a
 * dashboard that shows a plausible number it did not measure is worse than one
 * that shows nothing, because you stop checking the source. The BigQuery export
 * is not wired, so those cards would be dashes for weeks, and a landing page of
 * placeholders teaches you to skip the landing page.
 *
 * Revenue is a stronger no. It lives in Play's financial reports, which is the
 * system of record, and rebuilding it here creates a second number for the one
 * thing that must never have two answers. Play and Firebase render all of it
 * better than this panel will, so they are LINKED rather than copied.
 *
 * When the export lands, this is where it goes: the analytics card is shaped
 * for it and says "not connected" honestly until then.
 *
 * ─── EVERY BANNER, IN ONE PLACE ─────────────────────────────────────────────
 *
 * Each failure this panel reports was visible only on its own page, so finding
 * out something was wrong meant visiting six screens. They are aggregated here,
 * which is the whole argument for a landing page: one look tells you whether to
 * keep going.
 */
export default async function AppOverviewPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  const appId = app as AppId;

  // In parallel: R2, Play and the seeded drafts are unrelated services and the
  // page waits on the slowest either way.
  const [live, commerce, seeded] = await Promise.all([
    readLiveIndex(appId),
    commerceReport(appId),
    ensureSeededSafe(appId),
  ]);
  const signed = live.exists ? await indexIsSigned(appId).catch(() => false) : false;

  const meta = appMeta(appId);
  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const iconPacks = live.packs.filter((p) => iconTypes.has(p.packType));
  const themePacks = live.packs.filter((p) => p.packType === 'theme');

  // Distros = published theme packs unioned with seeded drafts, which is what
  // the Distros page lists. Counting only published would report zero for a
  // launcher that ships three inside its APK.
  const distroIds = new Set([
    ...themePacks.map((p) => p.packId),
    ...seeded.drafts.map((d) => d.id),
  ]);

  const broken = commerce.rows.filter((r) => worstTone(r.problems) === 'bad');
  const sellable = commerce.rows.filter((r) => r.sellable).length;
  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);

  const bucketDown = !!(live.unreachable || seeded.unreachable);
  const playDown = !commerce.play.ok;

  const projectId = process.env.GCP_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;

  return (
    <Shell app={appId} subtitle={meta?.pkg ?? 'admin.mindberzerk.com'}>
      {bucketDown && (
        <Banner tone="bad">
          The CDN bucket could not be read, so every catalogue figure below is a
          default rather than a measurement.{' '}
          {live.unreachable ?? seeded.unreachable}
        </Banner>
      )}
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Publishing is blocked rather
          than overwriting it, because a bad merge drops every pack from the store.
        </Banner>
      )}
      {live.exists && !signed && (
        <Banner tone="bad">
          index.json is published without index.sig. Every device refuses it and
          keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      )}
      {broken.length > 0 && (
        <Banner tone="bad">
          {broken.length === 1
            ? `${broken[0].sku} cannot be bought.`
            : `${broken.length} products cannot be bought.`}{' '}
          A price is advertised that Play will not charge. See Commerce.
        </Banner>
      )}
      {/* Narrowed INLINE rather than through `playDown`. PlayCatalogue is a
          discriminated union, and TypeScript cannot carry the narrowing through
          a boolean stored in a variable, so `commerce.play.error` is only
          reachable inside a direct check on `.ok`. The compiler caught this,
          which is the union doing its job: the error message only exists on the
          failure arm. */}
      {!commerce.play.ok && (
        <Banner tone="warn">
          Play could not be read, so whether anything is sellable is unknown
          rather than broken. {commerce.play.error}
        </Banner>
      )}

      <PageHead
        title={appName(appId)}
        meta={meta?.pkg ?? undefined}
        actions={
          <Button href={`/apps/${appId}/distros/builder`} variant="primary">
            New distro
          </Button>
        }
      />

      <Grid cols={4}>
        <Stat
          label="Packs live"
          value={bucketDown ? '\u2014' : live.packs.length}
          sub={bucketDown ? 'bucket unreachable' : bytes(size)}
          tone={bucketDown ? 'warn' : 'plain'}
          href={`/apps/${appId}/packs`}
        />
        <Stat
          label="Index"
          value={bucketDown ? '\u2014' : signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
          sub={bucketDown ? undefined : when(live.generatedAt)}
          tone={bucketDown ? 'warn' : signed ? 'ok' : live.exists ? 'bad' : 'plain'}
        />
        <Stat
          label="Sellable"
          value={playDown ? '\u2014' : `${sellable} / ${commerce.rows.length}`}
          sub={
            playDown
              ? 'Play unreachable'
              : broken.length
                ? `${broken.length} broken`
                : 'all good'
          }
          tone={playDown ? 'warn' : broken.length ? 'bad' : 'ok'}
          href={`/apps/${appId}/commerce`}
        />
        <Stat
          label="Distros"
          value={distroIds.size}
          sub={`${iconPacks.length} icon ${iconPacks.length === 1 ? 'pack' : 'packs'}`}
          href={`/apps/${appId}/distros`}
        />
      </Grid>

      <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-[1fr_1fr]">
        <Card title="Inventory">
          <KV
            k="Distros"
            v={`${distroIds.size} · ${seeded.drafts.filter((d) => d.bundled).length} bundled`}
          />
          <KV
            k="Icon packs"
            v={`${iconPacks.length} · ${iconPacks.filter((p) => p.packType === 'brand').length} brand`}
          />
          <KV k="Paid packs" v={live.packs.filter((p) => p.sku).length} />
          <KV k="Bundles" v={live.entitlements.length} />
          <KV k="On the CDN" v={bucketDown ? '\u2014' : bytes(size)} />
        </Card>

        <Card title="Analytics">
          {/* NOT CONNECTED, said plainly, rather than dashes pretending to be a
              measurement. When the BigQuery export is on, the funnel and
              retention blocks move here and this paragraph goes. */}
          <p className="text-data leading-relaxed text-ink-2">
            Installs, active users, engagement and countries are rendered by Play
            and Firebase, which are the systems of record. This panel does not
            rebuild them, and revenue least of all: a second number for the one
            thing that must have a single answer is worse than a link.
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            {meta?.pkg && (
              <Button href={`https://play.google.com/console/u/0/developers`}>
                Play Console
              </Button>
            )}
            {projectId && (
              <Button
                href={`https://console.firebase.google.com/project/${projectId}/analytics`}
              >
                Firebase analytics
              </Button>
            )}
            <Button href={`/apps/${appId}/analytics`}>What this panel adds</Button>
          </div>
          {!projectId && (
            <p className="mt-2 text-micro leading-relaxed text-warn">
              GCP_PROJECT is not set, so the Firebase link and the Config screen
              have no project to point at.
            </p>
          )}
        </Card>
      </div>

      <div className="mt-3 sm:mt-4">
        <Card title="Delivery">
          <KV k="Bucket" v={process.env.R2_BUCKET ?? 'mindberzerk-cdn'} />
          <KV k="Key id" v={live.keyId || (process.env.PACK_KEY_ID ?? '-')} />
          <KV k="Package" v={meta?.pkg ?? '-'} />
          <KV
            k="Signing"
            v={
              <Chip tone={signed ? 'ok' : live.exists ? 'bad' : 'plain'}>
                {signed ? 'valid' : live.exists ? 'missing' : 'nothing published'}
              </Chip>
            }
          />
        </Card>
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A pack only reaches devices when its version increases, and the index is
        what advertises it. Publishing signs both; unpublishing removes the entry
        and every device drops the pack on its next sync.
      </p>
    </Shell>
  );
}
