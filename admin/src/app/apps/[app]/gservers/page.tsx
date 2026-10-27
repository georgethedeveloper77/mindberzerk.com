import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Gauge, StatusDot } from '@/components/g-vpn/gauge';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton, SlabCell } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readBroker, readGServers, type GServerHealth } from '@/lib/g-vpn/gservers';

export const dynamic = 'force-dynamic';

function bytes(b = 0): string {
  if (b >= 1e12) return `${(b / 1e12).toFixed(1)} TB`;
  if (b >= 1e9) return `${(b / 1e9).toFixed(1)} GB`;
  if (b >= 1e6) return `${(b / 1e6).toFixed(1)} MB`;
  return `${Math.round(b / 1e3)} KB`;
}

function duration(s = 0): string {
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function Tile({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-[14px] border border-site-line bg-site-sunk px-3.5 py-3">
      <div className="text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">{label}</div>
      <div className="mt-1 font-mono text-[15px] font-semibold text-site-ink">{value}</div>
      {sub && <div className="mt-0.5 text-[11px] text-site-ink-3">{sub}</div>}
    </div>
  );
}

function ServerCard({ s }: { s: GServerHealth }) {
  const cpu = s.cpus ? ((s.load1 ?? 0) / s.cpus) * 100 : 0;
  const mem = s.memTotal ? ((s.memTotal - (s.memAvailable ?? 0)) / s.memTotal) * 100 : 0;
  const disk = s.diskTotal ? ((s.diskTotal - (s.diskFree ?? 0)) / s.diskTotal) * 100 : 0;
  return (
    <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
      <header className="flex items-center gap-3 border-b border-site-line px-5 py-4">
        <StatusDot online={s.online} />
        <div className="min-w-0">
          <h2 className="font-site-display text-[17px] font-bold tracking-[-0.015em] text-site-ink">{s.name}</h2>
          <div className="font-mono text-[11.5px] text-site-ink-3">{s.host}</div>
        </div>
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-[0.06em] ${
            s.online ? 'bg-site-ok-soft text-site-ok' : 'bg-site-bad-soft text-site-bad'
          }`}
        >
          {s.online ? 'Online' : 'Offline'}
        </span>
      </header>
      {!s.online ? (
        <p className="px-5 py-5 text-[13px] leading-relaxed text-site-bad">{s.error ?? 'No answer from the agent.'}</p>
      ) : (
        <div className="px-5 py-5">
          <div className="flex justify-around gap-2">
            <Gauge label="CPU" pct={cpu} detail={`${s.cpus} core${s.cpus === 1 ? '' : 's'}`} />
            <Gauge label="Memory" pct={mem} detail={bytes(s.memTotal)} />
            <Gauge label="Disk" pct={disk} detail={bytes(s.diskTotal)} />
          </div>
          <div className="mt-5 grid grid-cols-2 gap-2.5">
            <Tile
              label="Phones"
              value={`${s.peers ?? 0} added`}
              sub={`${s.active ?? 0} active now`}
            />
            <Tile label="Traffic" value={`↓ ${bytes(s.rxBytes)}`} sub={`↑ ${bytes(s.txBytes)} since the agent started`} />
            <Tile
              label="Load"
              value={`${(s.load1 ?? 0).toFixed(2)} · ${(s.load5 ?? 0).toFixed(2)}`}
              sub="1 and 5 minute averages"
            />
            <Tile label="Up" value={duration(s.machineUptimeSeconds)} sub={`agent ${duration(s.uptimeSeconds)}`} />
          </div>
        </div>
      )}
    </section>
  );
}

/**
 * G VPN only: health of every G Server, read live from each server's agent,
 * and the phone rules from the broker. Counts only, never which phones.
 */
export default async function GServersPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();

  const [{ servers, error }, broker] = await Promise.all([readGServers(), readBroker()]);
  const meta = appMeta(app);
  const online = servers.filter((s) => s.online);
  const rules = broker.summary?.settings;

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(app)}
        title="G Servers"
        meta="read live from each server"
        actions={<SlabButton href={`/apps/${app}/sources`}>Settings</SlabButton>}
        metrics={
          <>
            <SlabCell label="Online" value={online.length} of={`of ${servers.length}`} note="servers" />
            <SlabCell
              label="Phones"
              value={online.reduce((n, s) => n + (s.peers ?? 0), 0)}
              note={`${online.reduce((n, s) => n + (s.active ?? 0), 0)} active now`}
            />
            <SlabCell
              label="Traffic"
              value={bytes(online.reduce((n, s) => n + (s.rxBytes ?? 0) + (s.txBytes ?? 0), 0))}
              note="since the agents started"
            />
            <SlabCell
              label="Access"
              value={rules ? (rules.enabled ? (rules.access === 'pro' ? 'Pro' : 'Everyone') : 'Off') : 'unknown'}
              measured={Boolean(rules)}
              note={rules ? `${rules.limit} phones per plan` : broker.error ?? 'broker not set up'}
            />
          </>
        }
      />

      {error && <p className="rounded-[14px] bg-site-bad-soft px-4 py-3 text-[13px] text-site-bad">{error}</p>}

      <div className="grid gap-4 lg:grid-cols-2">
        {servers.map((s) => (
          <ServerCard key={s.host} s={s} />
        ))}
        <section className="flex flex-col justify-center rounded-[18px] border border-dashed border-site-line px-5 py-6">
          <h2 className="font-site-display text-[15px] font-bold text-site-ink">Add a G Server</h2>
          <p className="mt-1 text-[12.5px] leading-relaxed text-site-ink-3">
            Create the machine, install the agent, then add it to the panel and the broker.
          </p>
          <pre className="mt-3 overflow-x-auto rounded-[12px] bg-site-sunk px-3 py-2.5 font-mono text-[11.5px] leading-relaxed text-site-ink-2">
            {`bash backend/gvpn-server/oci-launch.sh 1 6
scp backend/gvpn-server/{install.sh,agent.py,gvpn-peer} ubuntu@IP:
ssh ubuntu@IP 'sudo GVPN_SERVER_NAME="G Server · City" bash install.sh'`}
          </pre>
        </section>
      </div>
    </StudioShell>
  );
}
