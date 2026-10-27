import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { ProvidersAdmin } from '@/components/g-vpn/ProvidersAdmin';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabCell } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readProviders } from '@/lib/g-vpn/providers';

export const dynamic = 'force-dynamic';

/**
 * G VPN only: the internet providers phones have met, with their ratings,
 * and the brand details the app shows for each (name, colour, logo, help
 * links). Speeds stay on the ISPs page; this page is about who they are.
 */
export default async function ProvidersPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();

  const state = await readProviders();
  const meta = appMeta(app);
  const down = state.unreachable != null;
  const shown = state.providers.filter((p) => !p.hidden);
  const ratings = state.providers.reduce((n, p) => n + p.ratings, 0);
  const users = shown.reduce((n, p) => n + p.users, 0);
  const setUp = shown.filter((p) => p.name).length;

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(app)}
        title="Providers"
        meta={down ? `Worker unreachable: ${state.unreachable}` : 'ratings from the last 12 months'}
        metrics={
          <>
            <SlabCell label="Providers" value={down ? 'unknown' : shown.length} measured={!down} note={`${setUp} set up`} />
            <SlabCell label="Users" value={down ? 'unknown' : users} measured={!down} note="installs, this month and last" />
            <SlabCell label="Ratings" value={down ? 'unknown' : ratings} measured={!down} note="one per phone a month" />
            <SlabCell
              label="Countries"
              value={down ? 'unknown' : new Set(shown.map((p) => p.country ?? '')).size}
              measured={!down}
            />
          </>
        }
      />
      {!down && <ProvidersAdmin providers={state.providers} />}
    </StudioShell>
  );
}
