'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

interface AppRow {
  id: string;
  name: string;
  mark: string;
  tint: string;
  blurb: string;
  state: string;
  hasLink: boolean;
}

interface Content {
  featured: string[];
  hero: { eyebrow: string; headline: string; lede: string };
  stats: { label: string; value: string }[];
  updatedAt: number;
}

/**
 * Editing what mindberzerk.com says.
 *
 * ## ONE LIST, NOT TWO
 *
 * Featured and unfeatured used to be two visually separate stacks, which read
 * as two lists that happened to be adjacent and made "how do I promote G Music"
 * a question with no obvious answer. It is one ordered list with a switch per
 * row: on rows carry their tint as a wash and their position with the
 * reordering controls, off rows keep the tint at low opacity and lose the
 * controls, because an unfeatured app has no position.
 *
 * ## THE PREVIEW IS THE SITE, AND IT STAYS LIGHT
 *
 * The right column is not a description of the outcome, it is the outcome: the
 * hero with its accent segment split on the first comma exactly as
 * `splitHeadline` does it, the featured cards saying whether each will link or
 * say coming soon, and the stat strip with the computed value shown as
 * computed. It renders light in both panel themes because the site is light by
 * default, so what you see is what a visitor sees rather than what the panel
 * would make of it.
 *
 * ## `auto` IS A VALUE, NOT A SETTING
 *
 * A stat whose value is the literal `auto` is computed by the site from the
 * live catalogue. It is typed rather than toggled because it round-trips
 * through the same JSON field as any other value, and a toggle would imply a
 * second field that does not exist.
 */
