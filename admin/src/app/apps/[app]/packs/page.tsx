import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { indexIsSigned, readLiveIndex } from '@/lib/core/catalogue';
import { orphanReport } from '@/lib/core/orphans';
import { isAppId, appName } from '@/lib/core/registry';
import { KNOWN_PACK_TYPES } from '@/lib/core/sign';
import { Shell } from '@/app/components/shell';
import { SweepOrphans } from '@/components/packs/SweepOrphans';
import { UnpublishButton } from '@/app/components/unpublish-button';
import {
  Banner,
  Button,
  Card,
  Chip,
  Empty,
  Filter,
  Inspector,
  KV,
  PageHead,
  Row,
  Rows,
  Table,
  Td,
  Th,
  Toolbar,
  Tr,
  bytes,
  when,
} from '@/app/components/ui';

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
 * The other two list screens draw the pack: a gradient swatch for a distro, a
 * mosaic of real icons for an icon pack. NOT HERE, and the reason is arithmetic
 * rather than taste. This page holds every pack kind at once, so a thumbnail
 * would mean fetching every theme.json AND every pack.json to draw a 26px
 * square, on the one screen that already does the most reads. What identifies a
 * pack here is its type and its path, so those are what the row carries. The
 * art is one click away on the screen that is about art.
 *
 * ─── FOUR STAT TILES BECAME ONE INDEX STRIP ─────────────────────────────────
 *
 * Packs, size and paid were three tiles restating what the rows and the meta
 * line already say. What is actually worth a permanent line is the INDEX: is it
 * signed, which key signed it, when, and which prefix. Those four sat in a card
 * at the very bottom of the page, three screens below the banner warning that
 * the index was unsigned. Now the facts and the warning about them are adjacent.
 *
 * ─── UNPUBLISH IS HERE AND ON THE DETAIL PAGE, DELIBERATELY ─────────────────
 *
 * The same component, the same route, the same two-step confirm. The detail
 * page keeps it because that is where you verify against the manifest and the
 * file list before pulling. It is here too because this is where you are
 * standing when the orphan sweep below is what you came for, and making a
 * delisting a page-load away from its own cleanup is how leftovers accumulate.
 */
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
  // alarm. Rendered as a section, not a banner: orphans are housekeeping.
  const [signed, orphans] = await Promise.all([
    live.exists ? indexIsSigned(app) : Promise.resolve(false),
    orphanReport(app),
  ]);

  const activeType =
    type && (KNOWN_PACK_TYPES as readonly string[]).includes(type) ? type : null;
  const shown = activeType
    ? live.packs.filter((p) => p.packType === activeType)
    : live.packs;

  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);
  const paid = live.packs.filter((p) => p.sku).length;

  // Same fallback as the other list screens: after an unpublish, `sel` names a
  // pack that is no longer in the catalogue, and the first row quietly takes
  // over rather than leaving an inspector describing something that is gone.
  const selected = shown.find((p) => p.packId === sel) ?? shown[0] ?? null;

  const href = (id: string) =>
    `/apps/${app}/packs?${activeType ? `type=${activeType}&` : ''}sel=${id}#detail`;

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Publishing is blocked rather
          than overwriting it. Fix the object in the bucket before republishing.
        </Banner>
      )}
      {live.exists && !signed && (
        <Banner tone="bad">
          index.json is published without index.sig. Every device refuses it and
          keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      )}
      {live.unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so nothing below reflects what is
          published. {live.unreachable}
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} packs`}
        meta={`${live.packs.length} live · ${bytes(size)} · ${paid} paid · updated ${when(live.generatedAt)}`}
        actions={
          <Button href={`/apps/${app}/publish`} variant="primary">
            Upload pack
          </Button>
        }
      />

      {/* The index, as one line. See the note above on why this replaced four
          tiles and a card at the bottom of the page. */}
      <div className="mb-3 flex flex-wrap gap-x-4 gap-y-1 rounded-card border border-line-soft px-3 py-2 font-mono text-micro text-ink-3">
        <span>
          index{' '}
          <span className={signed ? 'text-ok' : live.exists ? 'text-bad' : 'text-ink-2'}>
            {signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
          </span>
        </span>
        <span>
          key <span className="text-ink-2">{live.keyId}</span>
        </span>
        <span>
          generatedAt <span className="text-ink-2 tnum">{live.generatedAt || '-'}</span>
        </span>
        <span>
          prefix <span className="text-ink-2">{app}/</span>
        </span>
      </div>

      <Toolbar>
        <Filter href={`/apps/${app}/packs`} active={!activeType}>
          all
        </Filter>
        {KNOWN_PACK_TYPES.map((t) => (
          <Filter key={t} href={`/apps/${app}/packs?type=${t}`} active={activeType === t}>
            {t}
          </Filter>
        ))}
      </Toolbar>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          {shown.length === 0 ? (
            <Empty
              action={
                activeType ? (
                  <Button href={`/apps/${app}/packs`}>Show all</Button>
                ) : (
                  <Button href={`/apps/${app}/publish`}>Upload a pack</Button>
                )
              }
            >
              {live.packs.length === 0 ? 'Nothing published yet.' : `No ${activeType} packs.`}
            </Empty>
          ) : (
            <Rows>
              {shown.map((p) => (
                <Row
                  key={p.packId}
                  href={href(p.packId)}
                  selected={selected?.packId === p.packId}
                  title={p.title || p.packId}
                  subtitle={p.path}
                  chip={<Chip>{p.packType}</Chip>}
                  right={
                    <>
                      <span className="inline-block w-8 text-right">v{p.version}</span>
                      <span className="inline-block w-14 text-right">{bytes(p.sizeBytes)}</span>
                    </>
                  }
                />
              ))}
            </Rows>
          )}

          {orphans.ok && orphans.groups.length > 0 && (
            <div className="mt-3">
              <Card
                title="Orphaned objects"
                flush
                right={
                  <span className="font-mono text-micro text-ink-3">
                    {orphans.objectCount} objects · {bytes(orphans.totalBytes)}
                  </span>
                }
              >
                {/* Left behind on purpose by unpublish and delete, so in-flight
                    device downloads finish. This is the deliberate second half:
                    reviewed, grouped, and gone only on an explicit confirm. The
                    catalogue, admin state, site files, and every live pack's
                    current version are never listed here and can never be
                    swept. */}
                <SweepOrphans app={app} groups={orphans.groups} />
              </Card>
            </div>
          )}

          {live.entitlements.length > 0 && (
            <div className="mt-3">
              <Card title="Bundles" flush>
                <Table
                  head={
                    <>
                      <Th>SKU</Th>
                      <Th>Title</Th>
                      <Th num>Grants</Th>
                    </>
                  }
                >
                  {live.entitlements.map((e) => (
                    <Tr key={e.sku}>
                      <Td mono>{e.sku}</Td>
                      <Td>{e.title}</Td>
                      <Td num>{e.grants.includes('*') ? 'everything' : e.grants.length}</Td>
                    </Tr>
                  ))}
                </Table>
              </Card>
            </div>
          )}
        </div>

        {selected && (
          <Inspector>
            <div className="truncate text-data font-medium text-ink">
              {selected.title || selected.packId}
            </div>
            <div className="truncate font-mono text-micro text-ink-3">{selected.packId}</div>

            <div className="mt-2.5 border-t border-line-soft pt-1">
              <KV k="type" v={selected.packType} />
              {/* Pack versions are monotonic INTEGERS, not semver. The device
                  refuses anything that does not increase, so the number is the
                  whole contract. */}
              <KV k="version" v={selected.version} />
              <KV k="min app" v={selected.minAppVersion} />
              <KV k="size" v={bytes(selected.sizeBytes)} />
              <KV k="product" v={selected.sku ?? 'free'} />
            </div>

            {selected.summary && (
              <p className="mt-2 text-micro leading-relaxed text-ink-2">{selected.summary}</p>
            )}

            <div className="mt-2 break-all font-mono text-micro leading-relaxed text-ink-3">
              {app}/{selected.path}
            </div>

            <div className="mt-2.5 flex flex-wrap items-center gap-2 border-t border-line-soft pt-2.5">
              <Button href={`/apps/${app}/packs/${selected.packId}`}>Open</Button>
              <UnpublishButton app={app} packId={selected.packId} />
            </div>
            <p className="mt-2 text-micro leading-relaxed text-ink-3">
              Open shows the manifest, the file list and every sha256. Pulling
              leaves the objects in the bucket; they appear above as orphans.
            </p>
          </Inspector>
        )}
      </div>
    </Shell>
  );
}
