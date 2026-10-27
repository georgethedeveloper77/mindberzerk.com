'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { SoftPanel } from '@/components/studio/ui';
import type { AdminServer, Overrides, SourceHealth } from '@/lib/g-vpn/servers';

import { SaveBar, SettingRow, Stepper, Switch } from './controls';
import { saveAndRefresh } from './save';

/**
 * WHERE THE FREE LIST COMES FROM, AND THE RULES APPLIED TO ALL OF IT.
 *
 * Sources and protocols on or off, the two grade thresholds, and whole
 * countries hidden. Per-server steering lives on Servers. The OneConnect key
 * is a Worker secret, set with Wrangler, so it never passes through here.
 */
export function SourcesAdmin({
  servers,
  sources,
  initial,
  oneconnectKey,
}: {
  servers: AdminServer[];
  sources: Partial<Record<'vpngate' | 'oneconnect', SourceHealth>>;
  initial: Overrides;
  oneconnectKey: boolean;
}) {
  const router = useRouter();
  const [o, setO] = useState<Overrides>(initial);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; message: string } | null>(null);
  const dirty = JSON.stringify(o) !== JSON.stringify(initial);

  const countries = useMemo(() => {
    const m = new Map<string, { name: string; total: number; listed: number }>();
    for (const s of servers) {
      const c = m.get(s.countryCode) ?? { name: s.country, total: 0, listed: 0 };
      c.total++;
      if (s.listed) c.listed++;
      m.set(s.countryCode, c);
    }
    return [...m.entries()].sort((a, b) => b[1].total - a[1].total);
  }, [servers]);

  async function publish() {
    setBusy(true);
    setNote(null);
    const r = await saveAndRefresh(o);
    setNote(r);
    setBusy(false);
    if (r.ok) {
      router.refresh();
      setTimeout(() => setNote(null), 4000);
    }
  }

  const update = (fn: (p: Overrides) => Overrides) => {
    setNote(null);
    setO(fn);
  };

  const status = (s: SourceHealth | undefined, keyMissing = false) => {
    if (keyMissing) return <Health tone="bad" text="No key set" />;
    if (!s) return <Health tone="muted" text="Not read yet" />;
    if (s.off) return <Health tone="muted" text="Off" />;
    if (!s.ok) return <Health tone="bad" text={s.error ?? 'Failed'} />;
    return <Health tone="ok" text={`${s.count ?? 0} servers${s.skipped ? ` · ${s.skipped} unreadable` : ''}`} />;
  };

  const sstp = sources.vpngate;

  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <SoftPanel title="Sources" note="where free servers come from">
          <SettingRow title="VPN Gate" hint="Volunteer servers from the University of Tsukuba project.">
            <Switch
              checked={o.sources.vpngate}
              onChange={(v) => update((p) => ({ ...p, sources: { ...p.sources, vpngate: v } }))}
              label="VPN Gate"
            />
          </SettingRow>
          <div className="pb-3">{status(sources.vpngate)}</div>
          <SettingRow title="OneConnect" hint="Partner servers, with your OneConnect key.">
            <Switch
              checked={o.sources.oneconnect}
              onChange={(v) => update((p) => ({ ...p, sources: { ...p.sources, oneconnect: v } }))}
              label="OneConnect"
            />
          </SettingRow>
          <div>{status(sources.oneconnect, !oneconnectKey)}</div>
          {!oneconnectKey && (
            <p className="mt-2 font-mono text-[11px] leading-relaxed text-site-ink-3">
              cd backend/gvpn-servers && npx wrangler secret put ONECONNECT_KEY
            </p>
          )}
        </SoftPanel>

        <SoftPanel title="Protocols" note="how phones connect to free servers">
          <SettingRow title="OpenVPN" hint="Every VPN Gate and OneConnect server.">
            <Switch
              checked={o.protocols.openvpn}
              onChange={(v) =>
                // At least one protocol stays on.
                update((p) => ({ ...p, protocols: { openvpn: v, sstp: v ? p.protocols.sstp : true } }))
              }
              label="OpenVPN"
            />
          </SettingRow>
          <SettingRow title="SSTP" hint="Used where a server offers it; works through strict networks.">
            <Switch
              checked={o.protocols.sstp}
              onChange={(v) => update((p) => ({ ...p, protocols: { sstp: v, openvpn: v ? p.protocols.openvpn : true } }))}
              label="SSTP"
            />
          </SettingRow>
          <div className="pt-1">
            {sstp?.sstpError ? (
              <Health tone="bad" text={sstp.sstpError} />
            ) : (sstp?.sstp ?? 0) > 0 ? (
              <Health tone="ok" text={`${sstp?.sstp} servers offer SSTP`} />
            ) : (
              <Health tone="warn" text="No SSTP addresses found on VPN Gate’s page; phones use OpenVPN" />
            )}
          </div>
        </SoftPanel>

        <SoftPanel title="Grades" note="quality score, 0 to 100">
          <SettingRow title="Fast from" hint="Shown with the Fastest badge and first in the list.">
            <Stepper
              value={o.thresholds.fast}
              min={o.thresholds.good + 1}
              max={100}
              onChange={(fast) => update((p) => ({ ...p, thresholds: { ...p.thresholds, fast } }))}
              label="fast threshold"
            />
          </SettingRow>
          <SettingRow title="Good from" hint="Below this a server is graded slow.">
            <Stepper
              value={o.thresholds.good}
              min={0}
              max={o.thresholds.fast - 1}
              onChange={(good) => update((p) => ({ ...p, thresholds: { ...p.thresholds, good } }))}
              label="good threshold"
            />
          </SettingRow>
          <SettingRow title="OneConnect starts at" hint="They publish no speed data, so they begin here.">
            <span className="font-mono text-[13px] font-semibold text-site-ink">60</span>
          </SettingRow>
        </SoftPanel>
      </div>

      <SoftPanel
        title="Countries"
        note="switch a whole country off in the app"
        right={<span className="text-[11.5px] text-site-ink-3">{o.hiddenCountries.length} hidden</span>}
        flush
      >
        <div className="grid sm:grid-cols-2 lg:grid-cols-3">
          {countries.map(([cc, c]) => {
            const shown = !o.hiddenCountries.includes(cc);
            return (
              <div
                key={cc}
                className={`flex items-center justify-between gap-3 border-b border-r border-site-line px-[18px] py-2.5 ${shown ? '' : 'bg-site-sunk'}`}
              >
                <div className="min-w-0">
                  <div className={`truncate text-[12.5px] font-semibold ${shown ? 'text-site-ink' : 'text-site-ink-3'}`}>
                    {c.name} <span className="font-mono text-[11px] font-normal text-site-ink-3">{cc}</span>
                  </div>
                  <div className="font-mono text-[11px] text-site-ink-3">
                    {c.listed} of {c.total} listed
                  </div>
                </div>
                <Switch
                  checked={shown}
                  onChange={(on) =>
                    update((p) => ({
                      ...p,
                      hiddenCountries: on ? p.hiddenCountries.filter((x) => x !== cc) : [...p.hiddenCountries, cc],
                    }))
                  }
                  label={`Show ${c.name}`}
                />
              </div>
            );
          })}
        </div>
      </SoftPanel>

      <SaveBar dirty={dirty} busy={busy} note={note} onSave={publish} onDiscard={() => setO(initial)} />
    </div>
  );
}

function Health({ tone, text }: { tone: 'ok' | 'warn' | 'bad' | 'muted'; text: string }) {
  const cls = {
    ok: 'bg-site-ok-soft text-site-ok',
    warn: 'bg-site-plan-soft text-site-plan',
    bad: 'bg-site-bad-soft text-site-bad',
    muted: 'bg-site-sunk text-site-ink-3',
  }[tone];
  return <div className={`rounded-[10px] px-3 py-2 text-[12px] font-semibold leading-relaxed ${cls}`}>{text}</div>;
}
