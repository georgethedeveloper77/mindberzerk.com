'use client';

import { useMemo, useState } from 'react';

/**
 * A JSON editor for the content packs that do not yet warrant a form.
 *
 * ─── WHY THIS IS NOT A CHAPTER BUILDER, HONESTLY ────────────────────────────
 *
 * The Learn guide is prose in six block types, and a proper editor for it is a
 * block based writing surface: add a paragraph, promote it to a note, reorder,
 * preview. That is a real piece of work, and building a bad version of it would
 * be worse than this, because a half editor invites you to write in it and then
 * fights every edit.
 *
 * So this is deliberately a text box with three things around it that a text box
 * alone does not give you: parse feedback as you type, a structural summary so a
 * broken document is visible before publishing, and the same server side
 * validation everything else goes through. The chapters are edited perhaps once
 * a quarter; the trashmap is edited whenever a device turns up, which is why
 * that one got the form and this one did not.
 */

export interface DocumentSummary {
  label: string;
  value: string;
}

/**
 * THE SUMMARISER LIVES HERE, NOT IN THE PAGE, and that is a fix rather than a
 * preference.
 *
 * It used to arrive as a prop. The page that renders this is a server
 * component and this one is a client component, so passing a function across
 * that boundary is asking React to serialise a closure, which it cannot do:
 * the screen died with "Functions cannot be passed directly to Client
 * Components". Marking the summariser `'use server'` would have compiled and
 * been worse, because it is arithmetic over a document in a textarea and would
 * have become a network round trip per keystroke, and an exposed endpoint.
 *
 * So it is keyed by pack id instead. A pack with no summariser gets an empty
 * strip rather than an error, which is the right answer for a document whose
 * shape nothing here knows yet.
 */
const SUMMARISERS: Record<string, (doc: unknown) => DocumentSummary[]> = {
  'learn-en': (doc) => {
    const root = (doc ?? {}) as { chapters?: unknown; version?: unknown };
    const chapters = Array.isArray(root.chapters) ? root.chapters : [];
    const blocks = chapters.reduce((n: number, c: unknown) => {
      const list = (c as { blocks?: unknown })?.blocks;
      return n + (Array.isArray(list) ? list.length : 0);
    }, 0);
    return [
      { label: 'Guide version', value: String(root.version ?? '0') },
      { label: 'Chapters', value: String(chapters.length) },
      { label: 'Blocks', value: String(blocks) },
    ];
  },
};

export function DocumentEditor({
  packId,
  initial,
  liveVersion,
  unreachable,
}: {
  packId: string;
  initial: unknown | null;
  liveVersion: number;
  unreachable: string | null;
}) {
  const [text, setText] = useState(() =>
    initial === null ? '' : JSON.stringify(initial, null, 2),
  );
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  // Parsed on every keystroke, which is cheap for a document this size and is
  // what makes a stray comma visible where it was typed rather than at publish.
  const parsed = useMemo(() => {
    if (text.trim().length === 0) return { doc: null as unknown, error: null as string | null };
    try {
      return { doc: JSON.parse(text) as unknown, error: null };
    } catch (e) {
      return { doc: null as unknown, error: e instanceof Error ? e.message : String(e) };
    }
  }, [text]);

  const summary = parsed.doc === null ? [] : safeSummary(parsed.doc, SUMMARISERS[packId]);
  const blocked = unreachable !== null;
  const canPublish = !busy && !blocked && parsed.doc !== null && parsed.error === null;

  async function publish() {
    if (parsed.doc === null) return;
    setBusy(true);
    setMessage(null);
    try {
      const res = await fetch('/api/publish/content', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packId, document: parsed.doc }),
      });
      const body = (await res.json()) as { error?: string; version?: number };
      setMessage(
        res.ok
          ? { tone: 'ok', text: `Published pack v${body.version}.` }
          // Server validation messages name the exact chapter and block, so
          // they are shown verbatim rather than summarised into "invalid".
          : { tone: 'bad', text: body.error ?? `HTTP ${res.status}` },
      );
    } catch (e) {
      setMessage({ tone: 'bad', text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      {blocked && (
        <p className="rounded-[14px] border border-site-plan/40 bg-site-plan/10 px-4 py-3 text-[12.5px] text-site-ink">
          {unreachable}. Publishing is disabled.
        </p>
      )}

      <div className="flex flex-wrap items-center gap-4 text-[12.5px] text-site-ink-3">
        <span>
          Live pack <strong className="text-site-ink">v{liveVersion || 0}</strong>
        </span>
        {summary.map((s) => (
          <span key={s.label}>
            {s.label} <strong className="text-site-ink">{s.value}</strong>
          </span>
        ))}
        {parsed.error && <span className="text-site-plan">Not valid JSON: {parsed.error}</span>}
      </div>

      <textarea
        spellCheck={false}
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={28}
        className="w-full rounded-[14px] border border-site-line bg-site-page px-3 py-2.5 font-mono text-[12px] leading-relaxed text-site-ink outline-none focus:border-site-accent"
        placeholder="Paste or edit the document"
      />

      <div className="flex items-center gap-3">
        <button
          type="button"
          disabled={!canPublish}
          onClick={publish}
          className="rounded-lg border border-site-accent bg-site-accent px-4 py-2 text-xs font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-45"
        >
          {busy ? 'Publishing' : 'Sign and publish'}
        </button>
        {message && (
          <span
            className={`text-[12.5px] ${
              message.tone === 'ok' ? 'text-site-ok' : 'text-site-plan'
            }`}
          >
            {message.text}
          </span>
        )}
      </div>
    </div>
  );
}

/**
 * A summariser that throws must not take the editor down with it.
 *
 * It runs against whatever is in the box, which during editing is frequently a
 * half finished document with a missing field. Crashing there would blank the
 * screen mid keystroke.
 */
function safeSummary(
  doc: unknown,
  summarise: ((doc: unknown) => DocumentSummary[]) | undefined,
): DocumentSummary[] {
  if (!summarise) return [];
  try {
    return summarise(doc);
  } catch {
    return [];
  }
}
