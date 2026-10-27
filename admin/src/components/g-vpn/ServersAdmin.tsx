'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import type { AdminServer, Overrides } from '@/lib/g-vpn/servers';

import { saveAndRefresh } from './save';

/**
 * EVERY SERVER THE SOURCES OFFERED, AND WHAT THE APP SHOWS OF THEM.
 *
 * The panel never edits the list; it edits overrides (pin, hide, boost) and
 * the Worker applies them on every refresh. So this table previews the
 * effect (quality and grade move as you boost) and Save publishes it with an
 * immediate refresh.
 *
 * "Not listed" without "hidden" means the Worker dropped it: unreachable, or
 * beyond the per-country cap. Those are facts about the server, not choices,
 * and they are labelled so the two are never confused.
 */
type Show = 'listed' | 'all' | 'hidden' | 'dropped';

export function ServersAdmin({ servers, initial }: { servers: AdminServer[]; initial: Overrides }) {
  const router = useRouter();
  const [o, setO] = useState<Overrides>(initial);
  const [query, setQuery] = useState('');
  const [source, setSource] = useState<'all' | 'vpngate' | 'oneconnect'>('all');
  const [show, setShow] = useState<Show>('listed');
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; message: string } | null>(null);

  const dirty = JSON.stringify(o) !== JSON.stringify(initial);
  const pinned = new Set(o.pinnedServers);
  const hidden = new Set(o.hiddenServers);
  const hiddenCc = new Set(o.hiddenCountries);

  const toggle = (key: 'pinnedServers' | 'hiddenServers', id: string) =>
    setO((p) => ({
      ...p,
      [key]: p[key].includes(id) ? p[key].filter((x) => x !== id) : [...p[key], id],
    }));

  const boost = (id: string, by: number) =>
    setO((p) => {
      const next = Math.max(-50, Math.min(50, (p.boosts[id] ?? 0) + by));
      const boosts = { ...p.boosts };
      if (next === 0) delete boosts[id];
      else boosts[id] = next;
      return { ...p, boosts };
    });

  // The Worker reports quality WITH the saved boost; preview the unsaved one.
  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    return servers
      .map((s) => {
        const base = s.quality - (initial.boosts[s.id] ?? 0);
        const quality = Math.max(0, Math.min(100, base + (o.boosts[s.id] ?? 0)));
        const grade = quality >= o.thresholds.fast ? 'fast' : quality >= o.thresholds.good ? 'good' : 'slow';
        const isHidden = hidden.has(s.id) || hiddenCc.has(s.countryCode);
        return { ...s, quality, grade, isHidden, isPinned: pinned.has(s.id) };
      })
      .filter((s) => source === 'all' || s.source === source)
      .filter((s) => !q || `${s.country} ${s.countryCode} ${s.ip} ${s.host}`.toLowerCase().includes(q))
      .filter((s) =>
        show === 'all'
          ? true
          : show === 'listed'
            ? s.listed && !s.isHidden
            : show === 'hidden'
              ? s.isHidden
              : !s.listed && !s.isHidden,
      )
      .sort((a, b) => Number(b.isPinned) - Number(a.isPinned) || b.quality - a.quality);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [servers, o, initial, query, source, show]);

  async function run(save: boolean) {
    setBusy(true);
    setNote(null);
    const result = await saveAndRefresh(save ? o : undefined);
    setNote(result);
    setBusy(false);
    if (result.ok) router.refresh();
  }

  const chip = 'rounded-lg border px-2.5 py-1 text-[12px] font-semibold transition';
  const on = 'border-site-accent bg-site-accent-soft text-site-accent-deep';
  const off = 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink';

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Country, code or address"
          className="w-[240px] rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-[13px] text-site-ink outline-none focus:border-site-accent"
        />
        {(['listed', 'all', 'hidden', 'dropped'] as Show[]).map((v) => (
          <button key={v} type="button" onClick={() => setShow(v)} className={`${chip} ${show === v ? on : off}`}>
            {v === 'dropped' ? 'dropped by Worker' : v}
          </button>
        ))}
        <span className="mx-1 h-5 w-px bg-site-line" />
        {(['all', 'vpngate', 'oneconnect'] as const).map((v) => (
          <button key={v} type="button" onClick={() => setSource(v)} className={`${chip} ${source === v ? on : off}`}>
            {v === 'vpngate' ? 'VPN Gate' : v === 'oneconnect' ? 'OneConnect' : 'every source'}
          </button>
        ))}
        <div className="ml-auto flex items-center gap-2">
          {note && (
            <span className={`text-[12px] font-semibold ${note.ok ? 'text-site-ok' : 'text-site-bad'}`}>{note.message}</span>
          )}
          <button
            type="button"
            disabled={busy}
            onClick={() => run(false)}
            className={`${chip} ${off} disabled:opacity-50`}
          >
            Refresh now
          </button>
          <button
            type="button"
            disabled={busy || !dirty}
            onClick={() => run(true)}
            className="rounded-lg border border-site-accent bg-site-accent px-3 py-1.5 text-[12px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
          >
            {busy ? 'Publishing' : 'Save and publish'}
          </button>
        </div>
      </div>

      <div className="overflow-x-auto rounded-[18px] border border-site-line bg-site-card">
        <table className="w-full min-w-[920px] text-left text-[12.5px]">
          <thead>
            <tr className="border-b border-site-line text-[10.5px] uppercase tracking-[0.08em] text-site-ink-3">
              <th className="px-4 py-2.5">Server</th>
              <th className="px-2 py-2.5">Source</th>
              <th className="px-2 py-2.5 text-right">Mbps</th>
              <th className="px-2 py-2.5 text-right">Ping</th>
              <th className="px-2 py-2.5 text-right">Quality</th>
              <th className="px-2 py-2.5">Grade</th>
              <th className="px-2 py-2.5">Status</th>
              <th className="px-4 py-2.5 text-right">Steer</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((s) => {
              const b = o.boosts[s.id] ?? 0;
              const status = s.isHidden
                ? { t: hiddenCc.has(s.countryCode) ? 'country hidden' : 'hidden', c: 'text-site-ink-3' }
                : s.listed
                  ? { t: 'listed', c: 'text-site-ok' }
                  : s.reachable === false
                    ? { t: 'unreachable', c: 'text-site-bad' }
                    : { t: 'over country cap', c: 'text-site-ink-3' };
              const gradeColour = { fast: 'text-site-ok', good: 'text-site-accent-deep', slow: 'text-site-plan' }[s.grade];
              return (
                <tr key={s.id} className={`border-b border-site-line last:border-b-0 ${s.isHidden ? 'opacity-55' : ''}`}>
                  <td className="px-4 py-2.5">
                    <div className="font-semibold text-site-ink">
                      {s.isPinned && <span className="mr-1.5 text-site-accent">●</span>}
                      {s.country} <span className="font-mono text-[11px] text-site-ink-3">{s.countryCode}</span>
                    </div>
                    <div className="font-mono text-[11px] text-site-ink-3">
                      {s.sstpHost ? `SSTP ${s.sstpHost}:${s.sstpPort ?? 443}` : `OpenVPN ${s.ip}:${s.port} ${s.proto.toUpperCase()}`}
                    </div>
                  </td>
                  <td className="px-2 py-2.5 text-site-ink-2">{s.source === 'oneconnect' ? 'OneConnect' : 'VPN Gate'}</td>
                  <td className="px-2 py-2.5 text-right font-mono">{s.speedMbps ? s.speedMbps : ''}</td>
                  <td className="px-2 py-2.5 text-right font-mono">{s.pingMs ? `${s.pingMs}ms` : ''}</td>
                  <td className="px-2 py-2.5 text-right font-mono">
                    {s.quality}
                    {b !== 0 && <span className="ml-1 text-[11px] text-site-accent-deep">{b > 0 ? `+${b}` : b}</span>}
                  </td>
                  <td className={`px-2 py-2.5 font-bold uppercase ${gradeColour}`}>{s.grade}</td>
                  <td className={`px-2 py-2.5 font-semibold ${status.c}`}>{status.t}</td>
                  <td className="px-4 py-2.5">
                    <div className="flex justify-end gap-1.5">
                      <button type="button" onClick={() => boost(s.id, -10)} className={`${chip} ${off}`} title="Lower quality by 10">
                        −10
                      </button>
                      <button type="button" onClick={() => boost(s.id, 10)} className={`${chip} ${off}`} title="Raise quality by 10">
                        +10
                      </button>
                      <button type="button" onClick={() => toggle('pinnedServers', s.id)} className={`${chip} ${s.isPinned ? on : off}`}>
                        Pin
                      </button>
                      <button type="button" onClick={() => toggle('hiddenServers', s.id)} className={`${chip} ${hidden.has(s.id) ? on : off}`}>
                        Hide
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {rows.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-site-ink-3">
                  No servers match.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