export function SiteEditor({ apps, initial }: { apps: AppRow[]; initial: Content }) {
  const router = useRouter();

  const [featured, setFeatured] = useState<string[]>(initial.featured);
  const [hero, setHero] = useState(initial.hero);
  const [stats, setStats] = useState(initial.stats);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const dirty =
    JSON.stringify({ featured, hero, stats }) !==
    JSON.stringify({ featured: initial.featured, hero: initial.hero, stats: initial.stats });

  const byId = useMemo(() => new Map(apps.map((a) => [a.id, a])), [apps]);

  // Featured first in their published order, then everything else in registry
  // order. One list, so the boundary is a property of a row rather than a gap.
  const ordered = useMemo(() => {
    const on = featured.map((id) => byId.get(id)).filter((a): a is AppRow => !!a);
    const off = apps.filter((a) => !featured.includes(a.id));
    return [...on, ...off];
  }, [apps, featured, byId]);

  // A live app with no store link is a card that goes nowhere, which the server
  // refuses on publish. Named here so the button says why before the round trip.
  const brokenLinks = featured
    .map((id) => byId.get(id))
    .filter((a): a is AppRow => !!a)
    .filter((a) => a.state === 'live' && !a.hasLink);

  const blocked =
    featured.length === 0
      ? 'Nothing is featured, so the hero would be empty'
      : brokenLinks.length > 0
        ? `${brokenLinks.map((a) => a.name).join(', ')} ${brokenLinks.length === 1 ? 'is' : 'are'} live with no store link`
        : null;

  function toggle(id: string) {
    setFeatured((f) => (f.includes(id) ? f.filter((x) => x !== id) : [...f, id]));
  }

  function move(id: string, by: -1 | 1) {
    setFeatured((f) => {
      const i = f.indexOf(id);
      const j = i + by;
      if (i < 0 || j < 0 || j >= f.length) return f;
      const next = [...f];
      [next[i], next[j]] = [next[j], next[i]];
      return next;
    });
  }

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch('/api/publish/site', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ featured, hero, stats }),
      });
      const json = await res.json();
      if (res.ok) {
        setMsg({ tone: 'ok', text: 'Published. The landing picks it up within five minutes.' });
        router.refresh();
      } else {
        setMsg({ tone: 'bad', text: json.error ?? 'Publish failed' });
      }
    } catch (e) {
      setMsg({ tone: 'bad', text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  // The accent rule, mirrored from splitHeadline in lib/studio/site-public.
  const comma = hero.headline.indexOf(',');
  const headPlain = comma < 0 ? hero.headline : hero.headline.slice(0, comma + 1);
  const headAccent = comma < 0 ? null : hero.headline.slice(comma + 1).trim() || null;

  const input =
    'w-full rounded-xl border border-site-line bg-site-sunk px-3 py-2.5 text-sm text-site-ink focus:border-site-accent focus:outline-none';

  return (
    <div className="flex flex-col gap-4">
      {/* ── slab ── */}
      <section
        className="relative overflow-hidden rounded-[22px] shadow-[0_18px_44px_rgba(23,16,31,0.22)]"
        style={{
          background:
            'radial-gradient(560px 260px at 5% -30%, rgba(141,101,255,0.5), transparent 62%), radial-gradient(420px 240px at 98% 130%, rgba(233,84,32,0.34), transparent 62%), linear-gradient(140deg, #241b37, #150f20 60%, #100b17)',
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
              Site content
            </span>
            <h1 className="mt-2 font-site-display text-[25px] font-extrabold text-[#f6f2fd]">
              What mindberzerk.com says.
            </h1>
            <p className="mt-1.5 text-[12.5px] text-white/60">
              {initial.updatedAt
                ? `Published. Edits go live within five minutes of the next publish.`
                : 'Never published. The landing is still rendering the seed.'}
            </p>
          </div>
          <div className="flex-1" />
          <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 py-1.5 pl-2.5 pr-3 text-[11.5px] font-bold text-[#d5cbe8]">
            <span className="size-1.5 rounded-full bg-[#ffb27a]" />
            {featured.length} of {apps.length} featured
          </span>
          <button
            onClick={save}
            disabled={!dirty || busy || !!blocked}
            className="rounded-[10px] bg-white px-4 py-2 text-[13px] font-semibold text-[#1a1226] transition disabled:bg-white/15 disabled:text-white/50"
          >
            {busy ? 'Publishing' : dirty ? 'Publish to the site' : 'No changes'}
          </button>
        </div>
        {blocked && dirty && (
          <div className="relative z-10 border-t border-white/10 px-6 py-2.5 text-[12px] font-semibold text-[#ffc79a]">
            {blocked}
          </div>
        )}
      </section>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_330px]">
        <div className="flex flex-col gap-4">
          {/* ── featured ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            <header className="flex items-center gap-3 px-[18px] py-4">
              <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-accent-soft text-site-accent-deep">
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" aria-hidden>
                  <path d="M8 2l1.8 3.8L14 6.4l-3 2.9.7 4.1L8 11.5l-3.7 1.9.7-4.1-3-2.9 4.2-.6L8 2z" />
                </svg>
              </span>
              <h2 className="font-site-display text-[15px] font-bold text-site-ink">Featured apps</h2>
              <span className="text-[11.5px] text-site-ink-3">the hero rotates through these, in order</span>
            </header>

            {ordered.map((a) => {
              const on = featured.includes(a.id);
              const rank = featured.indexOf(a.id);
              return (
                <div
                  key={a.id}
                  className="relative flex items-center gap-3 border-t border-site-line px-[18px] py-2.5"
                  style={
                    on
                      ? { background: `linear-gradient(90deg, color-mix(in srgb, ${a.tint} 13%, transparent), transparent 46%)` }
                      : undefined
                  }
                >
                  <span
                    aria-hidden
                    className="absolute inset-y-0 left-0 w-[3px]"
                    style={{ background: a.tint, opacity: on ? 0.9 : 0.16 }}
                  />
                  <button
                    onClick={() => toggle(a.id)}
                    role="switch"
                    aria-checked={on}
                    aria-label={`${on ? 'Unfeature' : 'Feature'} ${a.name}`}
                    className={`relative h-[23px] w-[42px] shrink-0 rounded-full border transition ${
                      on ? 'border-site-accent bg-site-accent' : 'border-site-line bg-site-sunk'
                    }`}
                  >
                    <span
                      className={`absolute top-[2px] size-[17px] rounded-full transition-all ${
                        on ? 'left-[21px] bg-white' : 'left-[2px] bg-site-ink-3'
                      }`}
                    />
                  </button>

                  <span
                    aria-hidden
                    className={`grid size-[31px] shrink-0 place-items-center rounded-[9px] font-site-display text-[12px] font-extrabold text-white transition ${
                      on ? '' : 'opacity-45 grayscale'
                    }`}
                    style={{
                      background: `linear-gradient(140deg, color-mix(in srgb, ${a.tint} 76%, #fff 24%), ${a.tint})`,
                    }}
                  >
                    {a.mark}
                  </span>

                  <span className="min-w-0 flex-1">
                    <span
                      className={`block truncate text-[13.5px] font-semibold ${on ? 'text-site-ink' : 'text-site-ink-3'}`}
                    >
                      {a.name}
                      <span className="ml-2 rounded-full bg-site-sunk px-2 py-0.5 text-[9.5px] font-bold uppercase tracking-wide text-site-ink-3">
                        {a.state}
                      </span>
                    </span>
                  </span>

                  {/* Order controls exist only for featured rows. An unfeatured
                      app has no position, so offering to move it is offering an
                      action with no meaning. */}
                  {on && (
                    <span className="flex shrink-0 items-center gap-1">
                      <span className="w-5 text-right font-mono text-[11.5px] text-site-ink-3">#{rank + 1}</span>
                      <button
                        onClick={() => move(a.id, -1)}
                        disabled={rank === 0}
                        aria-label="Move up"
                        className="grid size-[23px] place-items-center rounded-[7px] border border-site-line text-site-ink-3 transition hover:text-site-ink disabled:opacity-30"
                      >
                        <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                          <path d="M6 9V3M3 6l3-3 3 3" />
                        </svg>
                      </button>
                      <button
                        onClick={() => move(a.id, 1)}
                        disabled={rank === featured.length - 1}
                        aria-label="Move down"
                        className="grid size-[23px] place-items-center rounded-[7px] border border-site-line text-site-ink-3 transition hover:text-site-ink disabled:opacity-30"
                      >
                        <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                          <path d="M6 3v6M3 6l3 3 3-3" />
                        </svg>
                      </button>
                    </span>
                  )}
                </div>
              );
            })}
          </section>

          {/* ── hero ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            <header className="flex items-center gap-3 px-[18px] py-4">
              <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-plan-soft text-site-plan">
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden>
                  <path d="M3 4.5h10M3 8h7M3 11.5h5" />
                </svg>
              </span>
              <h2 className="font-site-display text-[15px] font-bold text-site-ink">Hero</h2>
              <span className="text-[11.5px] text-site-ink-3">the first thing anyone reads</span>
            </header>
            <div className="flex flex-col gap-3.5 px-[18px] pb-[18px]">
              <div>
                <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Eyebrow</label>
                <input value={hero.eyebrow} onChange={(e) => setHero({ ...hero, eyebrow: e.target.value })} className={input} />
              </div>
              <div>
                <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">
                  Headline{' '}
                  <span className="font-normal text-site-ink-3">after the first comma renders in the accent colour</span>
                </label>
                <input value={hero.headline} onChange={(e) => setHero({ ...hero, headline: e.target.value })} className={input} />
              </div>
              <div>
                <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Lede</label>
                <textarea
                  value={hero.lede}
                  onChange={(e) => setHero({ ...hero, lede: e.target.value })}
                  rows={2}
                  className={`${input} resize-y leading-relaxed`}
                />
              </div>
            </div>
          </section>

          {/* ── stats ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            <header className="flex items-center gap-3 px-[18px] py-4">
              <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-ok-soft text-site-ok">
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden>
                  <path d="M2.5 13V7.5M6.5 13V3.5M10 13V9M13.5 13V6" />
                </svg>
              </span>
              <h2 className="font-site-display text-[15px] font-bold text-site-ink">Stat strip</h2>
              <span className="text-[11.5px] text-site-ink-3">a value of auto is computed from the live catalogue</span>
            </header>
            <div className="grid gap-3 px-[18px] pb-[18px] sm:grid-cols-2">
              {stats.map((s, i) => {
                const auto = s.value.trim().toLowerCase() === 'auto';
                const skin = [
                  'bg-site-accent-soft border-site-accent/25',
                  'bg-site-ok-soft border-site-ok/25',
                  'bg-site-info-soft border-site-info/25',
                  'bg-site-plan-soft border-site-plan/25',
                ][i % 4];
                return (
                  <div key={i} className={`rounded-[14px] border p-3 ${skin}`}>
                    <div className="flex items-baseline gap-2">
                      <input
                        value={s.value}
                        onChange={(e) => setStats(stats.map((x, n) => (n === i ? { ...x, value: e.target.value } : x)))}
                        className="w-full min-w-0 border-0 bg-transparent p-0 font-site-display text-[23px] font-extrabold tracking-[-0.03em] text-site-ink focus:outline-none"
                      />
                      {auto && (
                        <span className="shrink-0 rounded-full bg-black/10 px-2 py-0.5 text-[9.5px] font-bold uppercase tracking-wide text-site-ink-3">
                          computed
                        </span>
                      )}
                    </div>
                    <input
                      value={s.label}
                      onChange={(e) => setStats(stats.map((x, n) => (n === i ? { ...x, label: e.target.value } : x)))}
                      className="mt-0.5 w-full border-0 bg-transparent p-0 text-[11.5px] font-semibold text-site-ink-2 focus:outline-none"
                    />
                  </div>
                );
              })}
            </div>
          </section>

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

        {/* ── the live preview ── */}
        <aside className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4">
          <header className="flex items-center gap-3 px-[18px] py-4">
            <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-accent-soft text-site-accent-deep">
              <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
                <circle cx="8" cy="8" r="2.4" />
                <path d="M1.6 8S3.9 3.6 8 3.6 14.4 8 14.4 8 12.1 12.4 8 12.4 1.6 8 1.6 8z" />
              </svg>
            </span>
            <h2 className="font-site-display text-[15px] font-bold text-site-ink">Live preview</h2>
          </header>
          <div className="px-[18px] pb-[18px]">
            <div className="overflow-hidden rounded-[14px] border border-site-line bg-[#faf9f7] shadow-[0_10px_26px_rgba(0,0,0,0.2)]">
              <div className="flex items-center gap-1.5 border-b border-[#e3dfe9] bg-[#efedf4] px-2.5 py-2">
                <span className="size-2 rounded-full bg-[#cfc9da]" />
                <span className="size-2 rounded-full bg-[#cfc9da]" />
                <span className="size-2 rounded-full bg-[#cfc9da]" />
                <span className="ml-1.5 font-mono text-[9.5px] text-[#8d8599]">mindberzerk.com</span>
              </div>

              <div
                className="px-4 py-4"
                style={{
                  background:
                    'radial-gradient(320px 160px at 0% 0%, #ece6fb, transparent 62%), radial-gradient(260px 150px at 100% 100%, #fdeee0, transparent 60%), #faf9f7',
                }}
              >
                {hero.eyebrow && (
                  <span className="mb-2 inline-block rounded-full border-[1.5px] border-[#e9e5ef] bg-white px-2.5 py-1 text-[9px] font-bold text-[#736b80]">
                    {hero.eyebrow}
                  </span>
                )}
                <h3 className="font-site-display text-[19px] font-extrabold leading-[1.15] tracking-tight text-[#1c1526]">
                  {headPlain}
                  {headAccent && <span className="text-[#6d4ae8]"> {headAccent}</span>}
                </h3>
                <p className="mt-1.5 text-[11px] leading-relaxed text-[#514a5e]">{hero.lede}</p>
                <div className="mt-3 flex gap-1.5">
                  <span className="rounded-lg bg-[#1c1526] px-2.5 py-1.5 text-[9px] font-semibold text-white">
                    Google Play
                  </span>
                  <span className="rounded-lg bg-[#1c1526] px-2.5 py-1.5 text-[9px] font-semibold text-white">
                    App Store
                  </span>
                </div>
              </div>

              <div className="flex flex-col gap-1.5 bg-[#faf9f7] px-4 pb-3">
                {featured.length === 0 ? (
                  <span className="rounded-lg bg-[#fbe6e4] px-2.5 py-2 text-[10px] font-semibold text-[#ad2f2a]">
                    Nothing featured, so the hero renders empty.
                  </span>
                ) : (
                  featured.map((id) => {
                    const a = byId.get(id);
                    if (!a) return null;
                    const coming = a.state === 'build' || a.state === 'planned';
                    return (
                      <span key={id} className="flex items-center gap-2 rounded-[10px] border border-[#e9e5ef] bg-white px-2.5 py-2">
                        <span
                          aria-hidden
                          className="grid size-6 shrink-0 place-items-center rounded-lg font-site-display text-[10px] font-extrabold text-white"
                          style={{ background: a.tint }}
                        >
                          {a.mark}
                        </span>
                        <span className="min-w-0">
                          <span className="block truncate text-[10.5px] font-bold text-[#1c1526]">{a.name}</span>
                          <span className="block text-[8.5px] text-[#736b80]">
                            {coming ? 'coming soon, no link' : a.hasLink ? 'links to the store' : 'live with no link'}
                          </span>
                        </span>
                      </span>
                    );
                  })
                )}
              </div>

              {stats.length > 0 && (
                <div className="grid grid-cols-4 gap-1.5 bg-[#faf9f7] px-4 pb-4">
                  {stats.map((s, i) => (
                    <span key={i} className="rounded-[9px] border border-[#e9e5ef] bg-white px-1.5 py-2 text-center">
                      <span className="block font-site-display text-[13px] font-extrabold text-[#1c1526]">
                        {s.value.trim().toLowerCase() === 'auto' ? 'auto' : s.value}
                      </span>
                      <span className="block text-[8px] leading-tight text-[#736b80]">{s.label}</span>
                    </span>
                  ))}
                </div>
              )}
            </div>

            <p className="mt-3 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
              Light in both panel themes, because the site is light by default. A stat reading auto
              is replaced by the site with the live theme-pack count; if the index cannot be read,
              that row is dropped rather than shown as a placeholder.
            </p>
          </div>
        </aside>
      </div>
    </div>
  );
}
