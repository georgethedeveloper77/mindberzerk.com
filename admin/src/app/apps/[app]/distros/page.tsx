import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import {
  Banner,
  Button,
  Chip,
  Empty,
  Filter,
  Inspector,
  KV,
  PageHead,
  Row,
  Rows,
  Swatch,
  Toolbar,
  hexColor,
} from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { DeleteDistro } from '@/components/theme-list/DeleteDistro';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { ThemePreview } from '@/components/theme-builder/ThemePreview';
import { APPS, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { isListed, readListing } from '@/lib/core/listing';
import { readPackJson } from '@/lib/core/pack-content';
import { appName } from '@/lib/core/registry';
import { importTheme, type ThemeSpecJson } from '@/lib/g-launcher/theme-spec';
import { distroIconPackIds, ensureSeededSafe, mergeThemeRows } from '@/lib/g-launcher/themes';

export const dynamic = 'force-dynamic';

/**
 * DISTROS - the inventory, and the only one.
 *
 * This replaces the `/themes` table. A theme and a distro were always the same
 * artifact: a distro is a theme pack, plus an optional icon pack, plus optional
 * SKUs. Two lists and two builders for one thing meant two places for the schema
 * to drift and two answers to "where is Ubuntu".
 *
 * ─── ROWS AND ONE INSPECTOR, NOT A GRID OF PREVIEWS ─────────────────────────
 *
 * The previous pass gave every distro a full phone preview on the grounds that
 * the only question worth asking is what a distro LOOKS like. Half right. It
 * cost about 300px of vertical space each, so four distros filled a laptop
 * screen, and the fields that actually differ between them - state, version,
 * price, whether anything is listed - ended up three lines apart inside
 * separate boxes, which is the worst possible shape for comparing them.
 *
 * So the preview renders ONCE, in the inspector, for the selected distro, at a
 * size worth looking at. The rows carry a gradient swatch instead, which is
 * what actually identifies a distro at 26px, plus one state chip and the price.
 * Ten distros now fit where four did, and the column reads down.
 *
 * ─── SELECTION IS A SEARCH PARAM ────────────────────────────────────────────
 *
 * `?sel=<packId>`, not React state, so this page stays a server component with
 * no JavaScript in the list, so selection survives the `router.refresh()` that
 * follows every delete and every listing toggle, and so a distro can be linked
 * to directly. An unknown or missing `sel` falls back to the first row rather
 * than rendering an empty panel, which is also what makes delete safe: the row
 * it pointed at is gone, and the fallback quietly takes over.
 *
 * ─── BUNDLED AND CDN DISTROS SHARE ONE LIST ─────────────────────────────────
 *
 * They behave differently, so separating them is defensible. But "where is
 * Ubuntu" having two possible answers is the problem this page exists to
 * remove, a chip says everything the separation would have said, and the filter
 * row covers the case where you genuinely want one kind. Bundled sort first,
 * because they are the floor everything else falls back to.
 */

const FILTERS = ['all', 'live', 'bundled', 'paid', 'unlisted'] as const;
type FilterName = (typeof FILTERS)[number];

function isFilter(v: string | undefined): v is FilterName {
  return !!v && (FILTERS as readonly string[]).includes(v);
}

export default async function DistrosPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ sel?: string; filter?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  const { sel, filter } = await searchParams;
  const active: FilterName = isFilter(filter) ? filter : 'all';

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

  const specs = new Map(drafts.map((d) => [d.id, d.spec]));

  // A theme published out-of-band has no local draft, so its spec has to come
  // out of the pack itself. One GET per such distro, on a page with a handful
  // of them. Failures resolve to null and the row falls back to a neutral
  // swatch rather than disappearing.
  const fetched = await Promise.all(
    rows
      .filter((r) => !specs.has(r.id))
      .map(async (r) => {
        const pack = live.packs.find((p) => p.packId === r.id);
        if (!pack) return [r.id, null] as const;
        const file = await readPackJson(appId, pack.path, 'theme.json').catch(() => null);
        if (!file?.data) return [r.id, null] as const;
        const imported = importTheme(file.data);
        return [r.id, 'error' in imported ? null : imported.spec] as const;
      }),
  );
  for (const [id, spec] of fetched) if (spec) specs.set(id, spec);

  const sorted = [...rows].sort((a, b) => {
    if (a.bundled !== b.bundled) return a.bundled ? -1 : 1;
    return (a.title || a.id).localeCompare(b.title || b.id);
  });

  const shown = sorted.filter((r) => {
    switch (active) {
      case 'live':
        return r.publishedVersion != null;
      case 'bundled':
        return r.bundled;
      case 'paid':
        return !!r.sku;
      case 'unlisted':
        return !isListed(listing, r.id) && !r.bundled;
      default:
        return true;
    }
  });

  // The fallback is load-bearing: after a delete, `sel` names a row that no
  // longer exists, and without this the inspector would render empty beside a
  // list that is fine.
  const selected = shown.find((r) => r.id === sel) ?? shown[0] ?? null;
  const selectedSpec = selected ? (specs.get(selected.id) ?? null) : null;
  const selectedIcons = selected ? distroIconPackIds(live, selected.id) : null;

  const href = (id: string) =>
    `/apps/${appId}/distros?${active === 'all' ? '' : `filter=${active}&`}sel=${id}#detail`;

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

      <Toolbar>
        {FILTERS.map((f) => (
          <Filter
            key={f}
            href={`/apps/${appId}/distros${f === 'all' ? '' : `?filter=${f}`}`}
            active={active === f}
          >
            {f}
          </Filter>
        ))}
      </Toolbar>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          {shown.length === 0 ? (
            <Empty
              action={
                active === 'all' ? (
                  <Button href={`/apps/${appId}/distros/builder`}>New distro</Button>
                ) : (
                  <Button href={`/apps/${appId}/distros`}>Show all</Button>
                )
              }
            >
              {active === 'all' ? 'No distros yet.' : `No ${active} distros.`}
            </Empty>
          ) : (
            <Rows>
              {shown.map((r) => {
                const p = specs.get(r.id)?.palette;
                return (
                  <Row
                    key={r.id}
                    href={href(r.id)}
                    selected={selected?.id === r.id}
                    thumb={
                      <Swatch
                        top={hexColor(p?.bgTop, 'var(--color-surface-2)')}
                        bottom={hexColor(p?.bgBottom, 'var(--color-surface-0)')}
                        accent={hexColor(p?.accent, 'var(--color-line)')}
                      />
                    }
                    title={r.title || r.id}
                    subtitle={`${r.id}${specs.get(r.id)?.shell ? ` · ${specs.get(r.id)!.shell}` : ''}`}
                    chip={<StateChip row={r} listed={isListed(listing, r.id)} />}
                    right={r.sku ?? 'free'}
                  />
                );
              })}
            </Rows>
          )}
        </div>

        {selected && (
          <Inspector>
            <div className="flex justify-center rounded-lg border border-line-soft bg-surface-0 py-3">
              {selectedSpec ? (
                /* THE CLIP BOX IS SIZED FROM ThemePreview'S OWN GEOMETRY: a
                   232x480 phone inside 7px of padding is 246x494, times the
                   scale. The inner width must be the component's REAL 246px,
                   because `transform: scale` happens at paint time, after
                   layout: laid out inside a narrow box first, its centring flex
                   column would start the phone at a negative offset and clip
                   the left edge. 246 x 0.62 = 152.5, which is where the clip
                   box below comes from; change one and change the other. */
                <div className="h-[306px] w-[152px] overflow-hidden">
                  <div className="w-[246px] origin-top-left scale-[0.62]">
                    <ThemePreview spec={selectedSpec} />
                  </div>
                </div>
              ) : (
                <div className="flex h-[306px] w-[152px] items-center justify-center px-3 text-center text-micro leading-relaxed text-ink-3">
                  no theme.json to preview
                </div>
              )}
            </div>

            <div className="mt-2.5 truncate text-data font-medium text-ink">
              {selected.title || selected.id}
            </div>
            <div className="truncate font-mono text-micro text-ink-3">{selected.id}</div>
            {selected.summary && (
              <div className="mt-0.5 truncate text-micro text-ink-2">{selected.summary}</div>
            )}

            <div className="mt-2.5 border-t border-line-soft pt-1">
              <KV k="shell" v={selectedSpec?.shell ?? '-'} />
              <KV
                k="version"
                v={
                  selected.publishedVersion != null
                    ? `v${selected.publishedVersion}`
                    : selected.draftVersion != null
                      ? `draft v${selected.draftVersion}`
                      : '-'
                }
              />
              <KV k="product" v={selected.sku ?? 'free'} />
              <KV
                k="icon packs"
                v={
                  selectedIcons && selectedIcons.present.length + selectedIcons.pending.length > 0
                    ? [...selectedIcons.present, ...selectedIcons.pending].join(', ')
                    : 'none'
                }
              />
            </div>

            <div className="mt-2 flex items-center justify-between gap-2 border-t border-line-soft pt-2.5">
              <span className="text-micro text-ink-3">
                {selected.bundled ? 'bundled' : isListed(listing, selected.id) ? 'listed' : 'hidden'}
              </span>
              <ListToggle
                app={appId}
                packId={selected.id}
                initial={isListed(listing, selected.id)}
                disabled={selected.bundled}
              />
            </div>

            <div className="mt-2.5 flex flex-wrap items-center gap-3 border-t border-line-soft pt-2.5">
              <Button href={`/apps/${appId}/distros/builder?id=${selected.id}`}>Edit</Button>
              {!selected.bundled && (
                <DeleteDistro
                  app={appId}
                  id={selected.id}
                  published={selected.publishedVersion != null}
                  sku={selected.sku}
                  iconPacks={selectedIcons?.present ?? []}
                />
              )}
            </div>

            {selected.bundled && (
              <p className="mt-2 text-micro leading-relaxed text-ink-3">
                Bundled distros ship inside the APK, so they are always available
                and cannot be delisted or deleted.
              </p>
            )}
          </Inspector>
        )}
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A distro is a theme pack plus an optional icon pack. Product ID is the
        Play SKU; blank is free. To pull a live CDN pack from every device, use
        Unpublish on the CDN objects screen.
      </p>
    </Shell>
  );
}

/**
 * ONE chip, not three.
 *
 * Cards carried Free, Bundled and Not published as separate chips, which is
 * three pieces of jewellery to say one thing. State is a single fact with a
 * precedence order, and price already has its own column on the right.
 */
function StateChip({
  row,
  listed,
}: {
  row: { bundled: boolean; publishedVersion: number | null; needsPublish: boolean };
  listed: boolean;
}) {
  if (row.bundled) return <Chip tone="info">bundled</Chip>;
  if (row.publishedVersion == null) return <Chip tone="warn">draft</Chip>;
  if (!listed) return <Chip tone="warn">unlisted</Chip>;
  if (row.needsPublish) return <Chip tone="warn">draft ahead</Chip>;
  return <Chip tone="ok">{`live v${row.publishedVersion}`}</Chip>;
}
