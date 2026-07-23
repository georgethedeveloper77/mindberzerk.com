import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/catalogue';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { IconBuilder } from '@/app/components/icon-builder';
import { Banner, Card, Chip, Grid, PageHead, Stat, Table, Td, Th, Tr, bytes } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C8 — the icon builder.
 *
 * ## What this is not
 *
 * It is not an icon pack APK builder. `appfilter.xml`, CandyBar and
 * `gradlew assembleRelease` exist so OTHER launchers can read your icons, and
 * this ecosystem owns its launcher. Compiling an APK would mean a Play release
 * per icon change, no rollout control, and no way to tie a pack to a Billing
 * entitlement. Hero packs go over the CDN like everything else.
 *
 * There are also no density buckets. mdpi through xxxhdpi are how resources get
 * compiled into an APK and chosen at install time; these are fetched at runtime
 * and rendered natively at whatever size the launcher asks for, so five variants
 * would multiply pack size for nothing and give the icon cache five things to
 * disagree about.
 */
export default async function IconsPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const live = await readLiveIndex(app);
  const hero = live.packs.filter((p) => p.packType === 'hero');
  const brand = live.packs.filter((p) => p.packType === 'brand');

  // A hero pack barely larger than its pack.json has no images beside it — the
  // yaru case, where `heroPack: "yaru"` resolves to nothing and every app falls
  // through to the generator with no error anywhere. The threshold is a proxy
  // (a real pack of even a few PNGs clears it comfortably), not a hard fact.
  const empty = hero.filter((p) => p.sizeBytes < 8192);

  const publishedVersion: Record<string, number> = {};
  for (const p of hero) publishedVersion[p.packId] = p.version;

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      {empty.length > 0 && (
        <Banner tone="warn">
          {empty.map((p) => p.packId).join(', ')} contains almost nothing, so a
          theme naming it gets the generator for every app and reports no error.
        </Banner>
      )}

      {/* The disk cache key carries the pack id but not its version, so the
          launcher only re-renders icons when onPackChanged fires, which is
          gated on a verified NEW pack landing. Republishing the same version is
          a no-op on device. The pack route's monotonic version bump is what
          makes an update actually reach a phone. Worth stating because a hero
          pack looks correct in the panel the instant it uploads. */}
      <p className="mb-3 text-micro leading-relaxed text-ink-3">
        A hero pack only reaches devices when its version increases. The disk
        cache is keyed by pack id, not version, so republishing the same number
        changes nothing on a phone even though the panel shows the new bytes.
      </p>

      <PageHead
        title={`${appName(app)} icons`}
        meta={`${hero.length} hero · ${brand.length} brand`}
      />

      <Grid cols={4}>
        <Stat label="Hero packs" value={hero.length} />
        <Stat label="Brand packs" value={brand.length} />
        <Stat
          label="Hero bytes"
          value={bytes(hero.reduce((n, p) => n + p.sizeBytes, 0))}
        />
        <Stat label="Empty" value={empty.length} tone={empty.length ? 'warn' : 'plain'} />
      </Grid>

      {hero.length > 0 && (
        <div className="mt-3 sm:mt-4">
          <Card title="Published icon packs" flush>
            <Table
              head={
                <>
                  <Th>Pack</Th>
                  <Th>Type</Th>
                  <Th num>Ver</Th>
                  <Th num>Size</Th>
                  <Th>State</Th>
                </>
              }
            >
              {[...hero, ...brand].map((p) => (
                <Tr key={p.packId}>
                  <Td mono>{p.packId}</Td>
                  <Td>
                    <Chip>{p.packType}</Chip>
                  </Td>
                  <Td num>{p.version}</Td>
                  <Td num>{bytes(p.sizeBytes)}</Td>
                  <Td>
                    {p.sizeBytes < 4096 ? (
                      <Chip tone="warn">no art</Chip>
                    ) : (
                      <Chip tone="ok">live</Chip>
                    )}
                  </Td>
                </Tr>
              ))}
            </Table>
          </Card>
        </div>
      )}

      <div className="mt-3 sm:mt-4">
        <IconBuilder
          app={app}
          publishedIds={hero.map((p) => p.packId)}
          publishedVersion={publishedVersion}
        />
      </div>
    </Shell>
  );
}
