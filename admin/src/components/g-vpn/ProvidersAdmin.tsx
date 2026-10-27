'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState, useTransition } from 'react';

import { SoftPanel } from '@/components/studio/ui';
import type { ProviderEdit, ProviderRow } from '@/lib/g-vpn/providers';
import { saveProvider } from '@/lib/g-vpn/providers-actions';

import { SaveBar, SettingRow, Switch } from './controls';

/**
 * Every provider the app has met, by country, most rated first. Open one to
 * set what phones show: its display name, brand colour, logo, and where its
 * customers get help. Hidden providers (hosting, VPNs) cannot be rated.
 */
export function ProvidersAdmin({ providers }: { providers: ProviderRow[] }) {
  const [query, setQuery] = useState('');
  const [showHidden, setShowHidden] = useState(false);
  const [open, setOpen] = useState<number | null>(null);

  const byCountry = useMemo(() => {
    const q = query.trim().toLowerCase();
    const shown = providers.filter(
      (p) =>
        (showHidden || !p.hidden) &&
        (!q || p.org.toLowerCase().includes(q) || (p.name ?? '').toLowerCase().includes(q) || String(p.asn).includes(q)),
    );
    const groups = new Map<string, ProviderRow[]>();
    for (const p of shown) {
      const key = p.country ?? 'Unknown';
      groups.set(key, [...(groups.get(key) ?? []), p]);
    }
    return [...groups].sort((a, b) => b[1].reduce((n, p) => n + p.users, 0) - a[1].reduce((n, p) => n + p.users, 0));
  }, [providers, query, showHidden]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search name or network number"
          aria-label="Search providers"
          className="h-9 min-w-[240px] flex-1 rounded-[10px] border border-site-line bg-site-sunk px-3 text-[13px] text-site-ink outline-none placeholder:text-site-ink-3 focus:border-site-accent"
        />
        <label className="flex items-center gap-2 text-[12.5px] font-semibold text-site-ink-3">
          <Switch checked={showHidden} onChange={setShowHidden} label="Show hidden providers" />
          Show hidden
        </label>
      </div>

      {byCountry.length === 0 && (
        <p className="text-[13px] text-site-ink-3">
          {providers.length === 0
            ? 'No providers yet. They appear as phones open the Internet tab without the VPN.'
            : 'Nothing matches.'}
        </p>
      )}

      {byCountry.map(([country, rows]) => (
        <SoftPanel
          key={country}
          title={country}
          note={`${rows.length} providers · ${rows.reduce((n, p) => n + p.users, 0)} users · ${sum(rows)} ratings`}
          flush
        >
          {rows.map((p) => (
            <ProviderItem key={p.asn} p={p} open={open === p.asn} onToggle={() => setOpen(open === p.asn ? null : p.asn)} />
          ))}
        </SoftPanel>
      ))}
    </div>
  );
}

function sum(rows: ProviderRow[]) {
  return rows.reduce((n, p) => n + p.ratings, 0);
}

function editOf(p: ProviderRow): ProviderEdit {
  return {
    name: p.name ?? '',
    color: p.color ?? '',
    logo: p.logo ?? '',
    phone: p.phone ?? '',
    website: p.website ?? '',
    outages: p.outages ?? '',
    hidden: !!p.hidden,
  };
}

/** Two letters from a name, as the app draws its badge. */
function initials(name: string) {
  const words = name.replace(/[^A-Za-z0-9 ]/g, ' ').split(' ').filter(Boolean);
  if (words.length === 0) return '?';
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

function Badge({ name, color, logo }: { name: string; color: string; logo: string }) {
  const valid = /^#[0-9a-fA-F]{6}$/.test(color);
  return logo ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={logo} alt="" className="size-10 shrink-0 rounded-[12px] bg-white object-contain" />
  ) : (
    <span
      aria-hidden
      className="grid size-10 shrink-0 place-items-center rounded-[12px] text-[14px] font-extrabold text-white"
      style={{ background: valid ? color : 'var(--color-site-ink-3, #777)' }}
    >
      {initials(name)}
    </span>
  );
}

