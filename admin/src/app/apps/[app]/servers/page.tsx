import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { ServersAdmin } from '@/components/g-vpn/ServersAdmin';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readVpnState } from '@/lib/g-vpn/servers';

export const dynamic = 'force-dynamic';

/** G VPN only: the Community list, steered through the Worker's overrides. */
export default async function ServersPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();

  const state = await readVpnState();
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(app)}
        title="Servers"
        meta={state.unreachable ? `Worker unreachable: ${state.unreachable}` : `refreshed ${state.updatedAt ?? 'never'}`}
        actions={<SlabButton href={`/apps/${app}/sources`}>Sources</SlabButton>}
      />
      {state.unreachable ? (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The server Worker could not be read, so there is nothing to show or steer. {state.unreachable}
        </p>
      ) : (
        <ServersAdmin servers={state.servers} initial={state.overrides} />
      )}
    </StudioShell>
  );
}
