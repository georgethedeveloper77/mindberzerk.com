import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { GServersSwitch } from '@/components/g-vpn/GServersSwitch';
import { SourcesAdmin } from '@/components/g-vpn/SourcesAdmin';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readBroker } from '@/lib/g-vpn/gservers';
import { readVpnState } from '@/lib/g-vpn/servers';

export const dynamic = 'force-dynamic';

function SectionHead({ title, note }: { title: string; note: string }) {
  return (
    <div className="mt-2 flex items-baseline gap-3">
      <h2 className="font-site-display text-[19px] font-extrabold tracking-[-0.02em] text-site-ink">{title}</h2>
      <span className="text-[12.5px] text-site-ink-3">{note}</span>
    </div>
  );
}

/** G VPN only: every switch that decides which servers phones see. */
export default async function SourcesPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();

  const [state, broker] = await Promise.all([readVpnState(), readBroker()]);
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(app)}
        title="Sources"
        meta={state.unreachable ? `Server list unreachable: ${state.unreachable}` : `free list refreshed ${state.updatedAt ?? 'never'}`}
        actions={
          <>
            <SlabButton href={`/apps/${app}/gservers`}>G Servers</SlabButton>
            <SlabButton href={`/apps/${app}/servers`}>Free servers</SlabButton>
          </>
        }
      />

      <SectionHead title="G Servers" note="your own servers on Oracle" />
      {/* Each section holds its own save bar, so the two never overlap. */}
      <div className="flex flex-col gap-4">
        <GServersSwitch summary={broker.summary} error={broker.error} />
      </div>

      <SectionHead title="Free servers" note="VPN Gate and OneConnect" />
      {state.unreachable ? (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The server list could not be read, so there is nothing to show or steer. {state.unreachable}
        </p>
      ) : (
        <SourcesAdmin servers={state.servers} sources={state.sources} initial={state.overrides} oneconnectKey={state.oneconnectKey} />
      )}
    </StudioShell>
  );
}
