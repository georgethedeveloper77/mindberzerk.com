import Link from 'next/link';

import { StudioShell } from '@/components/studio/shell';
import { AppSlab, Bar, KVRow, SlabButton, SlabCell, SoftPanel } from '@/components/studio/ui';
import {
  exportState,
  toolUsage,
  vpnActivation,
  vpnConnections,
  vpnCountries,
  vpnFailures,
  type Analytics,
} from '@/lib/core/analytics';
import { appMeta, appName } from '@/lib/core/registry';
import { readIsps } from '@/lib/g-vpn/isps';
import { readVpnState } from '@/lib/g-vpn/servers';

const APP_ID = 'g-vpn';

/** G VPN's own Firebase project, separate from the shared one. */
const FIREBASE = 'https://console.firebase.google.com/project/gvpn-9bc4c/analytics';

const KIND: Record<string, string> = { free: 'Free', gserver: 'G Server', own: 'Own server' };
const PROTOCOL: Record<string, string> = { openvpn: 'OpenVPN', sstp: 'SSTP', wireguard: 'WireGuard' };
const FAILURE: Record<string, string> = {
  timeout: 'Server did not answer',
  auth_failed: 'Server refused',
  bad_config: 'Bad server config',
  not_authorized: 'VPN permission not given',
  download: 'Config download failed',
  cancelled: 'Cancelled',
  replaced: 'Replaced by another connect',
  busy: 'Permission dialog already open',
};
const TOOL: Record<string, string> = {
  network: 'This network',
  speed: 'Speed test',
  ping: 'Ping',
  status: 'Service status',
  traceroute: 'Traceroute',
  devices: 'Devices',
  router: 'Router check',
  ports: 'Open ports',
  wifi: 'Wi-Fi scanner',
  wake_on_lan: 'Wake on LAN',
};

function NotConnected({ reason }: { reason: string }) {
  return <p className="text-[12.5px] leading-relaxed text-site-ink-3">{reason}</p>;
}

/** A ranked list of bars, or the reason there is none. */
function Ranked({
  result,
  label,
  empty,
  colour = 'var(--color-site-accent)',
}: {
  result: Analytics<{ label: string; count: number; users: number }[]>;
  label: (key: string) => string;
  empty: string;
  colour?: string;
}) {
  if (!result.connected) return <NotConnected reason={result.reason} />;
  if (result.data.length === 0) return <NotConnected reason={empty} />;
  const top = Math.max(...result.data.map((r) => r.count), 1);
  return (
    <div>
      {result.data.map((r) => (
        <Bar
          key={r.label}
          label={label(r.label)}
          value={`${r.count.toLocaleString()} · ${r.users.toLocaleString()} people`}
          pct={(r.count / top) * 100}
          colour={colour}
        />
      ))}
    </div>
  );
}

/**
 * G VPN ANALYTICS.
 *
 * From the BigQuery export (G VPN's own Firebase project): connections by
 * kind and protocol, where free users connect, why connections fail, which
 * tools are used, and whether connecting on day one brings people back.
 * From the Workers: free servers offered and speed tests. Active users and
 * retention curves stay in the Firebase console, which renders them well.
 */