function ProviderItem({ p, open, onToggle }: { p: ProviderRow; open: boolean; onToggle: () => void }) {
  const router = useRouter();
  const [draft, setDraft] = useState<ProviderEdit>(() => editOf(p));
  const [note, setNote] = useState<{ ok: boolean; message: string } | null>(null);
  const [busy, start] = useTransition();
  const saved = editOf(p);
  const dirty = JSON.stringify(draft) !== JSON.stringify(saved);
  const shownName = draft.name || p.org;

  const problems = [
    draft.color && !/^#[0-9a-fA-F]{6}$/.test(draft.color) ? 'Colour must look like #2EB34A' : null,
    ...(['logo', 'website', 'outages'] as const).map((k) =>
      draft[k] && !draft[k].startsWith('https://') ? `${k[0].toUpperCase()}${k.slice(1)} must start with https://` : null,
    ),
  ].filter(Boolean) as string[];

  const set = <K extends keyof ProviderEdit>(k: K, v: ProviderEdit[K]) => {
    setNote(null);
    setDraft((d) => ({ ...d, [k]: v }));
  };

  const save = () =>
    start(async () => {
      const result = await saveProvider(p.asn, draft);
      setNote(result);
      if (result.ok) router.refresh();
      setTimeout(() => setNote(null), 4000);
    });

  const input =
    'h-9 w-full rounded-[10px] border border-site-line bg-site-sunk px-3 text-[13px] text-site-ink outline-none placeholder:text-site-ink-3 focus:border-site-accent';

  return (
    <div className="border-t border-site-line">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className={`flex w-full items-center gap-3 px-[18px] py-3 text-left transition hover:bg-site-sunk ${p.hidden ? 'opacity-50' : ''}`}
      >
        <Badge name={shownName} color={draft.color} logo={draft.logo} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className="truncate text-[13.5px] font-semibold text-site-ink">{shownName}</span>
            {p.hidden ? (
              <span className="rounded-full bg-site-sunk px-2 py-0.5 text-[10.5px] font-bold uppercase text-site-ink-3">Hidden</span>
            ) : null}
            {!p.name && !p.hidden && (
              <span className="rounded-full bg-site-sunk px-2 py-0.5 text-[10.5px] font-bold uppercase text-site-plan">Not set up</span>
            )}
          </div>
          <div className="font-mono text-[11.5px] text-site-ink-3">
            AS{p.asn} · {p.org}
          </div>
        </div>
        <div className="w-20 text-right">
          <div className="font-mono text-[13px] font-semibold text-site-ink">{p.users}</div>
          <div className="text-[11px] text-site-ink-3">users · {p.cities} cities</div>
        </div>
        <div className="w-16 text-right">
          <div className="font-mono text-[13px] font-semibold text-site-ink">{p.average ?? '--'}</div>
          <div className="text-[11px] text-site-ink-3">{p.ratings} ratings</div>
        </div>
      </button>

      {open && (
        <div className="grid gap-3 bg-site-sunk/40 px-[18px] pb-4 pt-2 sm:grid-cols-2">
          <Field label="Display name" hint={`Shown in the app instead of "${p.org}"`}>
            <input className={input} value={draft.name} placeholder={p.org} maxLength={60} onChange={(e) => set('name', e.target.value)} />
          </Field>
          <Field label="Brand colour" hint="The badge and speed bars">
            <div className="flex gap-2">
              <input
                type="color"
                aria-label="Pick brand colour"
                value={/^#[0-9a-fA-F]{6}$/.test(draft.color) ? draft.color : '#888888'}
                onChange={(e) => set('color', e.target.value.toUpperCase())}
                className="h-9 w-11 shrink-0 cursor-pointer rounded-[10px] border border-site-line bg-site-sunk p-1"
              />
              <input className={`${input} font-mono`} value={draft.color} placeholder="#2EB34A" onChange={(e) => set('color', e.target.value.trim())} />
            </div>
          </Field>
          <Field label="Logo" hint="https URL, square, on the CDN. Leave empty for initials">
            <input className={input} value={draft.logo} placeholder="https://cdn.mindberzerk.com/..." onChange={(e) => set('logo', e.target.value.trim())} />
          </Field>
          <Field label="Support phone" hint="Opens the dialler">
            <input className={input} value={draft.phone} placeholder="+254 ..." maxLength={40} onChange={(e) => set('phone', e.target.value)} />
          </Field>
          <Field label="Website">
            <input className={input} value={draft.website} placeholder="https://" onChange={(e) => set('website', e.target.value.trim())} />
          </Field>
          <Field label="Outage page" hint="Where customers check for faults">
            <input className={input} value={draft.outages} placeholder="https://" onChange={(e) => set('outages', e.target.value.trim())} />
          </Field>
          <div className="sm:col-span-2">
            <SettingRow title="Hidden" hint="Not a home provider (hosting, data centre, VPN): no ratings and not listed near people">
              <Switch checked={draft.hidden} onChange={(v) => set('hidden', v)} label="Hidden" />
            </SettingRow>
          </div>
          {problems.length > 0 && (
            <ul className="sm:col-span-2 text-[12px] font-semibold text-site-bad">
              {problems.map((m) => (
                <li key={m}>{m}</li>
              ))}
            </ul>
          )}
          <div className="sm:col-span-2">
            <SaveBar
              dirty={dirty && problems.length === 0}
              busy={busy}
              note={note}
              onSave={save}
              onDiscard={() => setDraft(saved)}
              saveLabel="Save provider"
            />
          </div>
        </div>
      )}
    </div>
  );
}

function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[12px] font-semibold text-site-ink">{label}</span>
      {children}
      {hint && <span className="text-[11px] text-site-ink-3">{hint}</span>}
    </label>
  );
}
