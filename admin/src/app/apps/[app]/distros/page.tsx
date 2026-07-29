import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, Button, Chip, PageHead, type Tone } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { DeleteDistro } from '@/components/theme-list/DeleteDistro';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { ThemePreview } from '@/components/theme-builder/ThemePreview';
import { APPS, readLiveIndex, type AppId } from '@/lib/catalogue';
import { isListed, readListing } from '@/lib/listing';
import { readPackJson } from '@/lib/pack-content';
import { appName } from '@/lib/registry';
import { importTheme, type ThemeSpecJson } from '@/lib/theme-spec';
import { distroIconPackIds, ensureSeededSafe, mergeThemeRows } from '@/lib/themes';

export const dynamic = 'force-dynamic';

/**
 * DISTROS — the inventory, and the only one.
 *
 * This replaces the `/themes` table. A theme and a distro were always the same
 * artifact: a distro is a theme pack, plus an optional icon pack, plus optional
 * SKUs. Two lists and two builders for one thing meant two places for the schema
 * to drift and two answers to "where is Ubuntu".
 *
 * ─── CARDS, NOT ROWS, AND THE PREVIEW IS THE REASON ─────────────────────────
 *
 * A table row can tell you a distro's id, version and price. It cannot tell you
 * whether it LOOKS like Kali, and that is the only question worth asking about
 * a distro at a glance. `ThemePreview` already renders the desktop from the
 * palette and layout — it is the same component the workspace shows while you
 * type — so every card gets a real preview with nothing to upload, nothing to
 * screenshot, and nothing that can go stale against the theme it depicts.
 *
 * That is the same call `theme_catalog.dart` made in the app: no screenshots,
 * render the thing.
 *
 * ─── BUNDLED AND CDN DISTROS SHARE ONE GRID ─────────────────────────────────
 *
 * A judgement call. They behave differently — the bundled three ship inside the
 * APK, cannot be unpublished, and have no price — so separating them is
 * defensible. But "where is Ubuntu" having two possible answers is exactly the
 * problem this page exists to remove, and a chip says everything the separation
 * would have said. Bundled sort first, because they are the floor everything
 * else falls back to.
 */

function tagTone(tag: string): Tone {
  if (tag === 'Paid') return 'accent';
  if (tag === 'Bundled') return 'info';
  if (tag.startsWith('Live')) return 'ok';
  if (tag === 'Draft ahead' || tag.startsWith('Seed')) return 'warn';
  return 'plain';
}

export default async function DistrosPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  // `ensureSeededSafe`, not `ensureSeeded`. The plain one reads and then WRITES
  // through `readMap`, which throws by design so a failed read can never become
  // the merge base for a write that wipes every draft. Correct for the writer,
  // fatal for a page: it took this whole screen into the error boundary the
  // first time the credential was refused.
  const [seeded, live, listing] = await Promise.all([
    ensureSeededSafe(appId),
    readLiveIndex(appId),
    readListing(appId),
  ]);
  const { drafts, unreachable: draftsUnreachable } = seeded;
  const rows = mergeThemeRows(drafts, live);

  const draftSpecs = new Map(drafts.map((d) => [d.id, d.spec]));

  // A theme published out-of-band has no local draft, so its spec has to come
  // out of the pack itself. One GET per such distro, on a page with a handful
  // of them, in exchange for every card having a real preview instead of a grey
  // rectangle. Failures resolve to null and the card renders without one.
  const fetched = await Promise.all(
    rows
      .filter((r) => !draftSpecs.has(r.id))
      .map(async (r) => {
        const pack = live.packs.find((p) => p.packId === r.id);
        if (!pack) return [r.id, null] as const;
        const file = await readPackJson(appId, pack.path, 'theme.json').catch(() => null);
        if (!file?.data) return [r.id, null] as const;
        const imported = importTheme(file.data);
        return [r.id, 'error' in imported ? null : imported.spec] as const;
      }),
  );
  for (const [id, spec] of fetched) if (spec) draftSpecs.set(id, spec);

  const sorted = [...rows].sort((a, b) => {
    if (a.bundled !== b.bundled) return a.bundled ? -1 : 1;
    return (a.title || a.id).localeCompare(b.title || b.id);
  });

  return (
    <Shell app={appId}>
      <Breadcrumb items={[{ label: appName(appId), href: `/apps/${appId}/packs` }, { label: 'Distros' }]} />

      {(live.unreachable || draftsUnreachable) && (
        <Banner tone="bad">
          The bucket could not be read, so this is the three distros compiled
          into the panel rather than what is published. Nothing here reflects
          the CDN, and edits cannot be saved.{' '}
          {live.unreachable ?? draftsUnreachable}
        </Banner>
      )}

      <PageHead
        title="Distros"
        meta={`${sorted.length} · ${sorted.filter((r) => r.bundled).length} bundled`}
        actions={
          <Button href={`/apps/${appId}/distros/builder`} variant="primary">
            New distro
          </Button>
        }
      />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {sorted.map((r) => {
          // `distroIconPackIds` is the same helper the delete action reads, so
          // the count on the card and what a delete would pull cannot drift.
          // The card shows present and pending together, because the bundle
          // advertises a granted pack whether or not it has shipped; a delete
          // only pulls the present ones.
          const icons = distroIconPackIds(live, r.id);
          return (
            <DistroCard
              key={r.id}
              app={appId}
              id={r.id}
              title={r.title}
              summary={r.summary}
              sku={r.sku}
              bundled={r.bundled}
              tags={r.tags}
              version={r.publishedVersion ?? r.draftVersion}
              published={r.publishedVersion != null}
              listed={isListed(listing, r.id)}
              spec={draftSpecs.get(r.id) ?? null}
              iconPacks={[...icons.present, ...icons.pending]}
              liveIconPacks={icons.present}
            />
          );
        })}
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A distro is a theme pack plus an optional icon pack. Product ID is the
        Play SKU; blank is free. Listed is the storefront switch, and bundled
        distros ship inside the APK so they are always available. To pull a live
        CDN pack from every device, use Unpublish on the Packs screen.
      </p>
    </Shell>
  );
}

