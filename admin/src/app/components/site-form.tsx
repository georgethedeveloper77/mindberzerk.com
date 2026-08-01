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
}

/**
 * PHASE C12 - editing site content.
 *
 * ## The featured row is order plus visibility, nothing else
 *
 * Each registry app is a row. A checkbox includes it, the up and down controls
 * order it, and that is the whole model: no names or blurbs are edited here
 * because they live in the registry and the site resolves them. This is what
 * stops the site and the panel drifting into two descriptions of the same app.
 *
 * ## THE PREVIEW MOVED INTO THIS COMPONENT, AND THAT FIXED A DRIFT
 *
 * The doc here used to say the preview strip sat under the editor. It did not:
 * the PAGE rendered it, above the form, from its own `resolveFeatured` call. So
 * the preview showed what was PUBLISHED while the editor showed what you were
 * typing, and the two only agreed before you touched anything. The strip is now
 * built from live form state, in the panel beside the editor, which is what the
 * doc always claimed and what makes it worth having: a live app with no store
 * link is flagged next to the card it would break, before publish.
 *
 * ## The blocking problem renders in the preview, not mid-form
 *
 * A featured, live app with no package would ship a card that links nowhere.
 * That already hard-blocks the publish; putting the reason beside the card it
 * would break is what makes the block obvious rather than mysterious.
 */
