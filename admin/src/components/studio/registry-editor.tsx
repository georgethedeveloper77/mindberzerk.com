'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { isComing, stateLabel } from '@/lib/studio/site-apps';
import type { AppMeta, AppState } from '@/lib/core/registry';

/**
 * Editing the studio's app list, with the site's own rendering beside it.
 *
 * ## THE PREVIEW IS THE POINT
 *
 * The fields here are abstract: a tint, a mark, a state, two numeric store ids.
 * Nothing about typing them tells you what the result looks like to a visitor,
 * and the failure mode is quiet: an app added with a blurb written for an
 * internal audience, or set live with no link, reads fine in a form and badly
 * on a phone.
 *
 * So the right-hand column renders the selected app exactly as the landing page
 * will: the featured card with its store chip or its coming-soon state, and the
 * catalogue row. It is the same resolution the site performs, from
 * `site-apps.ts`, rather than a second implementation that could disagree.
 *
 * ## Whole array, one save
 *
 * Same shape as the bundle editor and for the same reason: a partial update
 * would need concurrency control to be safe, and with one admin, last-write
 * over the whole array is simpler and fails visibly rather than subtly.
 *
 * Selection is client state here rather than a URL parameter, because the whole
 * screen is one dirty array and a link navigation would discard unsaved edits
 * without saying so.
 */

const STATES: AppState[] = ['live', 'build', 'planned', 'external'];

const TINTS = ['#e95420', '#4c8dff', '#b4407f', '#d29922', '#3fb950', '#8b5cf6', '#22c55e', '#e8703a'];

