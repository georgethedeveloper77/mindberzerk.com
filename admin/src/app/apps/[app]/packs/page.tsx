import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SoftButton, SoftPanel } from '@/components/studio/ui';
import { SweepOrphans } from '@/components/packs/SweepOrphans';
import { UnpublishButton } from '@/app/components/unpublish-button';
import { bytes, when } from '@/app/components/ui';
import { indexIsSigned, readLiveIndex } from '@/lib/core/catalogue';
import { orphanReport } from '@/lib/core/orphans';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { KNOWN_PACK_TYPES } from '@/lib/core/sign';
import { READ_BY_APP } from '@/lib/g-recovery/content-packs';

export const dynamic = 'force-dynamic';

/**
 * CDN OBJECTS - the catalogue for one app, and the substrate under Distros and
 * Icons.
 *
 * Everything on the CDN is a pack; `packType` says which kind. Distros filters
 * to `theme`, Icons filters to the icon families, and this shows all of them
 * plus the delivery detail neither product view has: the bucket path, the
 * version, the signed manifest, and the objects nothing references any more.
 *
 * ─── ROWS AND AN INSPECTOR, AND NO THUMBNAILS ───────────────────────────────
 *
 * The other two list screens draw the pack: a wallpaper swatch for a distro, a
 * mosaic of real icons for an icon pack. NOT HERE, and the reason is arithmetic
 * rather than taste. This page holds every pack kind at once, so a thumbnail
 * would mean fetching every theme.json AND every pack.json to draw a small
 * square, on the one screen that already does the most reads. What identifies a
 * pack here is its type and its path, so those are what the row carries, with
 * the type colour doing the recognition work a thumbnail would have done.
 *
 * ─── THE INDEX STRIP MOVED INTO THE SLAB ────────────────────────────────────
 *
 * Signed, key, generatedAt and prefix used to sit in a card at the bottom of
 * the page, three screens below the banner warning that the index was unsigned.
 * They are now in the header, beside the warning they explain: on this screen
 * the index IS the subject, not a footnote about it.
 *
 * ─── UNPUBLISH IS HERE AND ON THE DETAIL PAGE, DELIBERATELY ─────────────────
 *
 * The same component, the same route, the same two-step confirm. The detail
 * page keeps it because that is where you verify against the manifest and the
 * file list before pulling. It is here too because this is where you are
 * standing when the orphan sweep below is what you came for, and putting a
 * delisting a page-load away from its own cleanup is how leftovers accumulate.
 */

/**
 * Shared with Distros and the Overview, so a type reads the same everywhere.
 *
 * ALL SEVEN, not the launcher's four. The three content types were added to
 * `KNOWN_PACK_TYPES` for G Recovery and never got here, so a published trashmap
 * drew the same grey dot as a pack of an unknown type. On the one screen whose
 * job is telling pack kinds apart, that made the only kind this app publishes
 * the least legible thing on it.
 */
const TYPE_COLOUR: Record<string, string> = {
  theme: '#e95420',
  brand: '#4c8dff',
  hero: '#3fb950',
  icon: '#d29922',
  registry: '#2f9e8f',
  article: '#7c73d6',
  guide: '#c2739b',
};

