'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { renderMarkdown } from '@/lib/core/markdown';
import {
  TEMPLATES,
  blankDocument,
  isRequired,
  validate,
  type LegalDocument,
  type LegalDraft,
} from '@/lib/studio/legal-schema';

/**
 * Editing a set of legal documents.
 *
 * ## The preview is the publish
 *
 * `renderMarkdown` here is the same function `writeLegal` calls, imported from
 * the same module, which is why the renderer lives outside `server-only`. A
 * preview built from a second implementation is a decoration; this one is a
 * guarantee.
 *
 * ## Contact and jurisdiction are fields, not prose
 *
 * They are appended at publish time, contact to every document and governing
 * law to the terms. Left inline they would be placeholders in a wall of text,
 * and a placeholder in paragraph nine is a placeholder that ships.
 *
 * ## One button writes all of them
 *
 * Not one per document. A privacy page from today beside terms from last month
 * is a state Play would notice and nobody else would.
 *
 * ## A SLUG CANNOT BE RENAMED, AND THE UI SIMPLY DOES NOT OFFER IT
 *
 * The slug is the filename and the public URL. Renaming it 404s a link a store,
 * a search engine or a person may already hold. So it is set once when the
 * document is created and shown as read-only text afterwards. The title is
 * freely editable, because nothing links to a title.
 */
