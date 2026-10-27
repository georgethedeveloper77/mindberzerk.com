'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { SoftPanel } from '@/components/studio/ui';
import type { BrokerSettings, BrokerSummary } from '@/lib/g-vpn/gservers';

import { SaveBar, Segmented, SettingRow, Stepper, Switch } from './controls';

/**
 * The Oracle switch and the phone rules for G Servers: on or off for every
 * phone, who may use them, phones per plan, and how long an unused phone
 * keeps its place. Saved to the G Servers broker; phones see it within a minute.
 */
export function GServersSwitch({ summary, error }: { summary: BrokerSummary | null; error: string | null }) {
  const router = useRouter();
  const [saved, setSaved] = useState<BrokerSettings | null>(summary?.settings ?? null);
  const [s, setS] = useState<BrokerSettings | null>(summary?.settings ?? null);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; message: string } | null>(null);

  if (!s || !saved) {
    return (
      <SoftPanel title="G Servers" note="Oracle">
        <p className="text-[13px] leading-relaxed text-site-bad">{error ?? 'The broker is not set up yet.'}</p>
        <p className="mt-2 font-mono text-[11.5px] text-site-ink-3">bash backend/gvpn-gservers/setup.sh &lt;ip&gt; &quot;&lt;name&gt;&quot; &lt;city&gt; &lt;CC&gt;</p>
      </SoftPanel>
    );
  }

  const dirty = JSON.stringify(s) !== JSON.stringify(saved);
  const set = (patch: Partial<BrokerSettings>) => {
    setNote(null);
    setS({ ...s, ...patch });
  };

  const save = async () => {
    setBusy(true);
    setNote(null);
    try {
      const res = await fetch('/api/g-vpn/gservers', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(s) });
      const body = await res.json();
      if (res.ok) {
        setSaved(body.settings);
        setS(body.settings);
        setNote({ ok: true, message: 'Saved. Phones see it within a minute.' });
        router.refresh();
        setTimeout(() => setNote(null), 4000);
      } else {
        setNote({ ok: false, message: body.error ?? 'Could not save' });
      }
    } finally {
      setBusy(false);
    }
  };

  const phones = summary?.perServer.reduce((n, r) => n + r.phones, 0) ?? 0;

  return (
    <>
      <SoftPanel
        title="G Servers"
        note="Oracle · each phone gets its own key"
        right={
          <span
            className={`rounded-full px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-[0.06em] ${
              saved.enabled ? 'bg-site-ok-soft text-site-ok' : 'bg-site-sunk text-site-ink-3'
            }`}
          >
            {saved.enabled ? 'Live' : 'Off'}
          </span>
        }
      >
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_260px]">
          <div>
            <SettingRow title="G Servers on" hint="Off hides them from every phone; connected phones stay connected until they disconnect.">
              <Switch checked={s.enabled} onChange={(enabled) => set({ enabled })} label="G Servers on" />
            </SettingRow>
            <SettingRow
              title="Who can use them"
              hint={s.access === 'pro' ? 'Each phone’s subscription is checked with Google Play.' : 'Any phone with G VPN, free.'}
            >
              <Segmented
                label="Who can use them"
                value={s.access}
                onChange={(access) => set({ access })}
                options={[
                  { value: 'everyone', label: 'Everyone' },
                  { value: 'pro', label: 'Pro only' },
                ]}
              />
            </SettingRow>
            <SettingRow title="Phones per plan" hint="How many phones one subscription (or one free phone’s group) may add.">
              <Stepper value={s.limit} min={1} max={20} onChange={(limit) => set({ limit })} label="phones per plan" />
            </SettingRow>
            <SettingRow title="Remove unused phones after" hint="A phone that has not connected for this long gives its place back.">
              <Stepper value={s.idleDays} min={7} max={365} step={1} onChange={(idleDays) => set({ idleDays })} label="days" suffix="days" />
            </SettingRow>
            <div className="mt-5 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">Abuse limits</div>
            <p className="mt-1 text-[11.5px] leading-relaxed text-site-ink-3">
              Only new phones count; reconnecting never does. Carriers put many people behind one address, so keep the
              per-address limits generous: the daily total is what protects the servers.
            </p>
            <SettingRow title="New phones per address, per minute">
              <Stepper value={s.newPerIpMinute} min={1} max={60} onChange={(newPerIpMinute) => set({ newPerIpMinute })} label="per minute" />
            </SettingRow>
            <SettingRow title="New phones per address, per day">
              <Stepper value={s.newPerIpDay} min={1} max={1000} onChange={(newPerIpDay) => set({ newPerIpDay })} label="per address per day" />
            </SettingRow>
            <SettingRow title="New phones per day, everyone" hint="Past this, new phones wait until tomorrow.">
              <Stepper value={s.newPerDay} min={1} max={100000} step={50} onChange={(newPerDay) => set({ newPerDay })} label="per day" />
            </SettingRow>
            <SettingRow title="Most phones on one server" hint="A full server takes no new phones; existing ones stay.">
              <Stepper value={s.maxPerServer} min={10} max={60000} step={100} onChange={(maxPerServer) => set({ maxPerServer })} label="per server" />
            </SettingRow>
            {s.access === 'pro' && (
              <p className="mt-3 rounded-[12px] bg-site-plan-soft px-3 py-2 text-[12px] leading-relaxed text-site-plan">
                Pro only needs the PLAY_SERVICE_ACCOUNT secret on the broker, or no phone can register.
              </p>
            )}
          </div>

          <div className="grid content-start gap-2.5">
            <div className="rounded-[14px] border border-site-line bg-site-sunk px-4 py-3">
              <div className="text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">Phones now</div>
              <div className="mt-1 font-site-display text-[28px] font-extrabold leading-none text-site-ink">{phones}</div>
              <div className="mt-1 text-[11.5px] text-site-ink-3">
                in {summary?.groups ?? 0} plan{summary?.groups === 1 ? '' : 's'}
              </div>
            </div>
            {summary?.perServer.map((r) => (
              <div key={r.server_id} className="flex items-center justify-between rounded-[12px] border border-site-line px-3 py-2 text-[12.5px]">
                <span className="font-mono text-site-ink-3">{r.server_id}</span>
                <span className="font-semibold text-site-ink">
                  {r.phones} phone{r.phones === 1 ? '' : 's'}
                </span>
              </div>
            ))}
          </div>
        </div>
      </SoftPanel>
      <SaveBar dirty={dirty} busy={busy} note={note} onSave={save} onDiscard={() => setS(saved)} saveLabel="Save" />
    </>
  );
}
