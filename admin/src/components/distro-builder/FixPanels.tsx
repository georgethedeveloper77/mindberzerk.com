'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { C } from '@/components/theme-builder/console';

type Outcome = { id: string; ok: boolean; detail: string };

/**
 * STRIP THE MODULES ANDROID ALREADY DRAWS, ACROSS EVERY DRAFT.
 *
 * ─── TWO BUTTONS, NOT ONE WITH A CONFIRM ───────────────────────────────────
 *
 * A confirm dialog asks "are you sure" about a change nobody has seen yet.
 * Preview runs the same code with `apply: false` and prints exactly what would
 * happen, per pack, which is the only form of sure worth having on a bulk
 * edit. Apply is enabled by having read it.
 *
 * ─── AND IT DOES NOT PUBLISH ───────────────────────────────────────────────
 *
 * Same contract as `FillFeatureRows` beside it. The drafts change here; the
 * eight republishes are a separate, deliberate act with their own button,
 * because each one re-signs the index and bumps a version.
 */
export function FixPanels({
  app,
  action,
}: {
  app: string;
  /**
   * THE SERVER ACTION ITSELF, not a closure over it. A `'use server'` export is
   * passable across the boundary because what crosses is a callable reference;
   * an arrow written at the call site is not, and fails at render.
   */
  action: (app: string, apply: boolean) => Promise<Outcome[]>;
}) {
  const router = useRouter();
  const [results, setResults] = React.useState<Outcome[] | null>(null);
  const [applied, setApplied] = React.useState(false);
  const [pending, start] = React.useTransition();

  const run = (apply: boolean) => {
    setResults(null);
    start(async () => {
      const out = await action(app, apply);
      setResults(out);
      setApplied(apply);
      // The workspace reads drafts server-side, so without this the forms keep
      // showing the panels this just rewrote.
      if (apply) router.refresh();
    });
  };

  // Counted off the details rather than tracked separately, so the summary and
  // the list below it cannot disagree.
  const touched = results?.filter((r) => r.detail.includes('remov')) ?? [];
  const failed = results?.filter((r) => !r.ok) ?? [];

  return (
    <div
      style={{
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 9,
        padding: '11px 13px',
        marginBottom: 14,
      }}
    >
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
        <button
          type="button"
          onClick={() => run(false)}
          disabled={pending}
          style={btn(pending ? C.faint : C.dim)}
        >
          {pending ? 'reading drafts' : 'preview panel fix'}
        </button>
        <button
          type="button"
          onClick={() => run(true)}
          // Enabled only after a preview, so the first press of the destructive
          // one is never the first thing that happens.
          disabled={pending || !results || applied}
          style={btn(!results || applied ? C.faint : C.green)}
        >
          apply to drafts
        </button>
        <span style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, lineHeight: 1.5 }}>
          removes clock, battery, wifi and volume from TOP panels. keeps tray, keeps bottom
          panels, skips any distro that hides the system bar. never publishes.
        </span>
      </div>

      {results ? (
        <div style={{ marginTop: 11 }}>
          <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.dim, marginBottom: 7 }}>
            {touched.length} {applied ? 'fixed' : 'to fix'}, {results.length - touched.length}{' '}
            skipped
            {failed.length ? `, ${failed.length} failed` : ''}
            {applied ? ' \u00B7 drafts written, nothing published yet' : ''}
          </div>

          {results.map((r) => (
            <div
              key={r.id}
              style={{
                display: 'flex',
                gap: 10,
                fontFamily: C.mono,
                fontSize: 11,
                lineHeight: 1.9,
                color: !r.ok ? C.red : r.detail.includes('remov') ? C.amber : C.faint,
              }}
            >
              <span style={{ minWidth: 200, color: C.dim }}>{r.id}</span>
              <span>{r.detail}</span>
            </div>
          ))}

          {applied && touched.length ? (
            <div
              style={{
                marginTop: 10,
                borderTop: `1px solid ${C.lineSoft}`,
                paddingTop: 9,
                fontFamily: C.mono,
                fontSize: 11,
                color: C.amber,
                lineHeight: 1.7,
              }}
            >
              These are drafts. Select the {touched.length} above and republish to put them on the
              CDN, then rerun scripts/audit-panels.sh against the live index.
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function btn(color: string): React.CSSProperties {
  return {
    background: 'none',
    border: `1px solid ${C.lineSoft}`,
    borderRadius: 7,
    color,
    fontFamily: C.mono,
    fontSize: 11.5,
    padding: '5px 11px',
    cursor: color === C.faint ? 'default' : 'pointer',
  };
}
