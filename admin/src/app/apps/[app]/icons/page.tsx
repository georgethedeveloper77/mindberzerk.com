import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SoftButton } from '@/components/studio/ui';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { bytes } from '@/app/components/ui';
import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { cdnUrl } from '@/lib/core/cdn';
import { isListed, readListingResult } from '@/lib/core/listing';
import { readPackJson } from '@/lib/core/pack-content';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { importTheme } from '@/lib/g-launcher/theme-spec';
import { readIconDraftsSafe } from '@/lib/g-launcher/icon-drafts';
import { readAllDraftsSafe } from '@/lib/g-launcher/themes';

export const dynamic = 'force-dynamic';

/**
 * ICONS - the inventory, matching Distros.
 *
 * ─── ROWS AND ONE INSPECTOR, BUT A DIFFERENT THUMBNAIL RULE ─────────────────
 *
 * A distro is identified by its wallpaper; a pack has no wallpaper, it IS its
 * art. So the row carries a mosaic of the pack's own icons and the inspector
 * shows twelve, which is enough to catch the failures that matter (wrong crop,
 * accidental opacity, a set that is really one icon repeated) without becoming
 * a contact sheet nobody reads.
 *
 * ─── TWO PACK SHAPES, AND AN EARLIER VERSION UNDERSTOOD ONE ─────────────────
 *
 * `HeroIconResolver` reads `icons` as packageName -> FILENAME. A brand pack
 * reads it as packageName -> { d: <24x24 path> }: CC0 glyphs shipped as path
 * data, which is the whole reason 3,449 icons fit in a few MB.
 *
 * Keeping only string values made every brand pack resolve to zero icons and
 * render as "no pack.json to preview" with a count of 0. That is
 * `simple-icons`, the only brand pack there is, and the one that ships inside
 * the APK. It looked broken and was not.
 *
 * So both shapes are read. Files become <img> against the public CDN, the same
 * bytes a phone downloads. Paths become inline SVG at viewBox 24, drawn on the
 * server with no renderer to build and no request to make.
 *
 * ─── USED BY, WHICH NOTHING COULD ANSWER BEFORE ─────────────────────────────
 *
 * A pack is referenced by `icons.heroPack` or `icons.brandPack` inside a
 * THEME's spec, not by anything in the index, so "is anything still using this"
 * needs a reverse lookup across every draft and every published theme.json. It
 * is the question you have to answer before unpublishing. Entitlement-derived
 * grants stay separate: a grant says who PAYS for a pack, this says who USES
 * it, and they disagree more often than you would expect.
 */

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
function artFrom(data: unknown, base: (name: string) => string): { art: Art[]; count: number } {
  if (!data || typeof data !== 'object') return { art: [], count: 0 };
  const icons = (data as { icons?: Record<string, unknown> }).icons;
  if (!icons || typeof icons !== 'object') return { art: [], count: 0 };

  const art: Art[] = [];
  let count = 0;
  for (const value of Object.values(icons)) {
    if (typeof value === 'string') {
      count++;
      if (art.length < 12) art.push({ kind: 'file', url: base(value) });
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

  // `readListingResult`, NOT `readListing`. An unreadable bucket collapses to
  // an empty map, and an empty map reads as "everything is listed", so a
  // refused credential rendered as a screen of confident toggles.
  const [live, listingResult, draftsResult, iconDrafts] = await Promise.all([
    readLiveIndex(appId),
    readListingResult(appId),
    readAllDraftsSafe(appId),
    // Unfinished packs. A draft you cannot find again is not a draft, so they
    // list here beside the published ones rather than only at a URL you have
    // to remember.
    readIconDraftsSafe(appId),
  ]);
  const listing = listingResult.listing;

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
      // `cdnUrl` from lib/core/cdn, not a second copy of the env fallback here.
      // That module also carries the reasoning for why the public door is the one
      // that still works while the S3 token is refused.
      const { art, count } = artFrom(file?.data, (name) => cdnUrl(appId, p.path, name));

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

  const matches = (c: (typeof cards)[number], f: FilterName) => {
    switch (f) {
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
  };

  const shown = cards.filter((c) => matches(c, active));
  const selected = shown.find((c) => c.packId === sel) ?? shown[0] ?? null;

  const meta = appMeta(appId);
  const href = (id: string) =>
    `/apps/${appId}/icons?${active === 'all' ? '' : `filter=${encodeURIComponent(active)}&`}sel=${id}#detail`;

  return (
    <StudioShell app={appId}>
      {listingResult.unreachable && !live.unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The listing flags could not be read, so every pack below is shown as listed whether it is
          or not. {listingResult.unreachable}
        </p>
      )}

      {live.unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so nothing published is listed here. {live.unreachable}
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(appId)}
        title="Icon packs"
        actions={
          <SlabButton href={`/apps/${appId}/icons/builder`} primary>
            New icon pack
          </SlabButton>
        }
      />

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const n = cards.filter((c) => matches(c, f)).length;
          const on = active === f;
          return (
            <Link
              key={f}
              href={`/apps/${appId}/icons${f === 'all' ? '' : `?filter=${encodeURIComponent(f)}`}`}
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

      {iconDrafts.drafts.length > 0 && (
        <section className="overflow-hidden rounded-[18px] border border-dashed border-site-line bg-site-card shadow-site-soft">
          <header className="flex items-center gap-3 px-[18px] py-3.5">
            <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-info-soft text-site-info">
              <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                <path d="M11.3 2.9l1.8 1.8L5.8 12H4v-1.8l7.3-7.3z" />
              </svg>
            </span>
            <h2 className="font-site-display text-[15px] font-bold text-site-ink">Drafts</h2>
            <span className="text-[11.5px] text-site-ink-3">not published, visible only here</span>
          </header>
          {iconDrafts.drafts.map((d) => (
            <Link
              key={d.packId}
              href={`/apps/${appId}/icons/builder?id=${d.packId}`}
              className="flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition hover:bg-site-sunk"
            >
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                  {d.name || d.packId}
                </span>
                <span className="mt-0.5 block truncate font-mono text-[11px] text-site-ink-3">
                  {d.packId} {'\u00b7'} {d.icons.filter((i) => i.pkg).length} mapped of{' '}
                  {d.icons.length}
                </span>
              </span>
              <span className="shrink-0 rounded-full bg-site-info-soft px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] text-site-info">
                draft
              </span>
              <span className="w-[86px] shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                {new Date(d.updatedAt * 1000).toISOString().slice(0, 10)}
              </span>
            </Link>
          ))}
        </section>
      )}

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_306px]">
        <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
          {shown.length === 0 ? (
            <div className="px-[18px] py-10 text-center">
              <p className="text-[13px] text-site-ink-3">
                {live.unreachable
                  ? 'Nothing can be listed while the bucket is unreadable.'
                  : active === 'all'
                    ? 'No icon packs published yet.'
                    : `No ${active} packs.`}
              </p>
              <div className="mt-3 flex justify-center">
                {active === 'all' ? (
                  <SoftButton href={`/apps/${appId}/icons/builder`}>New icon pack</SoftButton>
                ) : (
                  <SoftButton href={`/apps/${appId}/icons`}>Show all</SoftButton>
                )}
              </div>
            </div>
          ) : (
            shown.map((c) => {
              const on = selected?.packId === c.packId;
              return (
                <Link
                  key={c.packId}
                  href={href(c.packId)}
                  className={`relative flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition first:border-t-0 ${
                    on ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'
                  }`}
                >
                  {on && <span aria-hidden className="absolute inset-y-0 left-0 w-[3px] bg-site-accent" />}
                  <Mosaic art={c.art} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                      {c.title}
                    </span>
                    <span className="mt-0.5 block truncate font-mono text-[11px] text-site-ink-3">
                      {c.packId} {'\u00b7'} {c.packType} {'\u00b7'} v{c.version}
                    </span>
                  </span>
                  <span
                    className={`shrink-0 rounded-full px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] ${
                      c.count === 0 ? 'bg-site-plan-soft text-site-plan' : 'bg-site-ok-soft text-site-ok'
                    }`}
                  >
                    {c.count === 0 ? 'no art' : c.distro ? 'in a distro' : 'standalone'}
                  </span>
                  <span className="w-[86px] shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                    {c.count.toLocaleString()} {c.count === 1 ? 'icon' : 'icons'}
                  </span>
                </Link>
              );
            })
          )}
        </section>

        {selected && (
          <aside
            id="detail"
            className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4"
          >
            <div className="border-b border-site-line bg-site-sunk p-3.5">
              {selected.art.length === 0 ? (
                <div className="flex h-[120px] items-center justify-center rounded-xl border border-dashed border-site-line px-3 text-center text-[11.5px] leading-relaxed text-site-ink-3">
                  pack.json could not be read, or names no art
                </div>
              ) : (
                <div className="grid grid-cols-4 gap-2 text-site-ink-2">
                  {selected.art.map((a, i) => (
                    <span key={i} className="rounded-lg bg-site-card p-1.5">
                      <Glyph art={a} size={34} />
                    </span>
                  ))}
                </div>
              )}
              <div className="mt-2.5 text-center font-mono text-[11px] text-site-ink-3">
                {selected.count > selected.art.length
                  ? `first ${selected.art.length} of ${selected.count.toLocaleString()}`
                  : `${selected.count} ${selected.count === 1 ? 'icon' : 'icons'}`}
              </div>
            </div>

            <div className="px-4 pb-4 pt-3.5">
              <div className="truncate font-site-display text-[15px] font-bold text-site-ink">
                {selected.title}
              </div>
              <div className="truncate font-mono text-[11px] text-site-ink-3">{selected.packId}</div>

              <div className="mt-3 border-t border-site-line">
                <KVRow k="type" v={<span className="font-mono">{selected.packType}</span>} />
                <KVRow k="version" v={<span className="font-mono">v{selected.version}</span>} />
                <KVRow k="product" v={<span className="font-mono">{selected.sku ?? 'free'}</span>} />
                <KVRow
                  k="granted by"
                  v={<span className="font-mono">{selected.distro ?? 'standalone'}</span>}
                />
                <KVRow
                  k="used by"
                  v={
                    <span className="font-mono">
                      {selected.used.length === 0 ? 'nothing' : selected.used.join(', ')}
                    </span>
                  }
                />
                <KVRow k="size" v={<span className="font-mono">{bytes(selected.sizeBytes)}</span>} />
              </div>

              {selected.used.length === 0 && (
                <p className="mt-3 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-plan">
                  No theme names this pack in icons.heroPack or icons.brandPack, so nothing on a
                  device would load it.
                </p>
              )}

              {/* Under 8KB means a pack.json and essentially no art beside it:
                  the yaru case, where a theme naming it gets the generator for
                  every app and reports no error anywhere. */}
              {selected.sizeBytes < 8192 && selected.packType !== 'brand' && (
                <p className="mt-2 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-plan">
                  Under 8KB, so this is a pack.json with almost no art beside it. A theme naming it
                  falls back to the generated icons silently.
                </p>
              )}

              <div className="mt-3 flex items-center justify-between gap-3 border-t border-site-line pt-3">
                <span className="text-[12px] text-site-ink-3">
                  {selected.listed ? 'listed on device' : 'hidden'}
                </span>
                <ListToggle app={appId} packId={selected.packId} initial={selected.listed} />
              </div>

              <div className="mt-3 border-t border-site-line pt-3">
                <SoftButton href={`/apps/${appId}/icons/builder?id=${selected.packId}`}>Edit</SoftButton>
              </div>

              {/* Unpublish is NOT duplicated here. It lives on CDN objects
                  beside the manifest and the file list, which is the context in
                  which pulling a pack from every device is a decision rather
                  than a button. */}
              <p className="mt-3 text-[11px] leading-relaxed text-site-ink-3">
                To pull this from every device, use Unpublish on CDN objects.
              </p>
            </div>
          </aside>
        )}
      </div>

      {/* The least obvious rule in the whole delivery path: the disk cache is
          keyed by pack id and not by version, so republishing at the same
          number changes the bytes in the bucket and nothing on any phone. */}
      <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
        A pack only reaches devices when its version increases. The device cache is keyed by pack
        id, not version, so republishing the same number is a no-op on a phone even though the panel
        shows the new bytes.
      </p>
    </StudioShell>
  );
}

/**
 * Four of the pack's own icons, which is what identifies it at row size.
 *
 * Larger than the old 26px, to match the wallpaper swatch on Distros: at that
 * size a two-by-two of icons was four smudges. Empty cells render as sunk
 * squares rather than collapsing, so a pack with one icon still reads as a
 * pack with one icon.
 */
function Mosaic({ art }: { art: Art[] }) {
  const four = art.slice(0, 4);
  return (
    <span className="grid size-[38px] shrink-0 grid-cols-2 gap-[3px] rounded-lg bg-site-sunk p-[3px] text-site-ink-2">
      {[0, 1, 2, 3].map((i) =>
        four[i] ? (
          <Glyph key={i} art={four[i]} size={15} />
        ) : (
          <span key={i} className="block rounded-[3px] bg-site-line" />
        ),
      )}
    </span>
  );
}
