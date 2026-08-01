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
  Toolbar,
  bytes,
} from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { readLiveIndex, type AppId } from '@/lib/catalogue';
import { isListed, readListing } from '@/lib/listing';
import { readPackJson } from '@/lib/pack-content';
import { appName, isAppId } from '@/lib/registry';
import { importTheme } from '@/lib/theme-spec';
import { readAllDraftsSafe } from '@/lib/themes';

export const dynamic = 'force-dynamic';

/**
 * ICONS - the inventory, matching Distros.
 *
 * ─── ROWS AND ONE INSPECTOR ─────────────────────────────────────────────────
 *
 * Same shape as Distros, for the same reason, but the thumbnail rule changes.
 * A distro is identified at 26px by its gradient; a pack has no gradient, it IS
 * its art. So the row carries a four-cell mosaic of the pack's own icons and
 * the inspector shows twelve, which is enough to catch the failures that matter
 * (wrong crop, accidental opacity, a set that is really one icon repeated)
 * without becoming a contact sheet nobody reads.
 *
 * ─── TWO PACK SHAPES, AND THE OLD PAGE ONLY UNDERSTOOD ONE ──────────────────
 *
 * `HeroIconResolver` reads `icons` as packageName -> FILENAME. A brand pack
 * reads it as packageName -> { d: <24x24 path> }: CC0 glyphs shipped as path
 * data, which is the whole reason 3,449 icons fit in a few MB.
 *
 * The previous version kept only string values, so every brand pack resolved to
 * zero icons and rendered as "no pack.json to preview" with a count of 0. That
 * is `simple-icons`, the only brand pack there is, and the one pack that ships
 * inside the APK. It looked broken and was not.
 *
 * So both shapes are read. Files become <img> against the public CDN, the same
 * bytes a phone downloads. Paths become inline SVG at viewBox 24, drawn on the
 * server with no renderer to build and no request to make.
 *
 * ─── USED BY, WHICH NOTHING COULD ANSWER BEFORE ─────────────────────────────
 *
 * A pack is referenced by `icons.heroPack` or `icons.brandPack` inside a
 * THEME's spec, not by anything in the index, so "is anything still using this"
 * needed a reverse lookup across every draft and every published theme.json.
 * It is the question you have to answer before unpublishing, and the panel
 * could not answer it. Entitlement-derived grants stay separate: a grant says
 * who PAYS for the pack, this says who USES it, and they disagree more often
 * than you would expect.
 */

/** Where the bucket is served publicly. Not the S3 endpoint, which is signed. */
function cdnBase(): string {
  return (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
}

const FILTERS = ['all', 'hero', 'brand', 'in a distro', 'standalone'] as const;
type FilterName = (typeof FILTERS)[number];

const isFilter = (v: string | undefined): v is FilterName =>
  !!v && (FILTERS as readonly string[]).includes(v);

/** A drawable icon: either a CDN file or a 24x24 glyph path. */
type Art = { kind: 'file'; url: string } | { kind: 'path'; d: string };

/**
 * Pull drawable art out of a pack.json, whichever shape it is in.
 *
 * Deliberately tolerant: a pack whose map holds something this does not
 * recognise yields fewer icons rather than throwing, because a preview is not
 * worth taking a page down for.
 */
function artFrom(data: unknown, base: string): { art: Art[]; count: number } {
  if (!data || typeof data !== 'object') return { art: [], count: 0 };
  const icons = (data as { icons?: Record<string, unknown> }).icons;
  if (!icons || typeof icons !== 'object') return { art: [], count: 0 };

  const art: Art[] = [];
  let count = 0;
  for (const value of Object.values(icons)) {
    if (typeof value === 'string') {
      count++;
      if (art.length < 12) art.push({ kind: 'file', url: `${base}/${value}` });
    } else if (value && typeof value === 'object' && typeof (value as { d?: unknown }).d === 'string') {
      count++;
      if (art.length < 12) art.push({ kind: 'path', d: (value as { d: string }).d });
    }
  }
  return { art, count };
}

function Glyph({ art, size }: { art: Art; size: number }) {
  if (art.kind === 'file') {
    // Plain <img>, not next/image: next/image proxies every icon through the
    // server, which for a brand pack is the panel re-serving a CDN that exists
    // precisely so it does not have to.
    // eslint-disable-next-line @next/next/no-img-element
    return (
      <img
        src={art.url}
        alt=""
        loading="lazy"
        width={size}
        height={size}
        className="aspect-square w-full rounded object-contain"
      />
    );
  }
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} className="aspect-square w-full" aria-hidden="true">
      <path d={art.d} fill="currentColor" />
    </svg>
  );
}