export function RegistryEditor({
  initial,
  anchored,
}: {
  initial: AppMeta[];
  /** Ids this panel administers. They cannot be deleted or renamed. */
  anchored: string[];
}) {
  const router = useRouter();
  const [apps, setApps] = useState<AppMeta[]>(initial);
  const [sel, setSel] = useState(0);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const dirty = JSON.stringify(apps) !== JSON.stringify(initial);
  const current = apps[sel];
  const isAnchored = (id: string) => anchored.includes(id);

  // Mirrors lib/studio/apps.ts validateRegistry. The server copy is the gate;
  // this one fails fast so a typo is caught before a round trip. Same standing
  // as the mirrored rule in config-form.
  const problems = useMemo(() => {
    const out: string[] = [];
    const seen = new Set<string>();
    for (const a of apps) {
      const label = a.name.trim() || a.id;
      if (!/^[a-z][a-z0-9-]{1,40}$/.test(a.id)) out.push(`"${a.id}" is not a usable id.`);
      if (seen.has(a.id)) out.push(`Two apps share the id "${a.id}".`);
      seen.add(a.id);
      if (!a.name.trim()) out.push(`The app at ${a.id} has no name.`);
      if (!a.blurb.trim()) out.push(`${label} has no blurb, and the site renders it verbatim.`);
      if (a.state === 'live' && !a.pkg && !a.appStoreAppId) {
        out.push(`${label} is live but links nowhere.`);
      }
    }
    return out;
  }, [apps]);

  function patch(i: number, next: Partial<AppMeta>) {
    setApps((x) => x.map((a, n) => (n === i ? { ...a, ...next } : a)));
  }

  function add() {
    const n = apps.length + 1;
    setApps((x) => [
      ...x,
      {
        id: `new-app-${n}`,
        name: '',
        pkg: null,
        mark: '?',
        tint: TINTS[n % TINTS.length],
        managed: false,
        state: 'planned',
        blurb: '',
      },
    ]);
    setSel(apps.length);
  }

  function remove(i: number) {
    if (isAnchored(apps[i].id)) return;
    setApps((x) => x.filter((_, n) => n !== i));
    setSel((s) => (s >= i ? Math.max(0, s - 1) : s));
  }

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch('/api/publish/apps', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ apps }),
      });
      const json = await res.json();
      if (res.ok) {
        setMsg({ tone: 'ok', text: `Saved. ${json.count} apps in the registry.` });
        router.refresh();
      } else {
        setMsg({ tone: 'bad', text: json.error ?? 'Save failed' });
      }
    } catch (e) {
      setMsg({ tone: 'bad', text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  const input =
    'w-full rounded-xl border border-site-line bg-site-sunk px-3 py-2.5 text-sm text-site-ink focus:border-site-accent focus:outline-none';

  return (
    <div className="flex flex-col gap-4">
      {/* ── slab ── */}
      <section
        className="relative overflow-hidden rounded-[22px] shadow-[0_18px_44px_rgba(23,16,31,0.22)]"
        style={{
          background:
            'radial-gradient(560px 260px at 5% -30%, rgba(74,211,165,0.34), transparent 62%), radial-gradient(420px 240px at 98% 130%, rgba(141,101,255,0.44), transparent 62%), linear-gradient(140deg, #1b2531, #12141f 60%, #0f0c16)',
        }}
      >
        <span
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              'linear-gradient(rgba(255,255,255,0.045) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.045) 1px, transparent 1px)',
            backgroundSize: '44px 44px',
            maskImage: 'radial-gradient(620px 260px at 15% 0%, #000, transparent 76%)',
            WebkitMaskImage: 'radial-gradient(620px 260px at 15% 0%, #000, transparent 76%)',
          }}
        />
        <div className="relative z-10 flex flex-wrap items-center gap-4 px-6 py-5">
          <div className="min-w-[240px]">
            <span className="inline-flex items-center gap-2 text-[10.5px] font-bold uppercase tracking-[0.1em] text-white/60">
              <span className="size-1.5 rounded-full bg-[#5ee0a8] shadow-[0_0_0_3px_rgba(94,224,168,0.2)]" />
              App registry
            </span>
            <h1 className="mt-2 font-site-display text-[25px] font-extrabold text-[#f6f2fd]">
              Every app the studio ships.
            </h1>
            <p className="mt-1.5 text-[12.5px] text-white/60">
              The dashboard counts this list, the site renders it, the legal pages key off it.
            </p>
          </div>
          <div className="flex-1" />
          {problems.length > 0 && (
            <span className="inline-flex items-center gap-2 rounded-full border border-[rgba(255,139,131,0.3)] bg-[rgba(255,139,131,0.1)] py-1.5 pl-2.5 pr-3 text-[11.5px] font-bold text-[#ffb0a8]">
              <span className="size-1.5 rounded-full bg-[#ff8b83]" />
              {problems.length} to fix
            </span>
          )}
          <button
            onClick={save}
            disabled={!dirty || busy || problems.length > 0}
            className="rounded-[10px] bg-white px-4 py-2 text-[13px] font-semibold text-[#1a1226] transition disabled:bg-white/15 disabled:text-white/50"
          >
            {busy ? 'Saving' : dirty ? 'Save the registry' : 'No changes'}
          </button>
        </div>
      </section>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_320px]">
        <div className="flex flex-col gap-4">
          {/* ── the list ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            {apps.map((a, i) => (
              <button
                key={`${a.id}-${i}`}
                onClick={() => setSel(i)}
                className={`relative flex w-full items-center gap-3 border-t border-site-line px-[18px] py-3 text-left first:border-t-0 ${
                  sel === i ? 'bg-site-sunk' : ''
                }`}
              >
                <span aria-hidden className="absolute inset-y-0 left-0 w-[3px]" style={{ background: a.tint }} />
                <span
                  aria-hidden
                  className="grid size-[31px] shrink-0 place-items-center rounded-[9px] font-site-display text-[12px] font-extrabold text-white"
                  style={{
                    background: `linear-gradient(140deg, color-mix(in srgb, ${a.tint} 76%, #fff 24%), ${a.tint})`,
                  }}
                >
                  {a.mark || '?'}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[13.5px] font-semibold text-site-ink">
                    {a.name || <span className="text-site-plan">unnamed</span>}
                  </span>
                  <span className="block truncate font-mono text-[11px] text-site-ink-3">
                    {a.pkg ?? a.id}
                  </span>
                </span>
                <span
                  className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide ${
                    a.state === 'live'
                      ? 'bg-site-ok-soft text-site-ok'
                      : a.state === 'build'
                        ? 'bg-site-info-soft text-site-info'
                        : a.state === 'external'
                          ? 'bg-site-accent-soft text-site-accent-deep'
                          : 'bg-site-sunk text-site-ink-3'
                  }`}
                >
                  {a.state}
                </span>
                {isAnchored(a.id) && (
                  <span className="shrink-0 font-mono text-[10px] text-site-ink-3">managed</span>
                )}
              </button>
            ))}
            <button
              onClick={add}
              className="flex w-full items-center justify-center gap-2 border-t border-dashed border-site-line py-3 text-[12.5px] font-semibold text-site-ink-3 transition hover:text-site-ink"
            >
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden>
                <path d="M7 2.5v9M2.5 7h9" />
              </svg>
              Add an app
            </button>
          </section>

          {/* ── the editor ── */}
          {current && (
            <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
              <header className="flex items-center gap-3 px-[18px] py-4">
                <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-accent-soft text-site-accent-deep">
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden>
                    <path d="M11.3 2.9l1.8 1.8L5.8 12H4v-1.8l7.3-7.3z" />
                  </svg>
                </span>
                <h2 className="font-site-display text-[15px] font-bold text-site-ink">
                  {current.name || 'New app'}
                </h2>
                <div className="flex-1" />
                {isAnchored(current.id) ? (
                  <span className="rounded-full bg-site-ok-soft px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-site-ok">
                    administered here
                  </span>
                ) : (
                  <button
                    onClick={() => remove(sel)}
                    className="text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan"
                  >
                    Remove
                  </button>
                )}
              </header>

              <div className="grid gap-4 px-[18px] pb-[18px] sm:grid-cols-2">
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Name</label>
                  <input value={current.name} onChange={(e) => patch(sel, { name: e.target.value })} className={input} />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">
                    Id{' '}
                    {isAnchored(current.id) && (
                      <span className="font-normal text-site-ink-3">fixed, it is a route segment</span>
                    )}
                  </label>
                  <input
                    value={current.id}
                    readOnly={isAnchored(current.id)}
                    onChange={(e) => patch(sel, { id: e.target.value })}
                    className={`${input} font-mono ${isAnchored(current.id) ? 'opacity-60' : ''}`}
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">
                    Blurb <span className="font-normal text-site-ink-3">rendered verbatim on the site</span>
                  </label>
                  <textarea
                    value={current.blurb}
                    onChange={(e) => patch(sel, { blurb: e.target.value })}
                    rows={2}
                    className={`${input} resize-y leading-relaxed`}
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Android package</label>
                  <input
                    value={current.pkg ?? ''}
                    onChange={(e) => patch(sel, { pkg: e.target.value.trim() || null })}
                    placeholder="com.mindhunter.example"
                    className={`${input} font-mono`}
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">State</label>
                  <select
                    value={current.state}
                    onChange={(e) => patch(sel, { state: e.target.value as AppState })}
                    className={input}
                  >
                    {STATES.map((s) => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Play Console app id</label>
                  <input
                    value={current.playConsoleAppId ?? ''}
                    onChange={(e) => patch(sel, { playConsoleAppId: e.target.value.trim() || undefined })}
                    placeholder="4975715356489098445"
                    className={`${input} font-mono`}
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">App Store id</label>
                  <input
                    value={current.appStoreAppId ?? ''}
                    onChange={(e) => patch(sel, { appStoreAppId: e.target.value.trim() || undefined })}
                    placeholder="6789087329"
                    className={`${input} font-mono`}
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Mark</label>
                  <input
                    value={current.mark}
                    maxLength={2}
                    onChange={(e) => patch(sel, { mark: e.target.value.toUpperCase() })}
                    className={`${input} font-site-display font-extrabold`}
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">
                    Tint <span className="font-normal text-site-ink-3">recognition only, carries no status</span>
                  </label>
                  <div className="flex flex-wrap gap-1.5 pt-1.5">
                    {TINTS.map((t) => (
                      <button
                        key={t}
                        onClick={() => patch(sel, { tint: t })}
                        aria-label={t}
                        className={`size-7 rounded-lg transition ${
                          current.tint.toLowerCase() === t ? 'ring-2 ring-site-ink ring-offset-2 ring-offset-site-card' : ''
                        }`}
                        style={{ background: t }}
                      />
                    ))}
                  </div>
                </div>
              </div>
            </section>
          )}

          {msg && (
            <p
              className={`rounded-[14px] px-4 py-3 text-[13px] leading-relaxed ${
                msg.tone === 'ok' ? 'bg-site-ok-soft text-site-ok' : 'bg-site-plan-soft text-site-plan'
              }`}
            >
              {msg.text}
            </p>
          )}
        </div>

        {/* ── the preview: the site's own rendering ── */}
        {current && (
          <aside className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4">
            <header className="flex items-center gap-3 px-[18px] py-4">
              <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-ok-soft text-site-ok">
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
                  <rect x="4.5" y="1.8" width="7" height="12.4" rx="1.8" />
                  <path d="M7 12.6h2" />
                </svg>
              </span>
              <h2 className="font-site-display text-[15px] font-bold text-site-ink">On the site</h2>
            </header>

            <div className="px-[18px] pb-[18px]">
              {/* Stays light in both modes, because the site is light by
                  default and this is the site, not the panel. */}
              <div className="overflow-hidden rounded-[14px] border border-site-line bg-[#faf9f7] shadow-[0_10px_26px_rgba(0,0,0,0.2)]">
                <div className="flex items-center gap-1.5 border-b border-[#e3dfe9] bg-[#efedf4] px-2.5 py-2">
                  <span className="size-2 rounded-full bg-[#cfc9da]" />
                  <span className="size-2 rounded-full bg-[#cfc9da]" />
                  <span className="size-2 rounded-full bg-[#cfc9da]" />
                  <span className="ml-1.5 font-mono text-[9.5px] text-[#8d8599]">mindberzerk.com</span>
                </div>

                {/* the featured card */}
                <div className="p-3.5">
                  <div className="mb-2 text-[9px] font-bold uppercase tracking-[0.08em] text-[#736b80]">
                    Featured card
                  </div>
                  <div className="rounded-xl border border-[#e9e5ef] bg-white p-3">
                    <span className="inline-block rounded-full bg-[#efeafd] px-2 py-0.5 text-[8.5px] font-bold uppercase tracking-wide text-[#55379f]">
                      {stateLabel(current.state)}
                    </span>
                    <div className="mt-1.5 font-site-display text-[15px] font-bold tracking-tight text-[#1c1526]">
                      {current.name || 'Unnamed app'}
                    </div>
                    <p className="mt-1 text-[10.5px] leading-relaxed text-[#514a5e]">
                      {current.blurb || (
                        <span className="text-[#ad2f2a]">No blurb, so this card renders empty.</span>
                      )}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {current.pkg && !isComing(current.state) && (
                        <span className="rounded-full border-[1.5px] border-[#e9e5ef] px-2.5 py-1 text-[9px] font-semibold text-[#1c1526]">
                          Google Play
                        </span>
                      )}
                      {current.appStoreAppId && (
                        <span className="rounded-full border-[1.5px] border-[#e9e5ef] px-2.5 py-1 text-[9px] font-semibold text-[#1c1526]">
                          App Store
                        </span>
                      )}
                      {isComing(current.state) && (
                        <span className="rounded-full border-[1.5px] border-dashed border-[#e9e5ef] px-2.5 py-1 text-[9px] font-semibold text-[#736b80]">
                          Coming soon
                        </span>
                      )}
                      {!current.pkg && !current.appStoreAppId && !isComing(current.state) && (
                        <span className="rounded-full bg-[#fbe6e4] px-2.5 py-1 text-[9px] font-semibold text-[#ad2f2a]">
                          Live, but links nowhere
                        </span>
                      )}
                    </div>
                  </div>

                  {/* the catalogue row */}
                  <div className="mb-2 mt-4 text-[9px] font-bold uppercase tracking-[0.08em] text-[#736b80]">
                    Catalogue row
                  </div>
                  <div className="flex items-start gap-2.5 rounded-xl border border-[#e9e5ef] bg-white p-2.5">
                    <span
                      aria-hidden
                      className="grid size-8 shrink-0 place-items-center rounded-[10px] font-site-display text-[12px] font-extrabold text-white"
                      style={{
                        background: `linear-gradient(140deg, ${current.tint}, color-mix(in srgb, ${current.tint} 55%, #1c1526))`,
                      }}
                    >
                      {current.mark || '?'}
                    </span>
                    <span className="min-w-0">
                      <span className="flex items-center gap-1.5">
                        <span className="truncate text-[11.5px] font-semibold text-[#1c1526]">
                          {current.name || 'Unnamed app'}
                        </span>
                        <span className="rounded-full bg-[#e0f4ec] px-1.5 py-0.5 text-[8px] font-bold uppercase tracking-wide text-[#12735c]">
                          {stateLabel(current.state)}
                        </span>
                      </span>
                      <span className="mt-0.5 block text-[9.5px] leading-relaxed text-[#514a5e]">
                        {current.blurb || 'No blurb'}
                      </span>
                    </span>
                  </div>
                </div>
              </div>

              <p className="mt-3 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
                This is the site&apos;s own resolution, not a mock-up of it: the same rules decide
                whether a store chip appears, whether it says coming soon, and whether a live app is
                pointing at nothing.
              </p>
            </div>
          </aside>
        )}
      </div>
    </div>
  );
}