export async function VpnAnalytics({ days }: { days: number }) {
  const [state, connections, countries, failures, tools, activation, vpn, isps] = await Promise.all([
    exportState(APP_ID),
    vpnConnections(APP_ID, days),
    vpnCountries(APP_ID, days),
    vpnFailures(APP_ID, days),
    toolUsage(APP_ID, days),
    vpnActivation(APP_ID),
    readVpnState(),
    readIsps(),
  ]);
  const meta = appMeta(APP_ID);
  const listed = vpn.servers.filter((s) => s.listed);

  const totals = connections.connected
    ? connections.data.reduce((t, r) => ({ ok: t.ok + r.ok, failed: t.failed + r.failed }), { ok: 0, failed: 0 })
    : null;
  const successRate = totals && totals.ok + totals.failed > 0 ? Math.round((totals.ok / (totals.ok + totals.failed)) * 100) : null;
  const activated = activation.connected ? activation.data.find((r) => r.connectedFirstDay) : undefined;
  const notActivated = activation.connected ? activation.data.find((r) => !r.connectedFirstDay) : undefined;
  const rate = (r?: { users: number; back: number }) => (r && r.users > 0 ? Math.round((r.back / r.users) * 100) : null);

  return (
    <StudioShell app={APP_ID}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(APP_ID)}
        title="Analytics"
        meta={`last ${days} days`}
        actions={
          <SlabButton href={FIREBASE} external>
            Users in Firebase
          </SlabButton>
        }
        metrics={
          <>
            <SlabCell
              label="Connections"
              value={totals ? totals.ok.toLocaleString() : 'not connected'}
              measured={Boolean(totals)}
              note={totals ? `${totals.failed.toLocaleString()} failed` : 'export off'}
            />
            <SlabCell
              label="Success rate"
              value={successRate === null ? 'none yet' : `${successRate}%`}
              measured={successRate !== null}
              note="connects that worked"
            />
            <SlabCell
              label="Back in week 2"
              value={rate(activated) === null ? 'none yet' : `${rate(activated)}%`}
              measured={rate(activated) !== null}
              note={rate(notActivated) === null ? 'connected on day one' : `vs ${rate(notActivated)}% who did not connect`}
            />
            <SlabCell
              label="Free servers"
              value={vpn.unreachable ? 'unknown' : listed.length}
              measured={!vpn.unreachable}
              note="at the last refresh"
            />
          </>
        }
      />

      <div className="flex flex-wrap items-center gap-2">
        {[7, 30, 90].map((d) => (
          <Link
            key={d}
            href={`/apps/${APP_ID}/analytics?days=${d}`}
            className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition ${
              days === d
                ? 'border-site-accent/30 bg-site-accent-soft text-site-accent-deep'
                : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
            }`}
          >
            {d}d
          </Link>
        ))}
        <span className="ml-1 text-[11.5px] text-site-ink-3">The free BigQuery sandbox keeps 60 days.</span>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <SoftPanel title="Connections" note="by kind of server and protocol">
          {!connections.connected ? (
            <NotConnected reason={connections.reason} />
          ) : connections.data.length === 0 ? (
            <NotConnected reason="No connections logged yet. They arrive with the version that logs them." />
          ) : (
            connections.data.map((r) => {
              const all = r.ok + r.failed;
              const pct = all ? (r.ok / all) * 100 : 0;
              return (
                <Bar
                  key={`${r.kind}-${r.protocol}`}
                  label={`${KIND[r.kind] ?? r.kind} · ${PROTOCOL[r.protocol] ?? r.protocol}`}
                  value={`${Math.round(pct)}% of ${all.toLocaleString()}`}
                  pct={pct}
                  colour={pct >= 80 ? 'var(--color-site-ok)' : pct >= 50 ? 'var(--color-site-plan)' : 'var(--color-site-bad)'}
                />
              );
            })
          )}
        </SoftPanel>

        <SoftPanel title="Why connections fail" note="most common first">
          <Ranked
            result={failures}
            label={(k) => FAILURE[k] ?? k}
            empty="No failed connections logged."
            colour="var(--color-site-bad)"
          />
        </SoftPanel>

        <SoftPanel title="Where free users connect" note="server country">
          <Ranked result={countries} label={(k) => k} empty="No free-server connections logged yet." />
        </SoftPanel>

        <SoftPanel title="Tools" note="opens and people">
          <Ranked result={tools} label={(k) => TOOL[k] ?? k} empty="No tools opened yet." colour="var(--color-site-ok)" />
        </SoftPanel>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <SoftPanel title="Day one and coming back" note="new users 14 to 37 days ago">
          {!activation.connected ? (
            <NotConnected reason={activation.reason} />
          ) : (
            <>
              <KVRow
                k="Connected on day one"
                v={activated ? `${rate(activated)}% back in week 2 (${activated.back} of ${activated.users})` : 'no one yet'}
              />
              <KVRow
                k="Did not connect on day one"
                v={notActivated ? `${rate(notActivated)}% back in week 2 (${notActivated.back} of ${notActivated.users})` : 'no one yet'}
              />
              <p className="mt-3 text-[12px] leading-relaxed text-site-ink-3">
                A large gap means getting people connected on their first day is the thing to improve.
              </p>
            </>
          )}
        </SoftPanel>

        <SoftPanel title="Export and Workers" note="where these numbers come from">
          <KVRow
            k="BigQuery export"
            v={state.connected ? `${state.data.days} daily tables` : 'not connected'}
            tone={state.connected ? 'ok' : 'bad'}
          />
          <KVRow k="Speed tests shared" v={isps.unreachable ? 'unknown' : `${isps.totalTests} in ${isps.countries.length} countries`} />
          <KVRow k="Free servers listed" v={vpn.unreachable ? 'unknown' : `${listed.length} of ${vpn.servers.length}`} />
          {!state.connected && <p className="mt-3 text-[12px] leading-relaxed text-site-ink-3">{state.reason}</p>}
        </SoftPanel>
      </div>

      <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
        Data safety: Firebase shares a pseudonymous app instance id with Google, and the events say which kind of server
        and protocol was used, never what anyone did online. The accurate claim: no account, no ads, no sale of data, no
        browsing history.
      </p>
    </StudioShell>
  );
}
