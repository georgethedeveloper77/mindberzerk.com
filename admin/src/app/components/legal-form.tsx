'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { renderMarkdown } from '@/lib/markdown';
import { validate, type DocKind, type LegalDraft } from '@/lib/legal-schema';

/**
 * PHASE C13 — editing an app's privacy policy and terms.
 *
 * ## The preview is the publish
 *
 * `renderMarkdown` here is the same function `writeLegal` calls, imported from
 * the same module, which is why the renderer lives outside `server-only`. A
 * preview built from a second implementation is a decoration; this one is a
 * guarantee, and it is the same argument `site-form` makes for resolving
 * featured cards through the registry rather than restating them.
 *
 * ## Contact and jurisdiction are fields, not prose
 *
 * They are appended to the markdown at publish time. Left inline they would be
 * two placeholders in a wall of text, and a placeholder in paragraph nine is a
 * placeholder that ships — which for a contact address means a rejected Play
 * listing and for a jurisdiction means terms that name nowhere.
 *
 * ## Publish writes both pages
 *
 * There is one button, not two. A privacy page from today beside terms from last
 * month is a state Play would notice and nobody else would, so the two move
 * together or not at all.
 */
export function LegalForm({
  app,
  initial,
  published,
  urls,
}: {
  app: string;
  initial: LegalDraft;
  published: boolean;
  urls: Record<DocKind, string>;
}) {
  const router = useRouter();

  const [doc, setDoc] = useState<LegalDraft>(initial);
  const [tab, setTab] = useState<DocKind>('privacy');
  const [preview, setPreview] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const dirty = JSON.stringify(doc) !== JSON.stringify(initial);
  const problems = useMemo(() => validate(doc), [doc]);

  // Rendered from the CURRENT tab only. Rendering both on every keystroke is
  // work nobody sees, and these documents are long.
  const html = useMemo(
    () => (preview ? renderMarkdown(doc[tab]) : ''),
    [preview, doc, tab],
  );

  function set<K extends keyof LegalDraft>(key: K, value: LegalDraft[K]) {
    setDoc((d) => ({ ...d, [key]: value }));
  }

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch('/api/publish/legal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app, ...doc }),
      });
      const json = await res.json();
      if (res.ok) {
        setMsg({
          tone: 'ok',
          text: 'Published. Both pages are live at the URLs above within five minutes.',
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

  return (
    <div className="space-y-3">
      {/* ── where these end up ─────────────────────────────────────────────
          Shown whether or not anything is published, because these are the
          strings that get pasted into Play and they do not change. */}
      <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
        <h2 className="mb-2 text-data font-medium">Public URLs</h2>
        <div className="space-y-1.5">
          {(['privacy', 'terms'] as DocKind[]).map((k) => (
            <div key={k} className="flex items-baseline gap-2">
              <span className="w-16 shrink-0 text-micro text-ink-3">{k}</span>
              <a
                href={urls[k]}
                target="_blank"
                rel="noreferrer"
                className="min-w-0 flex-1 truncate font-mono text-micro text-accent"
              >
                {urls[k]}
              </a>
            </div>
          ))}
        </div>
        <p className="mt-2 text-micro leading-relaxed text-ink-3">
          {published
            ? 'Privacy goes in Play Console under Data safety and App content. Terms goes in the store listing.'
            : 'These will 404 until the first publish.'}
        </p>
      </section>

      {/* ── the two values that must not be placeholders ───────────────────── */}
      <section className="grid gap-3 rounded-card border border-line-soft bg-surface-1 p-3 sm:grid-cols-2 sm:p-4">
        <Field
          label="Contact email"
          hint="Appended to both pages. Play rejects a policy with no way to reach you."
          value={doc.contactEmail}
          onChange={(v) => set('contactEmail', v)}
          mono
        />
        <Field
          label="Governing jurisdiction"
          hint="Appended to the terms, e.g. Kenya."
          value={doc.jurisdiction}
          onChange={(v) => set('jurisdiction', v)}
        />
      </section>

      {/* ── the documents ──────────────────────────────────────────────────── */}
      <section className="rounded-card border border-line-soft bg-surface-1">
        <header className="flex items-center gap-1 border-b border-line-soft px-3 py-2 sm:px-4">
          {(['privacy', 'terms'] as DocKind[]).map((k) => (
            <button
              key={k}
              onClick={() => setTab(k)}
              className={`rounded-lg px-3 py-1.5 text-data capitalize ${
                tab === k ? 'bg-surface-2 text-ink' : 'text-ink-3'
              }`}
            >
              {k}
            </button>
          ))}
          <button
            onClick={() => setPreview((p) => !p)}
            className={`ml-auto rounded-lg px-3 py-1.5 text-data ${
              preview ? 'bg-surface-2 text-ink' : 'text-ink-3'
            }`}
          >
            {preview ? 'Edit' : 'Preview'}
          </button>
        </header>

        {preview ? (
          // The published chrome is not reproduced here: this shows the
          // STRUCTURE the renderer produced, so a listing that came out as a
          // paragraph is obvious. Matching the page's own dark styling would
          // make a rendering mistake harder to see, not easier.
          <div
            className="legal-preview px-3 py-3 sm:px-4"
            dangerouslySetInnerHTML={{ __html: html }}
          />
        ) : (
          <textarea
            value={doc[tab]}
            onChange={(e) => set(tab, e.target.value)}
            rows={28}
            spellCheck
            className="w-full resize-y border-0 bg-transparent px-3 py-3 font-mono text-data leading-relaxed outline-none sm:px-4"
          />
        )}

        <footer className="border-t border-line-soft px-3 py-2 text-micro text-ink-3 sm:px-4">
          <code className="font-mono">## heading</code> ·{' '}
          <code className="font-mono">### sub</code> ·{' '}
          <code className="font-mono">- list</code> ·{' '}
          <code className="font-mono">&gt; callout</code> ·{' '}
          <code className="font-mono">**bold**</code> ·{' '}
          <code className="font-mono">[text](url)</code> · a fenced block becomes
          the permission listing, one <code className="font-mono">NAME — meaning</code> per line.
          Everything else is escaped, so HTML pasted here appears as text.
        </footer>
      </section>

      {problems.length > 0 && (
        <ul className="space-y-1 rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
          {problems.map((p) => (
            <li key={p}>{p}</li>
          ))}
        </ul>
      )}

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

      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] md:static">
        <button
          onClick={save}
          disabled={!dirty || busy || problems.length > 0}
          className="w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy
            ? 'Publishing'
            : problems.length > 0
              ? 'Fix the problems above'
              : dirty
                ? 'Publish privacy and terms'
                : 'No changes'}
        </button>
      </div>
    </div>
  );
}

function Field({
  label,
  hint,
  value,
  onChange,
  mono,
}: {
  label: string;
  hint: string;
  value: string;
  onChange: (v: string) => void;
  mono?: boolean;
}) {
  return (
    <div>
      <label className="block text-micro text-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`mt-1 w-full rounded-lg border border-line bg-surface-2 px-3 py-2 ${
          mono ? 'font-mono text-data' : ''
        }`}
      />
      <p className="mt-1 text-micro leading-relaxed text-ink-3">{hint}</p>
    </div>
  );
}
