'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

interface AppRow {
  id: string;
  name: string;
  mark: string;
  tint: string;
  state: string;
  hasLink: boolean;
}

interface Content {
  featured: string[];
  hero: { eyebrow: string; headline: string; lede: string };
  stats: { label: string; value: string }[];
}

/**
 * PHASE C12 — editing site content.
 *
 * ## The featured row is order plus visibility, nothing else
 *
 * Each registry app is a row. A checkbox includes it, the arrows order it, and
 * that is the whole model — no names or blurbs are edited here because they live
 * in the registry and the site resolves them. This is what stops the site and
 * the panel drifting into two descriptions of the same app.
 *
 * ## The publish preview is the site's own resolution
 *
 * The card strip under the editor renders each featured id through the same
 * registry lookup the static site uses, so what you see is what builds. A live
 * app with no store link is flagged red here rather than discovered as a dead
 * link after deploy.
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
        setMsg({ tone: 'ok', text: 'Published to site/content.json. The static build revalidates shortly.' });
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

  return (
    <div className="space-y-3">
      {/* ── featured order ────────────────────────────────────────────────── */}
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
              <Row key={id} a={a} slot={idx + 1} shown onToggle={() => toggle(id)}>
                <button
                  onClick={() => move(id, -1)}
                  disabled={idx === 0}
                  className="px-1 text-ink-3 disabled:opacity-30"
                >
                  ↑
                </button>
                <button
                  onClick={() => move(id, 1)}
                  disabled={idx === featured.length - 1}
                  className="px-1 text-ink-3 disabled:opacity-30"
                >
                  ↓
                </button>
              </Row>
            );
          })}
          {apps
            .filter((a) => !featured.includes(a.id))
            .map((a) => (
              <Row key={a.id} a={a} shown={false} onToggle={() => toggle(a.id)} />
            ))}
        </div>
      </section>

      {broken.length > 0 && (
        <p className="rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
          {broken.map((a) => a.name).join(', ')} {broken.length === 1 ? 'is' : 'are'} live and
          featured but {broken.length === 1 ? 'has' : 'have'} no store link. The card would
          point nowhere. Add a package in the registry or unfeature.
        </p>
      )}

      {/* ── hero ──────────────────────────────────────────────────────────── */}
      <section className="space-y-3 rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
        <h2 className="text-data font-medium">Hero</h2>
        <Field label="Eyebrow" value={hero.eyebrow} onChange={(v) => setHero({ ...hero, eyebrow: v })} />
        <Field
          label="Headline (text after the comma renders in accent)"
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

      {/* ── stats ─────────────────────────────────────────────────────────── */}
      <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
        <h2 className="mb-2 text-data font-medium">Stat strip</h2>
        <div className="space-y-2">
          {stats.map((s, i) => (
            <div key={i} className="flex gap-2">
              <input
                value={s.label}
                onChange={(e) => setStats(stats.map((x, n) => (n === i ? { ...x, label: e.target.value } : x)))}
                className="flex-1 rounded-lg border border-line bg-surface-2 px-3 py-1.5 text-data"
              />
              <input
                value={s.value}
                onChange={(e) => setStats(stats.map((x, n) => (n === i ? { ...x, value: e.target.value } : x)))}
                className="w-28 rounded-lg border border-line bg-surface-2 px-3 py-1.5 font-mono text-data"
              />
            </div>
          ))}
        </div>
        <p className="mt-2 text-micro text-ink-3">
          A value of <code className="font-mono">auto</code> is computed by the site from the live
          catalogue, so it cannot overstate the store. The rest are typed and dated on publish.
        </p>
      </section>

      {msg && (
        <p
          className={`rounded-card border px-3 py-2 text-data leading-relaxed ${
            msg.tone === 'ok' ? 'border-ok/40 bg-ok-dim text-ok' : 'border-bad/40 bg-bad-dim text-bad'
          }`}
        >
          {msg.text}
        </p>
      )}

      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] md:static">
        <button
          onClick={save}
          disabled={!dirty || busy || broken.length > 0}
          className="w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Publishing…' : dirty ? 'Publish site' : 'No changes'}
        </button>
      </div>
    </div>
  );
}

function Row({
  a,
  slot,
  shown,
  onToggle,
  children,
}: {
  a: AppRow;
  slot?: number;
  shown: boolean;
  onToggle: () => void;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex items-center gap-3 px-3 py-2.5 sm:px-4">
      <button
        onClick={onToggle}
        className={`grid size-4 shrink-0 place-items-center rounded ${
          shown ? 'bg-accent text-accent-ink' : 'border border-line'
        }`}
      >
        {shown ? '✓' : ''}
      </button>
      <span
        className="grid size-5 shrink-0 place-items-center rounded font-mono text-micro font-bold text-surface-0"
        style={{ background: a.tint }}
      >
        {a.mark}
      </span>
      <span className="min-w-0 flex-1">
        <span className="text-data">{a.name}</span>
        <span className="ml-2 font-mono text-micro text-ink-3">{a.state}</span>
        {a.state === 'live' && !a.hasLink && (
          <span className="ml-2 text-micro text-bad">no store link</span>
        )}
      </span>
      {shown && slot && <span className="font-mono text-micro text-ink-3 tnum">#{slot}</span>}
      {children}
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label className="block text-micro text-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2"
      />
    </div>
  );
}