export function LegalEditor({
  app,
  initial,
  urlFor,
}: {
  app: string;
  initial: LegalDraft;
  /** Built server-side, because the CDN base is a server env var. */
  urlFor: Record<string, string>;
}) {
  const router = useRouter();

  const [doc, setDoc] = useState<LegalDraft>(initial);
  const [sel, setSel] = useState(0);
  const [preview, setPreview] = useState(false);
  const [adding, setAdding] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const dirty = JSON.stringify(doc) !== JSON.stringify(initial);
  const problems = useMemo(() => validate(doc), [doc]);
  const current: LegalDocument | undefined = doc.documents[sel];

  // Rendered from the CURRENT document only. Rendering all of them on every
  // keystroke is work nobody sees, and these are long.
  const html = useMemo(
    () => (preview && current ? renderMarkdown(current.body) : ''),
    [preview, current],
  );

  function setField<K extends keyof LegalDraft>(key: K, value: LegalDraft[K]) {
    setDoc((d) => ({ ...d, [key]: value }));
  }

  function patchDoc(i: number, next: Partial<LegalDocument>) {
    setDoc((d) => ({
      ...d,
      documents: d.documents.map((x, n) => (n === i ? { ...x, ...next } : x)),
    }));
  }

  function addDoc(slug: string, title: string, body: string) {
    // A slug that already exists would silently overwrite on publish, so the
    // picker refuses rather than creating a duplicate.
    if (doc.documents.some((d) => d.slug === slug)) {
      setMsg({ tone: 'bad', text: `A document already uses /${slug}.` });
      setAdding(false);
      return;
    }
    setDoc((d) => ({ ...d, documents: [...d.documents, { slug, title, body }] }));
    setSel(doc.documents.length);
    setAdding(false);
  }

  function removeDoc(i: number) {
    const d = doc.documents[i];
    if (!d || isRequired(d.slug)) return;
    setDoc((x) => ({ ...x, documents: x.documents.filter((_, n) => n !== i) }));
    setSel((s) => (s >= i ? Math.max(0, s - 1) : s));
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
          text: `Published ${json.pages} ${json.pages === 1 ? 'page' : 'pages'}. Live at the URLs beside this within five minutes.`,
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

  const unused = TEMPLATES.filter((t) => !doc.documents.some((d) => d.slug === t.slug));

  const input =
    'w-full rounded-xl border border-site-line bg-site-sunk px-3 py-2.5 text-sm text-site-ink focus:border-site-accent focus:outline-none';

  return (
    <div className="flex flex-col gap-4">
      {/* ── the slab, same family as every studio screen ── */}
      <section
        className="relative overflow-hidden rounded-[22px] shadow-[0_18px_44px_rgba(23,16,31,0.22)]"
        style={{
          background:
            'radial-gradient(560px 260px at 5% -30%, rgba(255,178,122,0.4), transparent 62%), radial-gradient(420px 240px at 98% 130%, rgba(141,101,255,0.4), transparent 62%), linear-gradient(140deg, #2b2033, #171020 60%, #110c18)',
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
              <span className="size-1.5 rounded-full bg-[#ffb27a] shadow-[0_0_0_3px_rgba(255,178,122,0.2)]" />
              Legal
            </span>
            <h1 className="mt-2 font-site-display text-[25px] font-extrabold text-[#f6f2fd]">
              {doc.documents.length} {doc.documents.length === 1 ? 'document' : 'documents'}, one publish.
            </h1>
          </div>
          <div className="flex-1" />
          {problems.length > 0 && (
            <span className="inline-flex items-center gap-2 rounded-full border border-[rgba(255,139,131,0.3)] bg-[rgba(255,139,131,0.1)] py-1.5 pl-2.5 pr-3 text-[11.5px] font-bold text-[#ffb0a8]">
              <span className="size-1.5 rounded-full bg-[#ff8b83]" />
              {problems.length} {problems.length === 1 ? 'problem' : 'problems'} to fix
            </span>
          )}
          <button
            onClick={save}
            disabled={!dirty || busy || problems.length > 0}
            className="rounded-[10px] bg-white px-4 py-2 text-[13px] font-semibold text-[#1a1226] transition disabled:bg-white/15 disabled:text-white/50"
          >
            {busy ? 'Publishing' : dirty ? 'Publish every page' : 'No changes'}
          </button>
        </div>
      </section>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_330px]">
        <div className="flex flex-col gap-4">
          {/* ── the two values ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            <header className="flex items-center gap-3 px-[18px] py-4">
              <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-plan-soft text-site-plan">
                <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden>
                  <circle cx="8" cy="8" r="6" />
                  <path d="M8 5v3.4M8 10.9v.01" />
                </svg>
              </span>
              <h2 className="font-site-display text-[15px] font-bold text-site-ink">
                Appended to every page on publish
              </h2>
            </header>
            <div className="grid gap-4 px-[18px] pb-[18px] sm:grid-cols-2">
              <div>
                <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Contact email</label>
                <input
                  value={doc.contactEmail}
                  onChange={(e) => setField('contactEmail', e.target.value)}
                  placeholder="info@mindberzerk.com"
                  className={`${input} font-mono`}
                />
                <p className="mt-1.5 text-[11px] leading-relaxed text-site-ink-3">
                  Play rejects a policy with no way to reach you.
                </p>
              </div>
              <div>
                <label className="mb-1.5 block text-[12.5px] font-semibold text-site-ink">Governing jurisdiction</label>
                <input
                  value={doc.jurisdiction}
                  onChange={(e) => setField('jurisdiction', e.target.value)}
                  placeholder="Kenya"
                  className={input}
                />
                <p className="mt-1.5 text-[11px] leading-relaxed text-site-ink-3">
                  Appended to the terms only.
                </p>
              </div>
            </div>
          </section>

          {/* ── the documents ── */}
          <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            <div className="flex flex-wrap items-center gap-1.5 px-[18px] pt-3.5">
              {doc.documents.map((d, i) => (
                <button
                  key={d.slug}
                  onClick={() => {
                    setSel(i);
                    setPreview(false);
                  }}
                  className={`rounded-full px-3.5 py-[7px] text-[13px] font-semibold transition ${
                    sel === i
                      ? 'bg-site-accent-soft text-site-accent-deep'
                      : 'text-site-ink-3 hover:text-site-ink'
                  }`}
                >
                  {d.title || d.slug}
                </button>
              ))}
              <button
                onClick={() => setAdding((a) => !a)}
                className="grid size-7 place-items-center rounded-full border border-dashed border-site-line text-site-ink-3 transition hover:text-site-ink"
                aria-label="Add a document"
              >
                <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden>
                  <path d="M7 2.5v9M2.5 7h9" />
                </svg>
              </button>
              <div className="flex-1" />
              <button
                onClick={() => setPreview((p) => !p)}
                className={`rounded-full px-3.5 py-[7px] text-[13px] font-semibold transition ${
                  preview ? 'bg-site-accent-soft text-site-accent-deep' : 'text-site-ink-3 hover:text-site-ink'
                }`}
              >
                {preview ? 'Edit' : 'Preview'}
              </button>
            </div>

            {/* ── the picker ── */}
            {adding && (
              <div className="mx-[18px] mt-3 rounded-[14px] border border-dashed border-site-line bg-site-sunk p-4">
                <div className="mb-2.5 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
                  Add a document
                </div>
                <div className="flex flex-col gap-2">
                  {unused.map((t) => (
                    <button
                      key={t.slug}
                      onClick={() => addDoc(t.slug, t.title, t.body)}
                      className="rounded-xl border border-site-line bg-site-card px-3.5 py-2.5 text-left transition hover:border-site-accent"
                    >
                      <span className="block text-[13px] font-semibold text-site-ink">{t.title}</span>
                      <span className="block text-[11px] leading-relaxed text-site-ink-3">{t.when}</span>
                    </button>
                  ))}
                  <button
                    onClick={() => {
                      // A blank slug would fail validation loudly rather than
                      // quietly, which is the intent: the person naming it is
                      // the person who knows what it is.
                      const n = doc.documents.length + 1;
                      addDoc(`document-${n}`, `Document ${n}`, blankDocument(`document-${n}`, '').body);
                    }}
                    className="rounded-xl border border-dashed border-site-line px-3.5 py-2.5 text-left text-[13px] font-semibold text-site-ink-3 transition hover:text-site-ink"
                  >
                    Something else, blank
                  </button>
                </div>
              </div>
            )}

            {current && (
              <>
                <div className="mt-3 flex flex-wrap items-center gap-3 border-t border-site-line px-[18px] py-3">
                  <input
                    value={current.title}
                    onChange={(e) => patchDoc(sel, { title: e.target.value })}
                    className="min-w-0 flex-1 rounded-lg border border-transparent bg-transparent px-2 py-1 font-site-display text-[17px] font-bold text-site-ink hover:border-site-line focus:border-site-accent focus:bg-site-sunk focus:outline-none"
                  />
                  <span className="rounded-md bg-site-sunk px-2 py-1 font-mono text-[11px] text-site-ink-3">
                    /{current.slug}.html
                  </span>
                  {isRequired(current.slug) ? (
                    <span className="rounded-full bg-site-ok-soft px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-site-ok">
                      required
                    </span>
                  ) : (
                    <button
                      onClick={() => removeDoc(sel)}
                      className="text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan"
                    >
                      Remove
                    </button>
                  )}
                </div>

                {preview ? (
                  // The published chrome is NOT reproduced here. This shows the
                  // structure the renderer produced, so a listing that came out
                  // as a paragraph is obvious. Matching the page's own styling
                  // would make a rendering mistake harder to see, not easier.
                  <div
                    className="legal-preview px-[18px] py-4"
                    dangerouslySetInnerHTML={{ __html: html }}
                  />
                ) : (
                  <textarea
                    value={current.body}
                    onChange={(e) => patchDoc(sel, { body: e.target.value })}
                    rows={22}
                    spellCheck
                    className="w-full resize-y border-0 bg-transparent px-[18px] py-4 font-mono text-[12.5px] leading-relaxed text-site-ink outline-none"
                  />
                )}
              </>
            )}

            <footer className="border-t border-site-line px-[18px] py-3 text-[11px] leading-relaxed text-site-ink-3">
              <code className="font-mono">## heading</code> &nbsp;
              <code className="font-mono">### sub</code> &nbsp;
              <code className="font-mono">- list</code> &nbsp;
              <code className="font-mono">&gt; callout</code> &nbsp;
              <code className="font-mono">**bold**</code> &nbsp;
              <code className="font-mono">[text](url)</code> &nbsp; a fenced block becomes the
              permission listing. Everything else is escaped, so HTML pasted here appears as text.
            </footer>
          </section>

          {msg && (
            <p
              className={`rounded-[14px] px-4 py-3 text-[13px] leading-relaxed ${
                msg.tone === 'ok'
                  ? 'bg-site-ok-soft text-site-ok'
                  : 'bg-site-plan-soft text-site-plan'
              }`}
            >
              {msg.text}
            </p>
          )}
        </div>

        {/* ── consequence panel ── */}
        <aside className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4">
          <header className="flex items-center gap-3 px-[18px] py-4">
            <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-info-soft text-site-info">
              <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden>
                <path d="M6.6 9.4a3 3 0 004.3 0l1.8-1.8a3 3 0 10-4.3-4.3l-1 1" />
                <path d="M9.4 6.6a3 3 0 00-4.3 0L3.3 8.4a3 3 0 104.3 4.3l1-1" />
              </svg>
            </span>
            <h2 className="font-site-display text-[15px] font-bold text-site-ink">Where these end up</h2>
          </header>
          <div className="px-[18px] pb-[18px]">
            {doc.documents.map((d) => (
              <div
                key={d.slug}
                className="mb-2.5 rounded-xl border border-site-accent/25 bg-site-accent-soft px-3 py-2.5"
              >
                <div className="mb-1 text-[10.5px] font-bold uppercase tracking-[0.05em] text-site-accent-deep">
                  {d.title || d.slug}
                </div>
                <a
                  href={urlFor[d.slug] ?? '#'}
                  target="_blank"
                  rel="noreferrer"
                  className="break-all font-mono text-[10px] leading-relaxed text-site-accent-deep"
                >
                  {urlFor[d.slug] ?? `not published yet, /${d.slug}.html`}
                </a>
              </div>
            ))}

            {problems.length > 0 && (
              <>
                <div className="mb-2 mt-4 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
                  Before publishing
                </div>
                {problems.map((p) => (
                  <p
                    key={p}
                    className="mb-2 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-plan"
                  >
                    {p}
                  </p>
                ))}
              </>
            )}

            <p className="mt-3 border-t border-site-line pt-3 text-[11px] leading-relaxed text-site-ink-3">
              One button writes every page, and each one footer-links to the others. Removing a
              document stops it being rendered and delisted from those footers, but the old object
              stays on the bucket: a legal page that 404s for someone holding the link is worse
              than a stale one.
            </p>
          </div>
        </aside>
      </div>
    </div>
  );
}