export function SiteForm({
  apps,
  initial,
}: {
  apps: AppRow[];
  initial: Content;
}) {
  const router = useRouter();
  const [featured, setFeatured] = useState<string[]>(initial.featured);
  const [hero, setHero] = useState(initial.hero);
  const [stats, setStats] = useState(initial.stats);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const byId = useMemo(() => new Map(apps.map((a) => [a.id, a])), [apps]);

  const dirty =
    JSON.stringify({ featured, hero, stats }) !==
    JSON.stringify({ featured: initial.featured, hero: initial.hero, stats: initial.stats });

  function toggle(id: string) {
    setFeatured((f) => (f.includes(id) ? f.filter((x) => x !== id) : [...f, id]));
  }
  function move(id: string, dir: -1 | 1) {
    setFeatured((f) => {
      const i = f.indexOf(id);
      const j = i + dir;
      if (i < 0 || j < 0 || j >= f.length) return f;
      const copy = [...f];
      [copy[i], copy[j]] = [copy[j], copy[i]];
      return copy;
    });
  }

  // Live + featured + no link = a card that links nowhere. Surfaced before save.
  const broken = featured
    .map((id) => byId.get(id))
    .filter((a): a is AppRow => !!a)
    .filter((a) => a.state === 'live' && !a.hasLink);

  // The headline splits at the first comma, and the site renders the tail in
  // the accent colour. Mirrored here so the preview is the site's own rule
  // rather than an approximation of it.
  const comma = hero.headline.indexOf(',');
  const headLead = comma >= 0 ? hero.headline.slice(0, comma + 1) : hero.headline;
  const headTail = comma >= 0 ? hero.headline.slice(comma + 1) : '';

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
        setMsg({
          tone: 'ok',
          text: 'Published to site/content.json. The static build revalidates shortly.',
        });
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

  const blocked = broken.length > 0 ? 'A featured app has no store link' : null;

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <button
          onClick={save}
          disabled={!dirty || busy || !!blocked}
          className="rounded-lg bg-accent px-4 py-2 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-40"
        >
          {busy ? 'Publishing' : dirty ? 'Publish site' : 'No changes'}
        </button>
        {blocked ? (
          <span className="text-micro text-warn">{blocked}</span>
        ) : dirty ? (
          <span className="text-micro text-ink-3">unsaved changes</span>
        ) : null}
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1 space-y-3">
          {/* ── featured order ───────────────────────────────────────────── */}
          <section className="rounded-card border border-line-soft bg-surface-1">
            <header className="flex items-center gap-2 border-b border-line-soft px-3 py-2.5 sm:px-4">
              <h2 className="text-data font-medium">Featured apps</h2>
              <span className="ml-auto text-micro text-ink-3">
                {featured.length} of {apps.length} shown
              </span>
            </header>

            <div className="divide-y divide-line-soft">
              {/* Shown apps first, in order; then the rest, to add. */}
              {featured.map((id, idx) => {
                const a = byId.get(id);
                if (!a) return null;
                return (
                  <AppLine
                    key={id}
                    a={a}
                    slot={idx + 1}
                    shown
                    onToggle={() => toggle(id)}
                    onUp={idx === 0 ? undefined : () => move(id, -1)}
                    onDown={idx === featured.length - 1 ? undefined : () => move(id, 1)}
                  />
                );
              })}
              {apps
                .filter((a) => !featured.includes(a.id))
                .map((a) => (
                  <AppLine key={a.id} a={a} shown={false} onToggle={() => toggle(a.id)} />
                ))}
            </div>
          </section>

          {/* ── hero ─────────────────────────────────────────────────────── */}
          <section className="space-y-3 rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
            <h2 className="text-data font-medium">Hero</h2>
            <Field
              label="Eyebrow"
              value={hero.eyebrow}
              onChange={(v) => setHero({ ...hero, eyebrow: v })}
            />
            <Field
              label="Headline"
              hint="Text after the first comma renders in the accent colour"
              value={hero.headline}
              onChange={(v) => setHero({ ...hero, headline: v })}
            />
            <div>
              <label className="block text-micro text-ink-3">Lede</label>
              <textarea
                value={hero.lede}
                onChange={(e) => setHero({ ...hero, lede: e.target.value })}
                rows={2}
                className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2"
              />
            </div>
          </section>

          {/* ── stats ────────────────────────────────────────────────────── */}
          <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
            <h2 className="mb-2 text-data font-medium">Stat strip</h2>
            <div className="space-y-2">
              {stats.map((s, i) => (
                <div key={i} className="flex gap-2">
                  <input
                    value={s.label}
                    onChange={(e) =>
                      setStats(stats.map((x, n) => (n === i ? { ...x, label: e.target.value } : x)))
                    }
                    className="flex-1 rounded-lg border border-line bg-surface-2 px-3 py-1.5 text-data"
                  />
                  <input
                    value={s.value}
                    onChange={(e) =>
                      setStats(stats.map((x, n) => (n === i ? { ...x, value: e.target.value } : x)))
                    }
                    className="w-28 rounded-lg border border-line bg-surface-2 px-3 py-1.5 font-mono text-data"
                  />
                </div>
              ))}
            </div>
            <p className="mt-2 text-micro leading-relaxed text-ink-3">
              A value of auto is computed by the site from the live catalogue, so
              it cannot overstate the store. The rest are typed and dated on
              publish.
            </p>
          </section>

          {msg && (
            <p
              className={`rounded-card border px-3 py-2 text-data leading-relaxed ${
                msg.tone === 'ok'
                  ? 'border-ok/40 bg-ok-dim text-ok'
                  : 'border-bad/40 bg-bad-dim text-bad'
              }`}
            >
              {msg.text}
            </p>
          )}
        </div>

        {/* ── as the site resolves it ──────────────────────────────────── */}
        <aside className="w-full shrink-0 rounded-card border border-line-soft bg-surface-1 p-3 lg:sticky lg:top-6 lg:w-64">
          <div className="font-mono text-micro text-ink-3">as the site resolves it</div>

          <div className="mt-2 rounded-lg bg-surface-0 p-3">
            <div className="text-micro uppercase tracking-wider text-ink-3">
              {hero.eyebrow || 'no eyebrow'}
            </div>
            <div className="mt-1 text-data leading-snug font-medium text-ink">
              {headLead || 'no headline'}
              <span className="text-accent">{headTail}</span>
            </div>
            {hero.lede && (
              <p className="mt-1 text-micro leading-relaxed text-ink-3">{hero.lede}</p>
            )}
          </div>

          <div className="mt-2 space-y-1.5">
            {featured.length === 0 && (
              <p className="text-micro leading-relaxed text-ink-3">
                Nothing featured, so the site shows no app cards at all.
              </p>
            )}
            {featured.map((id) => {
              const a = byId.get(id);
              if (!a) return null;
              const dead = a.state === 'live' && !a.hasLink;
              return (
                <div
                  key={id}
                  className={`flex items-center gap-2 rounded-lg border px-2 py-1.5 ${
                    dead ? 'border-bad/40 bg-bad-dim' : 'border-line-soft'
                  }`}
                >
                  <span
                    className="grid size-5 shrink-0 place-items-center rounded font-mono text-micro font-bold text-surface-0"
                    style={{ background: a.tint }}
                  >
                    {a.mark}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-micro text-ink-2">{a.name}</span>
                    <span
                      className={`block truncate text-micro ${dead ? 'text-bad' : 'text-ink-3'}`}
                    >
                      {dead
                        ? 'live with no store link'
                        : a.hasLink
                          ? 'links to the store'
                          : 'coming soon, no link'}
                    </span>
                  </span>
                </div>
              );
            })}
          </div>

          {broken.length > 0 && (
            <p className="mt-2 text-micro leading-relaxed text-bad">
              {broken.map((a) => a.name).join(', ')}{' '}
              {broken.length === 1 ? 'is' : 'are'} live and featured with no store
              link, so the card would point nowhere. Add a package in the registry
              or unfeature. Publishing is blocked until then.
            </p>
          )}

          {stats.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 border-t border-line-soft pt-2">
              {stats.map((s, i) => (
                <span key={i} className="text-micro text-ink-3">
                  <span className="font-mono text-ink-2">{s.value || '-'}</span> {s.label}
                </span>
              ))}
            </div>
          )}
        </aside>
      </div>
    </div>
  );
}

