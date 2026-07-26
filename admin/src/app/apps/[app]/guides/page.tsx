import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { Card, Chip, Empty, Grid, PageHead, Stat, Table, Td, Th, Tr } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C13 - G Recovery, PLACEHOLDER ONLY.
 *
 * Pure design, no functionality. Nothing here reads a bucket or writes anything;
 * every number is a dash and every row is illustrative. It exists so opening
 * G Recovery shows the SHAPE of what it will be - per-brand OEM recovery
 * guidance, delivered by remote config to a budget-phone install base - rather
 * than a blank app section.
 *
 * When the app is real, this becomes a reader over whatever store holds the
 * guidance (likely Remote Config keyed by manufacturer), and the static rows
 * below become live. Until then it is a mock, and it says so.
 */
export default async function GuidesPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  // Illustrative only. The real list comes from the install base once the app
  // ships; these are the OEMs G Recovery's traffic actually skews toward.
  const brands = [
    { brand: 'Infinix', share: '26%', guides: '-' },
    { brand: 'Tecno', share: '21%', guides: '-' },
    { brand: 'Xiaomi / Redmi', share: '19%', guides: '-' },
    { brand: 'Samsung', share: '17%', guides: '-' },
    { brand: 'Oppo / realme', share: '9%', guides: '-' },
  ];

  return (
    <Shell app={app} subtitle={`${app} / guides`}>
      <PageHead
        title={`${appName(app)} guides`}
        meta="placeholder"
        actions={<Chip tone="warn">design only</Chip>}
      />

      <Grid cols={4}>
        <Stat label="Brands covered" value="-" />
        <Stat label="Guides published" value="-" />
        <Stat label="Delivery" value="remote config" />
        <Stat label="State" value="not built" tone="warn" />
      </Grid>

      <div className="mt-3 sm:mt-4">
        <Card title="Per-brand recovery guidance" flush>
          <Table
            head={
              <>
                <Th>Manufacturer</Th>
                <Th num>Install share</Th>
                <Th num>Guides</Th>
                <Th>State</Th>
              </>
            }
          >
            {brands.map((b) => (
              <Tr key={b.brand}>
                <Td>{b.brand}</Td>
                <Td num dim>
                  {b.share}
                </Td>
                <Td num dim>
                  {b.guides}
                </Td>
                <Td>
                  <Chip>planned</Chip>
                </Td>
              </Tr>
            ))}
          </Table>
        </Card>
      </div>

      <div className="mt-3 sm:mt-4">
        <Empty>
          G Recovery is not built yet. This section shows the intended shape:
          honestly-scoped recovery, storage auditing, and per-brand OEM guidance
          delivered by remote config. Nothing here is wired.
        </Empty>
      </div>
    </Shell>
  );
}
