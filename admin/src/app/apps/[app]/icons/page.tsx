import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, Button, Chip, PageHead } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { readLiveIndex, type AppId } from '@/lib/catalogue';
import { isListed, readListing } from '@/lib/listing';
import { readPackJson } from '@/lib/pack-content';
import { appName, isAppId } from '@/lib/registry';

export const dynamic = 'force-dynamic';

/**
 * ICONS — the inventory, matching Distros.
 *
 * This page used to be four stat cards, a table, and the builder all stacked on
 * one route. The builder now lives at `/icons/builder`, the same split Distros
 * has: a list you browse and an editor you open. A page that is both is a page
 * where publishing something is three screens of scrolling away from seeing
 * what you already published.
 *
 * ─── THE PREVIEW IS THE PACK'S OWN ART, FROM THE CDN ────────────────────────
 *
 * Unlike a theme, an icon pack cannot be rendered from its metadata: it IS the
 * art. So the preview loads the real PNGs, and it can, because the bucket is
 * served publicly at `cdn.mindberzerk.com` and pack objects live under an
 * immutable versioned path. The same bytes a phone downloads.
 *
 * That means the preview is honest in a way a mockup could not be. A pack whose
 * icons are the wrong size, wrongly cropped or accidentally opaque looks wrong
 * HERE, before anyone installs it.
 *
 * The images are fetched by the BROWSER, not the server, so an unreadable R2
 * credential does not hide them: the public read path and the S3 signing path
 * are different doors, and only the second one is currently shut.
 *
 * ─── LINKED TO A DISTRO, OR NOT ─────────────────────────────────────────────
 *
 * An icon pack is either part of a distro or it stands alone, and which one
 * decides how it is bought: a distro's pack is granted by `distro_<base>` and
 * usually also sold by itself, while a standalone pack has only its own SKU.
 * The entitlement is authoritative and the `<base>-` prefix is the fallback for
 * free distros that have no entitlement to read.
 */

/** Where the bucket is served publicly. Not the S3 endpoint, which is signed. */
function cdnBase(): string {
  return (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
}

interface IconPackCard {
  packId: string;
  title: string;
  packType: string;
  version: number;
  sizeBytes: number;
  sku: string | null;
  listed: boolean;
  /** The theme pack this belongs to, or null when it stands alone. */
  distro: string | null;
  /** Absolute URLs to a handful of the pack's icons. */
  sampleUrls: string[];
  iconCount: number;
}

export default async function IconsPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  const appId = app as AppId;

  const [live, listing] = await Promise.all([readLiveIndex(appId), readListing(appId)]);

  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const packs = live.packs.filter((p) => iconTypes.has(p.packType));

  const cards: IconPackCard[] = await Promise.all(
    packs.map(async (p) => {
      // The theme pack that grants this one, if any.
      const grant = live.entitlements.find((e) => e.grants.includes(p.packId));
      const distro =
        grant?.grants.find((g) => g !== p.packId && g.endsWith('-theme')) ??
        live.packs.find(
          (t) =>
            t.packType === 'theme' &&
            t.packId.replace(/-theme$/, '') === p.packId.replace(/-icons$/, ''),
        )?.packId ??
        null;

      // pack.json names every icon file. A failed read costs this card its
      // preview and nothing else, which is why it is caught per pack rather
      // than around the whole list.
      const file = await readPackJson(appId, p.path, 'pack.json').catch(() => null);
      const icons =
        file?.data && typeof file.data === 'object'
          ? ((file.data as { icons?: Record<string, string> }).icons ?? {})
          : {};
      const files = Object.values(icons).filter((f) => typeof f === 'string');

      return {
        packId: p.packId,
        title: p.title || p.packId,
        packType: p.packType,
        version: p.version,
        sizeBytes: p.sizeBytes,
        sku: p.sku ?? null,
        listed: isListed(listing, p.packId),
        distro,
        // Nine fills a 3x3 grid. More would be a contact sheet nobody reads at
        // card size, and every extra one is a request the browser makes.
        sampleUrls: files.slice(0, 9).map((f) => `${cdnBase()}/${appId}/${p.path}/${f}`),
        iconCount: files.length,
      };
    }),
  );

  cards.sort((a, b) => a.title.localeCompare(b.title));

  return (
    <Shell app={appId} subtitle={`cdn.mindberzerk.com / ${appId}`}>
      <Breadcrumb
        items={[{ label: appName(appId), href: `/apps/${appId}/packs` }, { label: 'Icons' }]}
      />

      {live.unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so nothing published is listed here.{' '}
          {live.unreachable}
        </Banner>
      )}

      {/* Kept from the old page because it is the least obvious rule in the
          whole delivery path. The disk cache is keyed by pack id and not by
          version, so republishing at the same number changes the bytes in the
          bucket and nothing on any phone. */}
      <p className="mb-3 text-micro leading-relaxed text-ink-3">
        A pack only reaches devices when its version increases. The device cache
        is keyed by pack id, not version, so republishing the same number is a
        no-op on a phone even though the panel shows the new bytes.
      </p>

      <PageHead
        title="Icon packs"
        meta={`${cards.length} · ${cards.filter((c) => c.distro).length} in a distro`}
        actions={
          <Button href={`/apps/${appId}/icons/builder`} variant="primary">
            New icon pack
          </Button>
        }
      />

      {cards.length === 0 ? (
        <p className="rounded-card border border-dashed border-line px-4 py-8 text-center text-data text-ink-3">
          {live.unreachable
            ? 'Nothing can be listed while the bucket is unreadable.'
            : 'No icon packs published yet.'}
        </p>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {cards.map((c) => (
            <IconPackCardView key={c.packId} app={appId} card={c} />
          ))}
        </div>
      )}

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A pack in a distro is granted by that distro&apos;s product and usually
        also sold on its own, so it carries both. A standalone pack has only its
        own product ID. Bundled packs ship inside the APK and are always
        available.
      </p>
    </Shell>
  );
}

