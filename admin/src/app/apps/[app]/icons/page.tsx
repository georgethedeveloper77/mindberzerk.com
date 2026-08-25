import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SoftButton } from '@/components/studio/ui';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { DeleteIconPack } from '@/components/icon-list/DeleteIconPack';
import { BulkBar, BulkProvider, RowCheck } from '@/components/studio/bulk';
import { bulkDeleteIconPacksAction } from './actions';
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

/** Mirrors BUNDLED_PACK_IDS; these ship in the APK and cannot be pulled. */
const BULK_UNDELETABLE = new Set(['simple-icons', 'yaru']);

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

// `drafts` is second for the same reason it is on Distros: "what am I part-way
// through" is the question this screen is opened with more often than any
// question about kind.
const FILTERS = ['all', 'drafts', 'hero', 'brand', 'in a distro', 'standalone'] as const;
type FilterName = (typeof FILTERS)[number];

const isFilter = (v: string | undefined): v is FilterName =>
  !!v && (FILTERS as readonly string[]).includes(v);

/** A drawable icon: either a CDN file or a 24x24 glyph path. */
type Art =
  | { kind: 'file'; url: string }
  /**
   * Vector art, drawn inline.
   *
   * [viewBox] and [stroke] are carried per glyph rather than assumed, because
   * the two packs that produce path art disagree on both: Simple Icons is a
   * 24-unit FILLED mark, a line set is a 48-unit STROKED one. Hardcoding 24 and
   * `fill` drew every outline drawing at double size as a solid blob.
   *
   * [colour] is the distro's tint. A line set publishes no colour of its own,
   * which is the entire point: fourteen products share one geometry and differ
   * only here.
   */
  | { kind: 'path'; d: string; viewBox: number; stroke: boolean; colour: string | null };

/**
 * Pull drawable art out of a pack.json, whichever shape it is in.
 *
 * ─── THREE SHAPES NOW, AND THIS KNEW ONE AND A HALF ─────────────────────────
 *
 *   HERO      `icons: { "com.whatsapp": "whatsapp.png" }`
 *             The value is a FILE in the pack. Rendered as an <img>.
 *
 *   INLINE    `icons: { "com.whatsapp": { d: "M17...", hex: "25D366" } }`
 *             Simple Icons. A 24-unit filled mark, colour published per glyph.
 *
 *   LINE      `icons: { "com.whatsapp": "whatsapp" }` plus
 *             `glyphs: { "whatsapp": ["M24,2.5...", "M9,17..."] }`
 *             The value is a SLUG into `glyphs`, because 32,950 packages share
 *             13,622 drawings and inlining would triple the file.
 *
 * The third was read as the first: a slug was treated as a filename, so every
 * preview was a broken image and the count read 32,950 because that is how many
 * package entries there are. That is the "NO ART" on every official pack.
 *
 * Deliberately tolerant: an unrecognised entry yields fewer icons rather than
 * throwing, because a preview is not worth taking a page down for.
 */
