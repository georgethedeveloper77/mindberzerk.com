import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SoftButton } from '@/components/studio/ui';
import { DeleteDistro } from '@/components/theme-list/DeleteDistro';
import { ListToggle } from '@/components/theme-list/ListToggle';
import { ThemePreview } from '@/components/theme-builder/ThemePreview';
import { APPS, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { isListed, readListingResult } from '@/lib/core/listing';
import { readPackJson } from '@/lib/core/pack-content';
import { appMeta, appName } from '@/lib/core/registry';
import { importTheme, type ThemeSpecJson } from '@/lib/g-launcher/theme-spec';
import { distroIconPackIds, ensureSeededSafe, mergeThemeRows } from '@/lib/g-launcher/themes';

export const dynamic = 'force-dynamic';

/**
 * DISTROS - the inventory, and the only one.
 *
 * A distro is a theme pack, plus an optional icon pack, plus optional SKUs.
 * Two lists and two builders for one thing meant two places for the schema to
 * drift and two answers to "where is Ubuntu".
 *
 * ─── ROWS AND ONE INSPECTOR ─────────────────────────────────────────────────
 *
 * An earlier pass gave every distro a full phone preview, on the grounds that
 * what a distro LOOKS like is the only question worth asking. Half right: it
 * cost about 300px each, so four distros filled a laptop screen, and the fields
 * that actually differ ended up three lines apart inside separate boxes, which
 * is the worst possible shape for comparing them.
 *
 * So the preview renders ONCE, in the inspector, at a size worth looking at.
 *
 * ─── THE SWATCH IS A WALLPAPER, NOT A COLOUR CHIP ───────────────────────────
 *
 * It used to be a small square of the top colour, which at that size cannot
 * distinguish Ubuntu from Ubuntu (paid test), the two rows most likely to be
 * confused. It is now phone-shaped and carries the real gradient, the top-bar
 * band and the accent as a dock square, which is genuinely what identifies a
 * distro at a glance.
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
 * remove, a chip says everything the separation would have said, and the
 * filters cover the case where you genuinely want one kind. Bundled sort first,
 * because they are the floor everything else falls back to.
 */

const FILTERS = ['all', 'live', 'bundled', 'paid', 'unlisted'] as const;
type FilterName = (typeof FILTERS)[number];

function isFilter(v: string | undefined): v is FilterName {
  return !!v && (FILTERS as readonly string[]).includes(v);
}

/** A hex from the spec, or a token when the spec is missing or malformed. */
function hex(value: string | undefined, fallback: string): string {
  return value && /^#[0-9a-f]{3,8}$/i.test(value) ? value : fallback;
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
  // `readListingResult`, NOT `readListing`. The plain one collapses an
  // unreadable bucket into an empty map, and an empty map means "everything is
  // listed", so a refused credential rendered as a screen full of confident
  // green toggles. The result form carries the difference and the banner says
  // which it is.
  const [seeded, live, listingResult] = await Promise.all([
    ensureSeededSafe(appId),
    readLiveIndex(appId),
    readListingResult(appId),
  ]);
  const listing = listingResult.listing;
  const { drafts, unreachable: draftsUnreachable } = seeded;
  const rows = mergeThemeRows(drafts, live);

  const specs = new Map<string, ThemeSpecJson>(drafts.map((d) => [d.id, d.spec]));

  // A theme published out-of-band has no local draft, so its spec comes out of
  // the pack itself. One GET per such distro, on a page with a handful of them.
  // Failures resolve to null and the row falls back to a neutral swatch rather
  // than disappearing.
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

  const matches = (r: (typeof sorted)[number], f: FilterName) => {
    switch (f) {
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
  };

  const shown = sorted.filter((r) => matches(r, active));

  // The fallback is load-bearing: after a delete, `sel` names a row that no
  // longer exists, and without this the inspector would render empty beside a
  // list that is fine.
  const selected = shown.find((r) => r.id === sel) ?? shown[0] ?? null;
  const selectedSpec = selected ? (specs.get(selected.id) ?? null) : null;
  const selectedIcons = selected ? distroIconPackIds(live, selected.id) : null;
  const selectedListed = selected ? isListed(listing, selected.id) : false;

  const meta = appMeta(appId);
  const href = (id: string) =>
    `/apps/${appId}/distros?${active === 'all' ? '' : `filter=${active}&`}sel=${id}#detail`;

  return (
    <StudioShell app={appId}>
      {listingResult.unreachable && !live.unreachable && !draftsUnreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The listing flags could not be read, so every distro below is shown as listed whether it
          is or not. {listingResult.unreachable}
        </p>
      )}

      {(live.unreachable || draftsUnreachable) && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so this is the distros compiled into the panel rather than
          what is published. Nothing here reflects the CDN, and edits cannot be saved.{' '}
          {live.unreachable ?? draftsUnreachable}
        </p>
      )}

      {/* THE COMPACT SLAB. No metrics: this screen's vertical space belongs to
          the rows. Same tint, same grid, a third of the Overview's height. */}
      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(appId)}
        title="Distros"
        actions={
          <SlabButton href={`/apps/${appId}/distros/builder`} primary>
            New distro
          </SlabButton>
        }
      />

      {/* Filters carry counts, because knowing there is exactly one unlisted
          distro is most of the reason to click unlisted. */}
      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => {
          const n = sorted.filter((r) => matches(r, f)).length;
          const on = active === f;
          return (
            <Link
              key={f}
              href={`/apps/${appId}/distros${f === 'all' ? '' : `?filter=${f}`}`}
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

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_306px]">
        <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
          {shown.length === 0 ? (
            <div className="px-[18px] py-10 text-center">
              <p className="text-[13px] text-site-ink-3">
                {active === 'all' ? 'No distros yet.' : `No ${active} distros.`}
              </p>
              <div className="mt-3 flex justify-center">
                {active === 'all' ? (
                  <SoftButton href={`/apps/${appId}/distros/builder`}>New distro</SoftButton>
                ) : (
                  <SoftButton href={`/apps/${appId}/distros`}>Show all</SoftButton>
                )}
              </div>
            </div>
          ) : (
            shown.map((r) => {
              const p = specs.get(r.id)?.palette;
              const shell = specs.get(r.id)?.shell;
              const on = selected?.id === r.id;
              const version =
                r.publishedVersion != null
                  ? `live v${r.publishedVersion}`
                  : r.draftVersion != null
                    ? `draft v${r.draftVersion}`
                    : 'no version';
              return (
                <Link
                  key={r.id}
                  href={href(r.id)}
                  className={`relative flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition first:border-t-0 ${
                    on ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'
                  }`}
                >
                  {on && <span aria-hidden className="absolute inset-y-0 left-0 w-[3px] bg-site-accent" />}

                  {/* The wallpaper swatch. Phone-shaped on purpose: it is a
                      miniature of the thing, not a colour sample. */}
                  <span
                    aria-hidden
                    className="relative h-[46px] w-[34px] shrink-0 overflow-hidden rounded-lg border border-white/10"
                    style={{
                      background: `linear-gradient(165deg, ${hex(p?.bgTop, '#2a2438')}, ${hex(p?.bgBottom, '#14101c')})`,
                    }}
                  >
                    <span className="absolute inset-x-0 top-0 h-[5px] bg-black/30" />
                    <span
                      className="absolute bottom-[5px] left-[5px] size-[9px] rounded-[3px]"
                      style={{ background: hex(p?.accent, 'rgba(255,255,255,0.35)') }}
                    />
                  </span>

                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                      {r.title || r.id}
                    </span>
                    <span className="mt-0.5 block truncate font-mono text-[11px] text-site-ink-3">
                      {r.id}
                      {shell ? ` \u00b7 ${shell}` : ''} {'\u00b7'} {version}
                    </span>
                  </span>

                  <StateChip row={r} listed={isListed(listing, r.id)} />

                  <span
                    className={`w-[104px] shrink-0 truncate text-right font-mono text-[11.5px] ${
                      r.sku ? 'text-site-ink' : 'text-site-ink-3'
                    }`}
                  >
                    {r.sku ?? 'free'}
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
            <div className="flex justify-center border-b border-site-line bg-site-sunk py-3.5">
              {selectedSpec ? (
                /* THE CLIP BOX IS SIZED FROM ThemePreview'S OWN GEOMETRY: a
                   232x480 phone inside 7px of padding is 246x494, times the
                   scale. The inner width must be the component's REAL 246px,
                   because `transform: scale` happens at paint time, after
                   layout: laid out inside a narrow box first, its centring flex
                   column would start the phone at a negative offset and clip
                   the left edge. 246 x 0.68 = 167, 494 x 0.68 = 336. Change one
                   and change the other. */
                <div className="h-[336px] w-[167px] overflow-hidden">
                  <div className="w-[246px] origin-top-left scale-[0.68]">
                    <ThemePreview spec={selectedSpec} />
                  </div>
                </div>
              ) : (
                <div className="flex h-[336px] w-[167px] items-center justify-center px-3 text-center text-[11.5px] leading-relaxed text-site-ink-3">
                  no theme.json to preview
                </div>
              )}
            </div>

            <div className="px-4 pb-4 pt-3.5">
              <div className="truncate font-site-display text-[15px] font-bold text-site-ink">
                {selected.title || selected.id}
              </div>
              <div className="truncate font-mono text-[11px] text-site-ink-3">{selected.id}</div>
              {selected.summary && (
                <div className="mt-1.5 text-[11.5px] leading-relaxed text-site-ink-2">
                  {selected.summary}
                </div>
              )}

              <div className="mt-3 border-t border-site-line">
                <KVRow k="shell" v={<span className="font-mono">{selectedSpec?.shell ?? '-'}</span>} />
                <KVRow
                  k="version"
                  v={
                    <span className="font-mono">
                      {selected.publishedVersion != null
                        ? `v${selected.publishedVersion}`
                        : selected.draftVersion != null
                          ? `draft v${selected.draftVersion}`
                          : '-'}
                    </span>
                  }
                />
                <KVRow k="product" v={<span className="font-mono">{selected.sku ?? 'free'}</span>} />
                <KVRow
                  k="icon packs"
                  v={
                    <span className="font-mono">
                      {selectedIcons && selectedIcons.present.length + selectedIcons.pending.length > 0
                        ? [...selectedIcons.present, ...selectedIcons.pending].join(', ')
                        : 'none'}
                    </span>
                  }
                />
              </div>

              <div className="flex items-center justify-between gap-3 border-b border-site-line py-2.5">
                <span className="text-[12px] text-site-ink-3">
                  {selected.bundled ? 'bundled' : selectedListed ? 'listed on device' : 'hidden'}
                </span>
                {/* Disabled rather than hidden for bundled distros, so the rule
                    is visible where you would look for it. */}
                <ListToggle
                  app={appId}
                  packId={selected.id}
                  initial={selectedListed}
                  disabled={selected.bundled}
                />
              </div>

              <div className="mt-3 flex flex-wrap items-center gap-3">
                <SoftButton href={`/apps/${appId}/distros/builder?id=${selected.id}`}>Edit</SoftButton>
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
                <p className="mt-3 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
                  Bundled distros ship inside the APK, so they are always available and cannot be
                  delisted or deleted.
                </p>
              )}
            </div>
          </aside>
        )}
      </div>

      <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
        A distro is a theme pack plus an optional icon pack. Product ID is the Play SKU; blank is
        free. To pull a live CDN pack from every device, use Unpublish on the CDN objects screen.
      </p>
    </StudioShell>
  );
}

/**
 * ONE chip, not three.
 *
 * Rows carried Free, Bundled and Not published as separate chips, which is
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
  const [text, skin] = row.bundled
    ? ['bundled', 'bg-site-info-soft text-site-info']
    : row.publishedVersion == null
      ? ['draft', 'bg-site-plan-soft text-site-plan']
      : !listed
        ? ['unlisted', 'bg-site-plan-soft text-site-plan']
        : row.needsPublish
          ? ['draft ahead', 'bg-site-plan-soft text-site-plan']
          : [`live v${row.publishedVersion}`, 'bg-site-ok-soft text-site-ok'];

  return (
    <span
      className={`shrink-0 rounded-full px-2 py-[2.5px] text-[9.5px] font-bold uppercase tracking-[0.05em] ${skin}`}
    >
      {text}
    </span>
  );
}