/**
 * One registry app. The include control and the ordering controls are TEXT, not
 * glyphs: the panel has no icon system, and a bare arrow in a 4px button is the
 * hardest thing on this screen to hit on a phone.
 */
function AppLine({
  a,
  slot,
  shown,
  onToggle,
  onUp,
  onDown,
}: {
  a: AppRow;
  slot?: number;
  shown: boolean;
  onToggle: () => void;
  onUp?: () => void;
  onDown?: () => void;
}) {
  return (
    <div className="flex items-center gap-2.5 px-3 py-2 sm:px-4">
      <button
        onClick={onToggle}
        aria-pressed={shown}
        className={`shrink-0 rounded-md border px-2 py-1 font-mono text-micro transition ${
          shown
            ? 'border-accent/40 bg-accent-dim text-accent'
            : 'border-line text-ink-3 hover:text-ink-2'
        }`}
      >
        {shown ? 'shown' : 'hidden'}
      </button>
      <span
        className="grid size-5 shrink-0 place-items-center rounded font-mono text-micro font-bold text-surface-0"
        style={{ background: a.tint }}
      >
        {a.mark}
      </span>
      <span className="min-w-0 flex-1">
        <span className="text-data text-ink-2">{a.name}</span>
        <span className="ml-2 font-mono text-micro text-ink-3">{a.state}</span>
        {a.state === 'live' && !a.hasLink && (
          <span className="ml-2 text-micro text-bad">no store link</span>
        )}
      </span>
      {shown && slot && (
        <span className="shrink-0 font-mono text-micro text-ink-3 tnum">#{slot}</span>
      )}
      {shown && (
        <span className="flex shrink-0 items-center gap-2">
          <button
            onClick={onUp}
            disabled={!onUp}
            className="text-micro text-ink-3 transition hover:text-ink disabled:opacity-30"
          >
            up
          </button>
          <button
            onClick={onDown}
            disabled={!onDown}
            className="text-micro text-ink-3 transition hover:text-ink disabled:opacity-30"
          >
            down
          </button>
        </span>
      )}
    </div>
  );
}

function Field({
  label,
  hint,
  value,
  onChange,
}: {
  label: string;
  hint?: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label className="block text-micro text-ink-3">
        {label}
        {hint && <span className="ml-2 text-ink-3/70">{hint}</span>}
      </label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2"
      />
    </div>
  );
}