export default async function IconsPage({
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
  const appId = app as AppId;

  const { sel, filter } = await searchParams;
  const active: FilterName = isFilter(filter) ? filter : 'all';

  const [live, listing, draftsResult] = await Promise.all([
    readLiveIndex(appId),
    readListing(appId),
    readAllDraftsSafe(appId),
  ]);

  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const packs = live.packs.filter((p) => iconTypes.has(p.packType));
  const themePacks = live.packs.filter((p) => p.packType === 'theme');

  // ── the reverse lookup: which themes name which pack ──────────────────────
  //
  // Drafts first, because they are already in memory and cover everything
  // authored here. Then the published theme.json of any theme with no draft,
  // which is the out-of-band case. One GET each, on a page with a handful.
  const usedBy = new Map<string, Set<string>>();
  const note = (packId: string | null | undefined, themeId: string) => {
    if (!packId) return;
    const set = usedBy.get(packId) ?? new Set<string>();
    set.add(themeId);
    usedBy.set(packId, set);
  };
  const draftIds = new Set(draftsResult.drafts.map((d) => d.id));
  for (const d of draftsResult.drafts) {
    note(d.spec.icons?.heroPack, d.id);
    note(d.spec.icons?.brandPack, d.id);
  }
  await Promise.all(
    themePacks
      .filter((t) => !draftIds.has(t.packId))
      .map(async (t) => {
        const file = await readPackJson(appId, t.path, 'theme.json').catch(() => null);
        if (!file?.data) return;
        const imported = importTheme(file.data);
        if ('error' in imported) return;
        note(imported.spec.icons?.heroPack, t.packId);
        note(imported.spec.icons?.brandPack, t.packId);
      }),
  );

  const cards = await Promise.all(
    packs.map(async (p) => {
      // The theme pack that GRANTS this one, which is a payment fact and not a
      // usage one. Kept separate from usedBy on purpose.
      const grant = live.entitlements.find((e) => e.grants.includes(p.packId));
      const distro =
        grant?.grants.find((g) => g !== p.packId && g.endsWith('-theme')) ??
        live.packs.find(
          (t) =>
            t.packType === 'theme' &&
            t.packId.replace(/-theme$/, '') === p.packId.replace(/-icons$/, ''),
        )?.packId ??
        null;

      // A failed read costs this pack its preview and nothing else, which is
      // why it is caught per pack rather than around the whole list.
      const file = await readPackJson(appId, p.path, 'pack.json').catch(() => null);
      const { art, count } = artFrom(file?.data, `${cdnBase()}/${appId}/${p.path}`);

      return {
        packId: p.packId,
        title: p.title || p.packId,
        packType: p.packType,
        version: p.version,
        sizeBytes: p.sizeBytes,
        sku: p.sku ?? null,
        listed: isListed(listing, p.packId),
        distro,
        art,
        count,
        used: [...(usedBy.get(p.packId) ?? [])].sort(),
      };
    }),
  );

  cards.sort((a, b) => a.title.localeCompare(b.title));

  const shown = cards.filter((c) => {
    switch (active) {
      case 'hero':
        return c.packType === 'hero' || c.packType === 'icon';
      case 'brand':
        return c.packType === 'brand';
      case 'in a distro':
        return !!c.distro;
      case 'standalone':
        return !c.distro;
      default:
        return true;
    }
  });

  const selected = shown.find((c) => c.packId === sel) ?? shown[0] ?? null;

  const href = (id: string) =>
    `/apps/${appId}/icons?${active === 'all' ? '' : `filter=${encodeURIComponent(active)}&`}sel=${id}#detail`;

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

      <PageHead
        title="Icon packs"
        meta={`${cards.length} · ${cards.filter((c) => c.distro).length} in a distro`}
        actions={
          <Button href={`/apps/${appId}/icons/builder`} variant="primary">
            New icon pack
          </Button>
        }
      />

      <Toolbar>
        {FILTERS.map((f) => (
          <Filter
            key={f}
            href={`/apps/${appId}/icons${f === 'all' ? '' : `?filter=${encodeURIComponent(f)}`}`}
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
                  <Button href={`/apps/${appId}/icons/builder`}>New icon pack</Button>
                ) : (
                  <Button href={`/apps/${appId}/icons`}>Show all</Button>
                )
              }
            >
              {live.unreachable
                ? 'Nothing can be listed while the bucket is unreadable.'
                : active === 'all'
                  ? 'No icon packs published yet.'
                  : `No ${active} packs.`}
            </Empty>
          ) : (
            <Rows>
              {shown.map((c) => (
                <Row
                  key={c.packId}
                  href={href(c.packId)}
                  selected={selected?.packId === c.packId}
                  thumb={<Mosaic art={c.art} />}
                  title={c.title}
                  subtitle={`${c.packId} · ${c.packType}`}
                  chip={
                    c.count === 0 ? (
                      <Chip tone="warn">no art</Chip>
                    ) : (
                      <Chip tone="ok">{`v${c.version}`}</Chip>
                    )
                  }
                  right={`${c.count} ${c.count === 1 ? 'icon' : 'icons'}`}
                />
              ))}
            </Rows>
          )}
        </div>

        {selected && (
          <Inspector>
            {selected.art.length === 0 ? (
              <div className="flex h-[120px] items-center justify-center rounded-lg border border-dashed border-line px-3 text-center text-micro leading-relaxed text-ink-3">
                pack.json could not be read, or names no art
              </div>
            ) : (
              <div className="grid grid-cols-4 gap-1.5 rounded-lg border border-line-soft bg-surface-0 p-2 text-ink-2">
                {selected.art.map((a, i) => (
                  <Glyph key={i} art={a} size={32} />
                ))}
              </div>
            )}
            <div className="mt-1 font-mono text-micro text-ink-3">
              {selected.count > selected.art.length
                ? `first ${selected.art.length} of ${selected.count}`
                : `${selected.count} ${selected.count === 1 ? 'icon' : 'icons'}`}
            </div>

            <div className="mt-2 truncate text-data font-medium text-ink">{selected.title}</div>
            <div className="truncate font-mono text-micro text-ink-3">{selected.packId}</div>

            <div className="mt-2.5 border-t border-line-soft pt-1">
              <KV k="type" v={selected.packType} />
              <KV k="version" v={`v${selected.version}`} />
              <KV k="product" v={selected.sku ?? 'free'} />
              <KV k="granted by" v={selected.distro ?? 'standalone'} />
              <KV
                k="used by"
                v={selected.used.length === 0 ? 'nothing' : selected.used.join(', ')}
              />
              <KV k="size" v={bytes(selected.sizeBytes)} />
            </div>

            {selected.used.length === 0 && (
              <p className="mt-2 text-micro leading-relaxed text-warn">
                No theme names this pack in icons.heroPack or icons.brandPack, so
                nothing on a device would load it.
              </p>
            )}
            {/* Under 8KB means a pack.json and essentially no art beside it: the
                yaru case, where a theme naming it gets the generator for every
                app and reports no error anywhere. */}
            {selected.sizeBytes < 8192 && selected.packType !== 'brand' && (
              <p className="mt-2 text-micro leading-relaxed text-warn">
                Under 8KB, so this is a pack.json with almost no art beside it. A
                theme naming it falls back to the generated icons silently.
              </p>
            )}

            <div className="mt-2 flex items-center justify-between gap-2 border-t border-line-soft pt-2.5">
              <span className="text-micro text-ink-3">
                {selected.listed ? 'listed' : 'hidden'}
              </span>
              <ListToggle app={appId} packId={selected.packId} initial={selected.listed} />
            </div>

            <div className="mt-2.5 border-t border-line-soft pt-2.5">
              <Button href={`/apps/${appId}/icons/builder?id=${selected.packId}`}>Edit</Button>
            </div>
            {/* Unpublish is NOT duplicated here. It lives on CDN objects beside
                the manifest and the file list, which is the context in which
                pulling a pack from every device is a decision rather than a
                button. */}
            <p className="mt-2 text-micro leading-relaxed text-ink-3">
              To pull this from every device, use Unpublish on CDN objects.
            </p>
          </Inspector>
        )}
      </div>

      {/* Kept from the old page because it is the least obvious rule in the
          whole delivery path. The disk cache is keyed by pack id and not by
          version, so republishing at the same number changes the bytes in the
          bucket and nothing on any phone. */}
      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A pack only reaches devices when its version increases. The device cache
        is keyed by pack id, not version, so republishing the same number is a
        no-op on a phone even though the panel shows the new bytes.
      </p>
    </Shell>
  );
}

/** Four of the pack's own icons, which is what identifies it at row size. */
function Mosaic({ art }: { art: Art[] }) {
  const four = art.slice(0, 4);
  return (
    <span className="grid h-[26px] w-[26px] shrink-0 grid-cols-2 gap-px text-ink-2">
      {[0, 1, 2, 3].map((i) =>
        four[i] ? (
          <Glyph key={i} art={four[i]} size={12} />
        ) : (
          <span key={i} className="block rounded-[2px] bg-surface-2" />
        ),
      )}
    </span>
  );
}