export default async function PacksPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ type?: string; sel?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  // A bad segment is a 404, not an empty page. Without this, `/apps/nope/packs`
  // would reach R2 with an attacker-supplied prefix.
  if (!isAppId(app)) notFound();

  const { type, sel } = await searchParams;
  const live = await readLiveIndex(app);
  // The report shares the live read's guards internally, so an unreachable or
  // corrupt index yields `ok: false` here rather than a bucket-wide false
  // alarm. Rendered as a panel, not a banner: orphans are housekeeping.
  const [signed, orphans] = await Promise.all([
    live.exists ? indexIsSigned(app) : Promise.resolve(false),
    orphanReport(app),
  ]);

  const activeType = type && (KNOWN_PACK_TYPES as readonly string[]).includes(type) ? type : null;
  const shown = activeType ? live.packs.filter((p) => p.packType === activeType) : live.packs;

  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);
  const paid = live.packs.filter((p) => p.sku).length;

  // Same fallback as the other list screens: after an unpublish, `sel` names a
  // pack that is no longer in the catalogue, and the first row quietly takes
  // over rather than leaving an inspector describing something that is gone.
  const selected = shown.find((p) => p.packId === sel) ?? shown[0] ?? null;

  const meta = appMeta(app);
  const href = (id: string) =>
    `/apps/${app}/packs?${activeType ? `type=${activeType}&` : ''}sel=${id}#detail`;

  return (
    <StudioShell app={app}>
      {live.corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is present but does not parse. Publishing is blocked rather than overwriting
          it. Fix the object in the bucket before republishing.
        </p>
      )}
      {live.exists && !signed && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is published without index.sig. Every device refuses it and keeps the
          catalogue it already had. Republish to regenerate both.
        </p>
      )}
      {live.unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so nothing below reflects what is published.{' '}
          {live.unreachable}
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="CDN objects"
        meta={`${live.packs.length} live · ${bytes(size)} · ${paid} paid · updated ${when(live.generatedAt)}`}
        actions={
          <SlabButton href={`/apps/${app}/publish`} primary>
            Upload pack
          </SlabButton>
        }
      >
        {/* THE INDEX, AS ONE LINE, in the header rather than at the bottom of
            the page. On this screen the index is the subject. */}
        <div className="mt-4 flex flex-wrap gap-x-5 gap-y-1.5 rounded-xl border border-white/10 bg-white/5 px-3.5 py-2.5 font-mono text-[11px] text-white/45">
          <span>
            index{' '}
            <span className={signed ? 'text-[#5ee0a8]' : live.exists ? 'text-[#ff8b83]' : 'text-white/70'}>
              {signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
            </span>
          </span>
          <span>
            key <span className="text-white/75">{live.keyId || '-'}</span>
          </span>
          <span>
            generatedAt <span className="text-white/75 tnum">{live.generatedAt || '-'}</span>
          </span>
          <span>
            prefix <span className="text-white/75">{app}/</span>
          </span>
        </div>
      </AppSlab>

      {/* CHIPS FOR WHAT IS HERE, plus whichever one is selected.

          Every app got all seven, so G Recovery offered to filter by distro
          and icon pack and the launcher offered to filter by article, and in
          both cases four of the seven were guaranteed to be empty. Deriving
          from the index means the strip describes this bucket rather than the
          type union, and it needs no per-app list to keep in step. The active
          type is kept even at zero, or clicking a chip would remove the chip
          you clicked and leave nothing to go back to. */}
      <div className="flex flex-wrap gap-2">
        {[null, ...KNOWN_PACK_TYPES.filter(
          (t) => live.packs.some((p) => p.packType === t) || t === activeType,
        )].map((t) => {
          const on = activeType === t;
          const n = t ? live.packs.filter((p) => p.packType === t).length : live.packs.length;
          return (
            <Link
              key={t ?? 'all'}
              href={`/apps/${app}/packs${t ? `?type=${t}` : ''}`}
              className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition ${
                on
                  ? 'border-site-accent/30 bg-site-accent-soft text-site-accent-deep'
                  : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
              }`}
            >
              {t && (
                <span
                  aria-hidden
                  className="size-[7px] rounded-full"
                  style={{ background: TYPE_COLOUR[t] ?? 'var(--color-site-ink-3)' }}
                />
              )}
              {t ?? 'all'}
              <span className="font-mono text-[11px] opacity-70">{n}</span>
            </Link>
          );
        })}
      </div>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_306px]">
        <div className="flex min-w-0 flex-col gap-4">
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            {shown.length === 0 ? (
              <div className="px-[18px] py-10 text-center">
                <p className="text-[13px] text-site-ink-3">
                  {live.packs.length === 0 ? 'Nothing published yet.' : `No ${activeType} packs.`}
                </p>
                <div className="mt-3 flex justify-center">
                  {activeType ? (
                    <SoftButton href={`/apps/${app}/packs`}>Show all</SoftButton>
                  ) : (
                    <SoftButton href={`/apps/${app}/publish`}>Upload a pack</SoftButton>
                  )}
                </div>
              </div>
            ) : (
              shown.map((p) => {
                const on = selected?.packId === p.packId;
                const colour = TYPE_COLOUR[p.packType] ?? 'var(--color-site-ink-3)';
                return (
                  <Link
                    key={p.packId}
                    href={href(p.packId)}
                    className={`relative flex items-center gap-3.5 border-t border-site-line px-4 py-2.5 transition first:border-t-0 ${
                      on ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'
                    }`}
                  >
                    {on && <span aria-hidden className="absolute inset-y-0 left-0 w-[3px] bg-site-accent" />}

                    {/* The type, as colour rather than as a fifth chip. It is
                        the one thing that identifies a pack on this screen and
                        it repeats hundreds of times, so it should be scannable
                        without being read. */}
                    <span
                      className="w-[52px] shrink-0 rounded-md px-1.5 py-1 text-center font-mono text-[10px] font-bold uppercase"
                      style={{ background: `color-mix(in srgb, ${colour} 16%, transparent)`, color: colour }}
                    >
                      {p.packType}
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                        {p.title || p.packId}
                      </span>
                      <span className="mt-0.5 block truncate font-mono text-[11px] text-site-ink-3">
                        {p.path}
                      </span>
                    </span>

                    {/* ─── WHETHER THE SHIPPED APP CAN READ THIS ────────────
                        The panel knows about more content than the app does.
                        ContentStore in G Recovery declares two ids and no more,
                        so oem-guide and storage-map can be authored, validated,
                        signed, uploaded and indexed here, and no device will
                        ever fetch them.

                        Not a bug in the pipeline, and worth an afternoon of
                        somebody's life if nothing says so. Only rendered for
                        this app, because the launcher's readers are a different
                        list and guessing at it would mark a real pack dead. */}
                    {app === 'g-recovery' && !READ_BY_APP.has(p.packId) && (
                      <span className="hidden shrink-0 rounded-md border border-site-bad/30 bg-site-bad-soft px-1.5 py-px font-mono text-[9px] tracking-[0.08em] text-site-bad sm:block">
                        NO READER
                      </span>
                    )}

                    {p.sku && (
                      <span className="hidden shrink-0 truncate font-mono text-[11px] text-site-ink-2 sm:block">
                        {p.sku}
                      </span>
                    )}
                    <span className="w-9 shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                      v{p.version}
                    </span>
                    <span className="w-[62px] shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                      {bytes(p.sizeBytes)}
                    </span>
                  </Link>
                );
              })
            )}
          </section>

          {orphans.ok && orphans.groups.length > 0 && (
            <SoftPanel
              title="Orphaned objects"
              note="left behind on purpose, swept on an explicit confirm"
              right={
                <span className="font-mono text-[11.5px] text-site-ink-3">
                  {orphans.objectCount} objects · {bytes(orphans.totalBytes)}
                </span>
              }
            >
              {/* Left behind by unpublish and delete so in-flight device
                  downloads finish. This is the deliberate second half:
                  reviewed, grouped, and gone only on an explicit confirm. The
                  catalogue, admin state, site files, and every live pack's
                  current version are never listed here and can never be swept. */}
              <SweepOrphans app={app} groups={orphans.groups} />
            </SoftPanel>
          )}

          {live.entitlements.length > 0 && (
            <SoftPanel title="Bundles" note="entitlements carried in this index" flush>
              {live.entitlements.map((e) => (
                <div
                  key={e.sku}
                  className="flex items-center gap-3 border-t border-site-line px-[18px] py-2.5 first:border-t-0"
                >
                  <span className="w-[150px] shrink-0 truncate font-mono text-[11.5px] text-site-ink">
                    {e.sku}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[12.5px] text-site-ink-2">{e.title}</span>
                  <span
                    className={`shrink-0 font-mono text-[11.5px] ${
                      e.grants.includes('*') ? 'font-bold text-site-plan' : 'text-site-ink-3'
                    }`}
                  >
                    {e.grants.includes('*') ? 'everything' : `${e.grants.length} granted`}
                  </span>
                </div>
              ))}
            </SoftPanel>
          )}
        </div>

        {selected && (
          <aside
            id="detail"
            className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4"
          >
            <div
              className="h-1.5"
              style={{ background: TYPE_COLOUR[selected.packType] ?? 'var(--color-site-line)' }}
            />
            <div className="px-4 pb-4 pt-3.5">
              <div className="truncate font-site-display text-[15px] font-bold text-site-ink">
                {selected.title || selected.packId}
              </div>
              <div className="truncate font-mono text-[11px] text-site-ink-3">{selected.packId}</div>

              <div className="mt-3 border-t border-site-line">
                <KVRow k="type" v={<span className="font-mono">{selected.packType}</span>} />
                {/* Pack versions are monotonic INTEGERS, not semver. The device
                    refuses anything that does not increase, so the number is
                    the whole contract. */}
                <KVRow k="version" v={<span className="font-mono">{selected.version}</span>} />
                <KVRow k="min app" v={<span className="font-mono">{selected.minAppVersion}</span>} />
                <KVRow k="size" v={<span className="font-mono">{bytes(selected.sizeBytes)}</span>} />
                <KVRow k="product" v={<span className="font-mono">{selected.sku ?? 'free'}</span>} />
              </div>

              {selected.summary && (
                <p className="mt-3 text-[11.5px] leading-relaxed text-site-ink-2">{selected.summary}</p>
              )}

              <p className="mt-3 break-all rounded-lg bg-site-sunk px-2.5 py-2 font-mono text-[10.5px] leading-relaxed text-site-ink-3">
                {app}/{selected.path}
              </p>

              <div className="mt-3 flex flex-wrap items-center gap-2.5 border-t border-site-line pt-3">
                <SoftButton href={`/apps/${app}/packs/${selected.packId}`}>Open</SoftButton>
                <UnpublishButton app={app} packId={selected.packId} />
              </div>

              <p className="mt-3 text-[11px] leading-relaxed text-site-ink-3">
                Open shows the manifest, the file list and every sha256. Pulling leaves the objects
                in the bucket; they appear above as orphans.
              </p>
            </div>
          </aside>
        )}
      </div>
    </StudioShell>
  );
}