function DistroCard({
  app,
  id,
  title,
  summary,
  sku,
  bundled,
  tags,
  version,
  published,
  listed,
  spec,
  iconPacks,
  liveIconPacks,
}: {
  app: AppId;
  id: string;
  title: string;
  summary: string;
  sku: string | null;
  bundled: boolean;
  tags: string[];
  version: number | null;
  published: boolean;
  listed: boolean;
  spec: ThemeSpecJson | null;
  iconPacks: string[];
  /** The subset of [iconPacks] actually in the live index; what a delete pulls. */
  liveIconPacks: string[];
}) {
  return (
    <section className="flex flex-col overflow-hidden rounded-card border border-line-soft bg-surface-1">
      {/* ── THE PREVIEW LEADS ──────────────────────────────────────────────
          It was a 100px strip down the side of a text block, which is the
          wrong emphasis for this page: the only question you open a distro
          gallery to answer is what the thing LOOKS like, and at that size the
          phone was clipped at the bezel and the dock fell off the bottom.

          Full width, on its own stage, at a size where the dock, the top bar
          and the gradient are all legible. The text below is the caption to
          it rather than the other way round.

          THE CLIP BOX IS SIZED FROM ThemePreview'S OWN GEOMETRY: a 232x480
          phone inside 7px of padding is 246x494, times the scale. It is a
          literal because the component's dimensions are literals; if those
          change, this crops and the fix is here. That is the cost of scaling
          a fixed-size component rather than parameterising it, and it is
          still cheaper than two previews drifting apart.

          The caption ThemePreview draws underneath is deliberately cropped
          out: it repeats the shell and name that the card already shows. */}
      <div className="flex justify-center border-b border-line-soft bg-surface-0 py-4">
        {spec ? (
          <div className="h-[296px] w-[148px] overflow-hidden">
            {/* THE INNER WIDTH IS EXPLICIT, and leaving it out was the bug.
                `transform: scale` happens at PAINT time, after layout. So the
                unscaled ThemePreview was laid out inside a 148px box first, and
                its outer flex column centres its children: a 246px phone
                centred in 148px starts at -49px and loses its left edge. That
                is the clipping in the cards — Ubuntu's dock and the terminal's
                first character were cut off, and the space that should have
                held them sat empty on the right.

                Giving the wrapper the component's real 246px lets it lay out at
                full size and only then shrink. 246 x 0.6 = 147.6, which is what
                the 148px clip box is derived from; change one and the other
                follows. */}
            <div className="w-[246px] origin-top-left scale-[0.6]">
              <ThemePreview spec={spec} />
            </div>
          </div>
        ) : (
          <div className="flex h-[296px] w-[148px] items-center justify-center rounded-lg border border-dashed border-line px-3 text-center text-micro leading-relaxed text-ink-3">
            no theme.json to preview
          </div>
        )}
      </div>

      <div className="flex flex-1 flex-col p-3">
        <div className="flex items-baseline justify-between gap-2">
          <span className="truncate text-data font-medium text-ink">{title || id}</span>
          {version != null && (
            <span className="shrink-0 font-mono text-micro text-ink-3">v{version}</span>
          )}
        </div>
        <div className="truncate font-mono text-micro text-ink-3">{id}</div>
        {summary && <div className="mt-1 truncate text-micro text-ink-2">{summary}</div>}

        <div className="mt-2 flex flex-wrap gap-1">
          {tags.map((t) => (
            <Chip key={t} tone={tagTone(t)}>
              {t}
            </Chip>
          ))}
        </div>

        <div className="mt-2 text-micro text-ink-3">
          <span className="text-ink-2">
            {iconPacks.length === 0
              ? 'no icon pack'
              : `${iconPacks.length} icon pack${iconPacks.length === 1 ? '' : 's'}`}
          </span>
          <span className="ml-2 font-mono">{sku ?? 'free'}</span>
        </div>
        {iconPacks.length > 0 && (
          <div className="truncate font-mono text-micro text-ink-3">
            {iconPacks.join(', ')}
          </div>
        )}

        {/* flex-wrap so the delete confirm text can take a full line of its
            own instead of crushing the toggle. Bundled distros get no delete
            at all: their packs ship in the APK and the unpublish layer refuses
            their ids, so a disabled button would promise something the server
            never allows. */}
        <div className="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
          <ListToggle app={app} packId={id} initial={listed} disabled={bundled} />
          <div className="flex items-center gap-3">
            {!bundled && (
              <DeleteDistro
                app={app}
                id={id}
                published={published}
                sku={sku}
                iconPacks={liveIconPacks}
              />
            )}
            <Button href={`/apps/${app}/distros/builder?id=${id}`}>Edit</Button>
          </div>
        </div>
      </div>
    </section>
  );
}
