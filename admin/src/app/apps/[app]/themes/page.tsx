import { notFound } from 'next/navigation';

import { APPS, readLiveIndex, type AppId } from '@/lib/catalogue';
import { ensureSeeded, mergeThemeRows } from '@/lib/themes';
import { readListing, isListed } from '@/lib/listing';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Button, Card, Chip, PageHead, Table, Td, Th, Tr, type Tone } from '@/app/components/ui';
import { ListToggle } from '@/components/theme-list/ListToggle';

export const dynamic = 'force-dynamic';

/**
 * PHASE B (panel) - the inventory the storefront is assembled from.
 *
 * Everything the panel can act on in one list: the three bundled free themes
 * (Ubuntu, KDE, Terminal) that ship in the APK, any drafts, and any theme packs
 * live in the signed index, unioned by mergeThemeRows so nothing is hidden. The
 * Product ID column is the Play SKU, and the Listed switch is the storefront
 * on/off. Bundled rows are always available, so their switch is disabled.
 */

const BUNDLED_ICON_PACKS = [
  { id: 'simple-icons', name: 'Simple Icons', type: 'brand' },
  { id: 'yaru', name: 'Yaru', type: 'hero' },
];

function tagTone(tag: string): Tone {
  if (tag === 'Paid') return 'accent';
  if (tag === 'Bundled') return 'info';
  if (tag.startsWith('Live')) return 'ok';
  if (tag === 'Draft ahead' || tag.startsWith('Seed')) return 'warn';
  return 'plain';
}

export default async function ThemesPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  const [drafts, live, listing] = await Promise.all([
    ensureSeeded(appId),
    readLiveIndex(appId),
    readListing(appId),
  ]);
  const rows = mergeThemeRows(drafts, live);

  const livePackIds = new Set(BUNDLED_ICON_PACKS.map((p) => p.id));
  const iconRows = [
    ...BUNDLED_ICON_PACKS.map((p) => ({
      id: p.id,
      name: p.name,
      type: p.type,
      sku: null as string | null,
      bundled: true,
      version: null as number | null,
    })),
    ...live.packs
      .filter((p) => (p.packType === 'hero' || p.packType === 'brand' || p.packType === 'icon') && !livePackIds.has(p.packId))
      .map((p) => ({
        id: p.packId,
        name: p.title || p.packId,
        type: p.packType,
        sku: p.sku ?? null,
        bundled: false,
        version: p.version,
      })),
  ];

  return (
    <Shell app={appId}>
      <PageHead
        title="Themes & packs"
        meta={`${rows.length} themes · ${iconRows.length} packs`}
        actions={
          /* /themes/builder is gone. A theme and a distro were always the same
             artifact: a distro is a theme plus an optional icon pack plus
             optional SKUs, so the workspace is the superset, and two editors
             for one file was two places for the schema to drift.

             This page stays as the INVENTORY. One list, one editor. */
          <Button href={`/apps/${appId}/distros/builder`} variant="primary">
            New distro
          </Button>
        }
      />

      <Card title="Themes" flush>
        <Table
          head={
            <>
              <Th>Name</Th>
              <Th>Product ID</Th>
              <Th>Status</Th>
              <Th num>Version</Th>
              <Th>Listed</Th>
              <Th />
            </>
          }
        >
          {rows.map((r) => (
            <Tr key={r.id}>
              <Td>
                <span className="block">{r.title || r.id}</span>
                <span className="block font-mono text-micro text-ink-3">{r.id}</span>
              </Td>
              <Td mono dim>
                {r.sku ?? 'free'}
              </Td>
              <Td>
                <span className="flex flex-wrap gap-1">
                  {r.tags.map((t) => (
                    <Chip key={t} tone={tagTone(t)}>
                      {t}
                    </Chip>
                  ))}
                </span>
              </Td>
              <Td num>{r.publishedVersion ?? r.draftVersion ?? '-'}</Td>
              <Td>
                <ListToggle app={appId} packId={r.id} initial={isListed(listing, r.id)} disabled={r.bundled} />
              </Td>
              <Td num>
                <Button href={`/apps/${appId}/distros/builder?id=${r.id}`}>Edit</Button>
              </Td>
            </Tr>
          ))}
        </Table>
      </Card>

      <div className="mt-3 sm:mt-4">
        <Card title="Icon & brand packs" flush>
          <Table
            head={
              <>
                <Th>Name</Th>
                <Th>Product ID</Th>
                <Th>Type</Th>
                <Th>Status</Th>
                <Th>Listed</Th>
              </>
            }
          >
            {iconRows.map((p) => (
              <Tr key={p.id}>
                <Td>
                  <span className="block">{p.name}</span>
                  <span className="block font-mono text-micro text-ink-3">{p.id}</span>
                </Td>
                <Td mono dim>
                  {p.sku ?? 'free'}
                </Td>
                <Td mono dim>
                  {p.type}
                </Td>
                <Td>
                  {p.bundled ? (
                    <Chip tone="info">Bundled</Chip>
                  ) : (
                    <Chip tone="ok">Live v{p.version}</Chip>
                  )}
                </Td>
                <Td>
                  <ListToggle app={appId} packId={p.id} initial={isListed(listing, p.id)} disabled={p.bundled} />
                </Td>
              </Tr>
            ))}
          </Table>
        </Card>
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        Product ID is the Play SKU. Paid distros appear here once you build them in the distro workspace, which sets
        their SKUs. Listed is the storefront switch; bundled packs ship in the APK and are always available. To pull a
        live CDN pack from every device, use Unpublish on the Packs screen.
      </p>
    </Shell>
  );
}