function IconPackCardView({ app, card }: { app: AppId; card: IconPackCard }) {
  return (
    <section className="flex flex-col overflow-hidden rounded-card border border-line-soft bg-surface-1">
      {/* THE ART, FIRST. Nine real icons off the CDN on the theme-neutral page
          surface, so what you are judging is the artwork rather than a plate
          the renderer will apply later.

          `unoptimized` is not available here because these are plain <img>
          rather than next/image, and that is deliberate: next/image would
          proxy every icon through the server, which for a 3.5MB brand pack is
          the panel re-serving a CDN that exists precisely so it does not have
          to. */}
      <div className="border-b border-line-soft bg-surface-0 p-4">
        {card.sampleUrls.length === 0 ? (
          <div className="flex h-[136px] items-center justify-center rounded-lg border border-dashed border-line text-center text-micro leading-relaxed text-ink-3">
            no pack.json to preview
          </div>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            {card.sampleUrls.map((u) => (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                key={u}
                src={u}
                alt=""
                loading="lazy"
                className="aspect-square w-full rounded-lg object-contain"
              />
            ))}
          </div>
        )}
      </div>

      <div className="flex flex-1 flex-col p-3">
        <div className="flex items-baseline justify-between gap-2">
          <span className="truncate text-data font-medium text-ink">{card.title}</span>
          <span className="shrink-0 font-mono text-micro text-ink-3">v{card.version}</span>
        </div>
        <div className="truncate font-mono text-micro text-ink-3">{card.packId}</div>

        <div className="mt-2 flex flex-wrap gap-1">
          <Chip>{card.packType}</Chip>
          {card.distro ? (
            <Chip tone="info">in {card.distro.replace(/-theme$/, '')}</Chip>
          ) : (
            <Chip>standalone</Chip>
          )}
          {card.sku ? <Chip tone="accent">{card.sku}</Chip> : <Chip tone="ok">free</Chip>}
        </div>

        <div className="mt-2 text-micro text-ink-3">
          <span className="text-ink-2">
            {card.iconCount} {card.iconCount === 1 ? 'icon' : 'icons'}
          </span>
          {/* Under 8KB means a pack.json and essentially no art beside it: the
              yaru case, where a theme naming it gets the generator for every
              app and reports no error anywhere. */}
          {card.sizeBytes < 8192 && (
            <span className="ml-2 text-warn">almost no art</span>
          )}
        </div>

        <div className="mt-auto flex items-center justify-between gap-2 pt-3">
          <ListToggle app={app} packId={card.packId} initial={card.listed} />
          <Button href={`/apps/${app}/icons/builder?id=${card.packId}`}>Edit</Button>
        </div>
      </div>
    </section>
  );
}