function artFrom(
  data: unknown,
  base: (name: string) => string,
  /** The distro's colour, for a line set. Null leaves it to the glyph. */
  tint: string | null = null,
): { art: Art[]; count: number } {
  if (!data || typeof data !== 'object') return { art: [], count: 0 };
  const pack = data as {
    icons?: Record<string, unknown>;
    glyphs?: Record<string, unknown>;
    viewBox?: number;
    style?: string;
  };
  const icons = pack.icons;
  if (!icons || typeof icons !== 'object') return { art: [], count: 0 };

  const glyphs = pack.glyphs && typeof pack.glyphs === 'object' ? pack.glyphs : null;
  const viewBox = typeof pack.viewBox === 'number' && pack.viewBox > 0 ? pack.viewBox : 24;
  const stroke = pack.style === 'stroke';

  const art: Art[] = [];
  let count = 0;

  // COUNT IS DRAWINGS, NOT PACKAGE ENTRIES. A line set maps 32,950 packages
  // onto 13,622 drawings, and reporting the first is both wrong and flattering:
  // the pack does not contain 32,950 icons, it contains 13,622.
  if (glyphs) {
    for (const [slug, paths] of Object.entries(glyphs)) {
      count++;
      if (art.length >= 12) continue;
      const first = Array.isArray(paths) ? paths : [paths];
      const d = first.find((x) => typeof x === 'string' && x.length > 0);
      if (typeof d === 'string') art.push({ kind: 'path', d, viewBox, stroke, colour: tint });
      // `slug` is unused here on purpose: the preview shows the first twelve
      // drawings in file order, not a chosen set, so no lookup is needed.
      void slug;
    }
    return { art, count };
  }

  for (const value of Object.values(icons)) {
    if (typeof value === 'string') {
      count++;
      if (art.length < 12) art.push({ kind: 'file', url: base(value) });
    } else if (value && typeof value === 'object' && typeof (value as { d?: unknown }).d === 'string') {
      count++;
      if (art.length < 12) {
        const hex = (value as { hex?: unknown }).hex;
        art.push({
          kind: 'path',
          d: (value as { d: string }).d,
          viewBox,
          stroke,
          colour: typeof hex === 'string' && hex ? `#${hex.replace(/^#/, '')}` : tint,
        });
      }
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
  // The pack's OWN viewBox and fill rule. Both were hardcoded to Simple Icons'
  // 24-unit filled mark, so a 48-unit stroked drawing rendered at double scale
  // as a solid shape: recognisable as wrong, unrecognisable as which icon.
  const stroked = art.stroke;
  return (
    <svg
      viewBox={`0 0 ${art.viewBox} ${art.viewBox}`}
      width={size}
      height={size}
      className="aspect-square w-full"
      aria-hidden="true"
    >
      <path
        d={art.d}
        fill={stroked ? 'none' : (art.colour ?? 'currentColor')}
        stroke={stroked ? (art.colour ?? 'currentColor') : 'none'}
        // Arcticons and every set like it declare round caps and joins in
        // source. Android's defaults are butt and miter, and so are SVG's, so
        // without these the preview does not match what the device draws.
        strokeWidth={stroked ? 1 : undefined}
        strokeLinecap={stroked ? 'round' : undefined}
        strokeLinejoin={stroked ? 'round' : undefined}
      />
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
  /**
   * ─── THE SOURCE IS NOT A PRODUCT ──────────────────────────────────────────
   *
   * `arcticons-line` carries the 13,622 drawings all fourteen official packs
   * point at. It has no colour of its own and nobody would choose it, so listing
   * it puts a fifteenth row on the shelf that changes nothing when tapped.
   *
   * It is hidden from the LIST, not from the panel: it still has a page at
   * `?sel=arcticons-line`, because checking the drawings is a real thing to want
   * and it is the one pack whose preview is the whole library.
   *
   * Anything a pack `extends` is treated the same way, derived from the packs
   * themselves rather than named here, so a second source added later is hidden
   * for the same reason without anyone remembering to add it to a list.
   */
  const sources = new Set(
    live.packs
      .map((p) => (p as { requires?: string[] }).requires ?? [])
      .flat(),
  );
  const packs = live.packs.filter(
    (p) => iconTypes.has(p.packType) && (!sources.has(p.packId) || p.packId === sel),
  );
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

  const published = await Promise.all(
    packs.map(async (p) => {
      // The theme pack that GRANTS this one, which is a payment fact and not a
      // usage one. Kept separate from usedBy on purpose.
      const grant = live.entitlements.find((e) => e.grants.includes(p.packId));

      /**
       * ─── WHICH DISTRO THIS PACK BELONGS TO ───────────────────────────────
       *
       * Three ways, in order of how much they prove.
       *
       * Both of the first two assumed things that stopped being true:
       *
       *   - the entitlement lookup required a grant ending `-theme`, and the
       *     three BUNDLED distros are `kde-plasma-6`, `terminal` and
       *     `ubuntu-24-04`, with no suffix and no entitlement at all because
       *     they are free
       *   - the id fallback stripped `-icons`, and the official packs end
       *     `-line`
       *
       * So all three bundled distros' packs read STANDALONE while the eleven
       * paid ones read IN A DISTRO. The relationship was identical; only the
       * detection differed.
       *
       * The third way is the one that actually proves it and is checked FIRST:
       * a theme naming this pack in `brandPack` or `heroPack` is not an
       * inference at all. `usedBy` already holds that, computed from the
       * published theme.json a few lines above.
       */
      const distro =
        // Ground truth: a theme names it.
        // A SET, not an array: `[0]` on it is undefined, which would have made
        // this whole branch silently useless and sent every pack to the
        // fallbacks below.
        [...(usedBy.get(p.packId) ?? [])][0] ??
        // Or an entitlement grants it alongside a theme pack. Matched against
        // real theme ids rather than a suffix, so a bundled distro counts.
        grant?.grants.find(
          (g) => g !== p.packId && themePacks.some((t) => t.packId === g),
        ) ??
        // Or the ids line up. Both suffixes, because hand-built packs end
        // `-icons` and the official ones end `-line`.
        live.packs.find(
          (t) =>
            t.packType === 'theme' &&
            t.packId.replace(/-theme$/, '') === p.packId.replace(/-(icons|line)$/, ''),
        )?.packId ??
        null;

      // A failed read costs this pack its preview and nothing else, which is
      // why it is caught per pack rather than around the whole list.
      const file = await readPackJson(appId, p.path, 'pack.json').catch(() => null);

      /**
       * ─── FOLLOW `extends`, THE WAY THE DEVICE DOES ────────────────────────
       *
       * An official pack is 207 bytes: a colour and a pointer at
       * `arcticons-line`, which carries all 13,622 drawings. It has no art of
       * its own, so reading its own file honestly reported NO ART and 0 icons
       * on all fourteen. The packs were correct; the panel was looking in the
       * wrong file.
       *
       * `BrandIconResolver` already does exactly this on device: sees
       * `extends`, loads that pack's geometry, stamps `tint` on every glyph.
       * This is the same two steps, so what the panel shows is what the phone
       * draws rather than a second guess at it.
       *
       * ONE FETCH PER PACK and they run inside the same `Promise.all` as
       * everything else, so fourteen resolutions are fourteen parallel reads of
       * a file the CDN edge is already holding, not fourteen round trips in
       * series.
       */
      const ext = (file?.data as { extends?: unknown; tint?: unknown } | undefined) ?? {};
      const extendsId = typeof ext.extends === 'string' ? ext.extends : null;
      const tint = typeof ext.tint === 'string' ? ext.tint : null;

      let source = file?.data;
      let sourcePath = p.path;
      if (extendsId) {
        // The base's own entry, for its path. Looked up rather than
        // constructed: `path` carries a version segment and guessing it would
        // work until the next publish.
        const basePack = live.packs.find((x) => x.packId === extendsId);
        const baseFile = basePack
          ? await readPackJson(appId, basePack.path, 'pack.json').catch(() => null)
          : null;
        // A base that cannot be read leaves this pack with no preview, which is
        // the honest answer: on a device it would install and draw nothing.
        source = baseFile?.data;
        sourcePath = basePack?.path ?? p.path;
      }

      // `cdnUrl` from lib/core/cdn, not a second copy of the env fallback here.
      // That module also carries the reasoning for why the public door is the one
      // that still works while the S3 token is refused.
      const { art, count } = artFrom(
        source,
        (name) => cdnUrl(appId, sourcePath, name),
        tint,
      );

      return {
        draft: false as const,
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

  // ── DRAFTS JOIN THE LIST RATHER THAN SITTING ABOVE IT ────────────────────
  //
  // A separate strip made drafts a second list to scan, which is the shape this
  // panel has been removing everywhere else: one list, one order, a chip saying
  // which kind of row it is. A draft has no version, no size and nothing on the
  // CDN, so those columns render empty rather than as zeroes.
  const draftCards = iconDrafts.drafts.map((d) => ({
    draft: true as const,
    packId: d.packId,
    title: d.name || d.packId,
    packType: 'hero',
    version: 0,
    sizeBytes: 0,
    sku: d.sku || null,
    listed: false,
    distro: null as string | null,
    // A draft's art lives under admin/ and is reopened by URL in the builder;
    // rendering those here would be a second fetch of the same bytes for a
    // 38px mosaic, so drafts show the count and no thumbnail.
    art: [] as Art[],
    count: d.icons.length,
    mapped: d.icons.filter((i) => i.pkg).length,
    used: [] as string[],
    updatedAt: d.updatedAt,
  }));

  // ── ONE ROW PER PACK ID ───────────────────────────────────────────────────
  //
  // These two lists used to be concatenated, so saving a draft against a pack
  // that is already published produced a SECOND ROW with the same id, reading
  // exactly like the pack had been duplicated. Nothing was duplicated: a draft
  // is unpublished work sitting on top of a published pack, which is one thing
  // in two states, not two things. So a draft whose id is published merges into
  // that row as a pending marker, and only a draft for an id nobody has
  // published yet gets a row of its own.
  const publishedIdSet = new Set(published.map((p) => p.packId));
  //
  // ─── PENDING MEANS AHEAD, NOT MERELY PRESENT ──────────────────────────────
  //
  // Publishing leaves the draft in place, because it is the only copy of the
  // preview settings. So "a draft exists" stopped meaning "there is
  // unpublished work" the first time anything was published, and this row wore
  // a DRAFT PENDING chip permanently. `publishedAtVersion` is the draft's
  // record of what its content became; equal to the live version means there
  // is nothing pending and the chip is a lie.
  const merged = published.map((p) => {
    const d = iconDrafts.drafts.find((x) => x.packId === p.packId);
    const ahead = !!d && d.publishedAtVersion !== p.version;
    return ahead && d
      ? { ...p, pendingDraft: { count: d.icons.length, updatedAt: d.updatedAt } }
      : { ...p, pendingDraft: null as { count: number; updatedAt: number } | null };
  });
  const cards = [
    ...merged,
    ...draftCards
      .filter((d) => !publishedIdSet.has(d.packId))
      .map((d) => ({ ...d, pendingDraft: null as { count: number; updatedAt: number } | null })),
  ];
  cards.sort((a, b) => a.title.localeCompare(b.title));

  const matches = (c: (typeof cards)[number], f: FilterName) => {
    switch (f) {
      case 'drafts':
        return c.draft;
      case 'hero':
        return c.packType === 'hero' || c.packType === 'icon';
      case 'brand':
        return c.packType === 'brand';
      case 'in a distro':
        return !c.draft && !!c.distro;
      case 'standalone':
        return !c.draft && !c.distro;
      default:
        return true;
    }
  };

  const shown = cards.filter((c) => matches(c, active));
  // ── DRAFTS ARE SELECTABLE NOW ─────────────────────────────────────────────
  //
  // They were not, because every field the inspector shows (version, size,
  // granted by, used by) is a fact about the INDEX and a draft is in none of
  // it. True, and it left drafts as the one row type with no way to delete
  // them: the row went straight to the builder, and the builder has no delete.
  // So the index-only rows are hidden for a draft rather than the draft being
  // hidden from the inspector, and every row now behaves the same way: click
  // to inspect, then Edit or Delete.
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

      <BulkProvider>
      {/* The bar renders nothing until something is ticked, so the screen is
          unchanged for the common case of browsing. */}
      <BulkBar
        noun="icon pack"
        verb="Delete"
        app={appId}
        action={bulkDeleteIconPacksAction}
      />

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
                  key={`${c.draft ? 'draft' : 'live'}-${c.packId}`}
                  // Both kinds select. A draft used to jump straight to the
                  // builder, which is why it could never be inspected or
                  // deleted; Edit in the inspector is one further click and is
                  // the same click every published pack already takes.
                  href={href(c.packId)}
                  className={`relative flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition first:border-t-0 ${
                    on ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'
                  }`}
                >
                  {on && <span aria-hidden className="absolute inset-y-0 left-0 w-[3px] bg-site-accent" />}
                  {/* Bundled ids are refused by the action anyway; showing the
                      box for them would offer a press that cannot succeed. */}
                  <RowCheck
                    id={c.packId}
                    disabled={BULK_UNDELETABLE.has(c.packId)}
                    why="ships inside the app"
                  />
                  {c.draft ? (
                    <span
                      aria-hidden
                      className="grid size-[38px] shrink-0 place-items-center rounded-lg border border-dashed border-site-line text-site-ink-3"
                    >
                      <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M11.3 2.9l1.8 1.8L5.8 12H4v-1.8l7.3-7.3z" />
                      </svg>
                    </span>
                  ) : (
                    <Mosaic art={c.art} />
                  )}
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                      {c.title}
                    </span>
                    <span className="mt-0.5 block truncate font-mono text-[11px] text-site-ink-3">
                      {c.draft
                        ? `${c.packId} \u00b7 ${c.mapped} mapped of ${c.count}`
                        : `${c.packId} \u00b7 ${c.packType} \u00b7 v${c.version}`}
                    </span>
                  </span>
                  {/* The pending-draft marker rides BESIDE the status chip
                      rather than replacing it: the pack is still in a distro,
                      still published, and also has unpublished work. One row,
                      both facts. */}
                  {!c.draft && c.pendingDraft ? (
                    <span
                      title={`${c.pendingDraft.count} icons saved as a draft on top of the live v${c.version}`}
                      className="shrink-0 rounded-full bg-site-info-soft px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] text-site-info"
                    >
                      draft pending
                    </span>
                  ) : null}
                  <span
                    className={`shrink-0 rounded-full px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] ${
                      c.draft
                        ? 'bg-site-info-soft text-site-info'
                        : c.count === 0
                          ? 'bg-site-plan-soft text-site-plan'
                          : 'bg-site-ok-soft text-site-ok'
                    }`}
                  >
                    {c.draft ? 'draft' : c.count === 0 ? 'no art' : c.distro ? 'in a distro' : 'standalone'}
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
                  {/* A draft has art; it just lives under admin/ and is not
                      fetched for a thumbnail strip. Saying pack.json failed
                      would be a false alarm about a file that does not exist
                      yet. */}
                  {selected.draft
                    ? 'Draft art opens in the builder'
                    : 'pack.json could not be read, or names no art'}
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
                {/* NOTHING THAT IS A FACT ABOUT THE INDEX IS SHOWN FOR A DRAFT.
                    v0, 0 bytes and "granted by standalone" are not small
                    inaccuracies on a draft, they are four confident answers to
                    questions that have none yet. The one honest line replaces
                    all of them. */}
                {selected.draft ? (
                  <KVRow
                    k="state"
                    v={<span className="font-mono">draft, never published</span>}
                  />
                ) : (
                  <>
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
                  </>
                )}
              </div>

              {!selected.draft && selected.used.length === 0 && (
                <p className="mt-3 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-plan">
                  No theme names this pack in icons.heroPack or icons.brandPack, so nothing on a
                  device would load it.
                </p>
              )}

              {/* Under 8KB means a pack.json and essentially no art beside it:
                  the yaru case, where a theme naming it gets the generator for
                  every app and reports no error anywhere. */}
              {!selected.draft && selected.sizeBytes < 8192 && selected.packType !== 'brand' && (
                <p className="mt-2 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-plan">
                  Under 8KB, so this is a pack.json with almost no art beside it. A theme naming it
                  falls back to the generated icons silently.
                </p>
              )}

              {/* Listing writes a flag against an INDEX ENTRY, so a draft has
                  nothing to toggle. Rendering it anyway would offer to hide
                  something no device can see. */}
              {!selected.draft && (
                <div className="mt-3 flex items-center justify-between gap-3 border-t border-site-line pt-3">
                  <span className="text-[12px] text-site-ink-3">
                    {selected.listed ? 'listed on device' : 'hidden'}
                  </span>
                  <ListToggle app={appId} packId={selected.packId} initial={selected.listed} />
                </div>
              )}

              {/* THE SUBJECT OF THE SENTENCE IS THE DRAFT, NOT THE PACK, and
                  the old wording left that to the reader. "has never been
                  published" sat directly under a row labelled v2, which reads
                  as a claim about the pack and is the exact sentence that
                  makes someone press publish on something already live. Both
                  version numbers are named now, so there is nothing to infer. */}
              {!selected.draft && selected.pendingDraft && (
                <p className="mt-3 rounded-[10px] bg-site-info-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-info">
                  {selected.pendingDraft.count} icons are saved as an unpublished draft on top of
                  the live v{selected.version}. Edit opens the draft; publishing from there writes
                  v{selected.version + 1}.
                </p>
              )}

              {/* ── EDIT AND RENAME, AND WHY RENAME IS NOT A FIELD ──────────
                  The builder's Pack id is read-only once a pack is open, and
                  correctly so: the id is the primary key of the draft, the
                  bucket directory, the index entry and the device's install
                  path, so typing a new one there published a SECOND pack at v1
                  and left the original live and orphaned. A rename is therefore
                  a migration rather than an edit, and it gets its own screen
                  which reads the live state, reports what it will do, and only
                  then moves the art, publishes the new id and repoints every
                  distro that names the old one. */}
              <div className="mt-3 flex flex-wrap gap-2 border-t border-site-line pt-3">
                <SoftButton href={`/apps/${appId}/icons/builder?id=${selected.packId}`}>Edit</SoftButton>
                <SoftButton href={`/apps/${appId}/icons/rename?from=${selected.packId}`}>
                  Rename id
                </SoftButton>
              </div>

              {/* ── DELETE LIVES HERE NOW, AND UNPUBLISH STILL LIVES THERE ──
                  The note this replaces was right about one thing and wrong
                  about another. Pulling an ARBITRARY pack by id is a delivery
                  operation and stays on CDN objects beside the manifest it
                  belongs to. Deleting a pack you are looking at, made on this
                  screen, is an authoring operation, and sending someone to
                  another screen to finish the CRUD they started here is how a
                  panel grows orphans. This checks what only this screen knows:
                  whether a distro still names the pack. */}
              <DeleteIconPack
                app={appId}
                packId={selected.packId}
                published={!selected.draft}
                usedBy={selected.used}
              />

              <p className="mt-3 text-[11px] leading-relaxed text-site-ink-3">
                {selected.draft
                  ? 'Nothing here is live yet. Publishing from the builder creates it at version 1.'
                  : 'Deleting removes it from the catalogue. To pull an arbitrary pack by id, or to sweep the objects it leaves behind, use CDN objects.'}
              </p>
            </div>
          </aside>
        )}
      </div>

      </BulkProvider>

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
