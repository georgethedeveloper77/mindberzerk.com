'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { KVRow, SoftPanel } from '@/components/studio/ui';
import type { AdminServer, Overrides, SourceHealth } from '@/lib/g-vpn/servers';

import { saveAndRefresh } from './save';

/**
 * WHERE THE LIST COMES FROM, AND THE RULES APPLIED TO ALL OF IT.
 *
 * Sources on or off, the two grade thresholds, and whole countries hidden
 * (a country can be hidden for a reason no single server shows: a blocked
 * region, a legal concern). Per-server steering lives on Servers.
 *
 * The OneConnect key is NOT editable here. It is a Worker secret, set with
 * Wrangler, so it never passes through this panel or its database.
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
    if (r.ok) router.refresh();
  }

  const toggleCountry = (cc: string) =>
    setO((p) => ({
      ...p,
      hiddenCountries: p.hiddenCountries.includes(cc)
        ? p.hiddenCountries.filter((x) => x !== cc)
        : [...p.hiddenCountries, cc],
    }));

  const health = (s?: SourceHealth) =>
    !s ? 'not read yet' : s.off ? 'off' : !s.ok ? s.error ?? 'failed' : `${s.count ?? 0} servers${s.skipped ? `, ${s.skipped} unreadable` : ''}`;

  const toggle = (on: boolean, flip: () => void, label: string) => (
    <button
      type="button"
      onClick={flip}
      aria-pressed={on}
      className={`rounded-lg border px-3 py-1 text-[12px] font-semibold ${
        on ? 'border-site-accent bg-site-accent-soft text-site-accent-deep' : 'border-site-line bg-site-card text-site-ink-3'
      }`}
    >
      {on ? `${label} on` : `${label} off`}
    </button>
  );

  const field =
    'w-[72px] rounded-lg border border-site-line bg-site-card px-2 py-1 text-right font-mono text-[13px] text-site-ink outline-none focus:border-site-accent';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3">
        {note && <span className={`text-[12px] font-semibold ${note.ok ? 'text-site-ok' : 'text-site-bad'}`}>{note.message}</span>}
        <button
          type="button"
          disabled={busy || !dirty}
          onClick={publish}
          className="ml-auto rounded-lg border border-site-accent bg-site-accent px-3 py-1.5 text-[12px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
        >
          {busy ? 'Publishing' : 'Save and publish'}
        </button>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <SoftPanel title="Sources">
          <KVRow
            k="VPN Gate"
            v={toggle(o.sources.vpngate, () => setO((p) => ({ ...p, sources: { ...p.sources, vpngate: !p.sources.vpngate } })), 'VPN Gate')}
          />
          <KVRow k="Last refresh" v={health(sources.vpngate)} tone={sources.vpngate && !sources.vpngate.ok ? 'bad' : undefined} />
          <KVRow
            k="OneConnect"
            v={toggle(o.sources.oneconnect, () => setO((p) => ({ ...p, sources: { ...p.sources, oneconnect: !p.sources.oneconnect } })), 'OneConnect')}
          />
          <KVRow
            k="Last refresh"
            v={oneconnectKey ? health(sources.oneconnect) : 'no key set'}
            tone={!oneconnectKey || (sources.oneconnect && !sources.oneconnect.ok) ? 'bad' : undefined}
          />
          {!oneconnectKey && (
            <p className="mt-3 font-mono text-[11.5px] leading-relaxed text-site-ink-3">
              cd backend/gvpn-servers && npx wrangler secret put ONECONNECT_KEY
            </p>
          )}
        </SoftPanel>

        <SoftPanel title="Grades" note="quality score, 0 to 100">
          <KVRow
            k="Fast from"
            v={
              <input
                type="number"
                className={field}
                value={o.thresholds.fast}
                onChange={(e) => setO((p) => ({ ...p, thresholds: { ...p.thresholds, fast: Number(e.target.value) } }))}
              />
            }
          />
          <KVRow
            k="Good from"
            v={
              <input
                type="number"
                className={field}
                value={o.thresholds.good}
                onChange={(e) => setO((p) => ({ ...p, thresholds: { ...p.thresholds, good: Number(e.target.value) } }))}
              />
            }
          />
          <KVRow k="OneConnect starts at" v="60 (no speed data)" />
        </SoftPanel>
      </div>

      <SoftPanel title="Countries" note="hide a whole country from the app" flush>
        <div className="grid sm:grid-cols-2 lg:grid-cols-3">
          {countries.map(([cc, c]) => {
            const isHidden = o.hiddenCountries.includes(cc);
            return (
              <button
                key={cc}
                type="button"
                onClick={() => toggleCountry(cc)}
                className={`flex items-center justify-between border-b border-r border-site-line px-[18px] py-2.5 text-left text-[12.5px] ${
                  isHidden ? 'bg-site-sunk text-site-ink-3' : 'text-site-ink'
                }`}
              >
                <span>
                  <span className="font-semibold">{c.name}</span>{' '}
                  <span className="font-mono text-[11px] text-site-ink-3">{cc}</span>
                </span>
                <span className="font-mono text-[11px]">{isHidden ? 'hidden' : `${c.listed}/${c.total}`}</span>
              </button>
            );
          })}
        </div>
      </SoftPanel>
    </div>
  );
}
