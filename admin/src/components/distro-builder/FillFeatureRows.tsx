'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { C } from '@/components/theme-builder/console';

type Outcome = { id: string; ok: boolean; detail: string };

/**
 * FILL FEATURE ROWS ON EVERY DRAFT THAT HAS NONE.
 *
 * ─── NOT PART OF `BulkBar`, AND THAT IS THE POINT ───────────────────────────
 *
 * `BulkBar` acts on a selection: you tick rows, you press a verb, those rows
 * happen. This acts on every draft that has no rows, which is a different
 * question, and putting it behind a selection would invite the reading that
 * ticking three distros fills only those three. It also has no destructive
 * mode, so it needs neither arming nor the stop-on-first-failure loop that
 * republish needs.
 *
 * ─── IT REPORTS THE SKIPS TOO ───────────────────────────────────────────────
 *
 * A run that fills eight, skips three that already had rows and finds nothing
 * to say about four more is a useful result, and only the last group is worth
 * acting on. Collapsing it to "8 filled" hides the four distros that are asking
 * for money with nothing to sell, which is the thing this whole pass exists to
 * surface.
 */
export function FillFeatureRows({
  app,
  action,
}: {
  app: string;
  /**
   * THE SERVER ACTION ITSELF, not a closure over it. A `'use server'` export is
   * passable across the boundary because what crosses is a callable reference;
   * an arrow function written at the call site is not, and fails at render.
   * Same rule `BulkBar` documents, and the bound argument moves to `app` for
   * the same reason.
   */
  action: (app: string) => Promise<Outcome[]>;
}) {
  const router = useRouter();
  const [results, setResults] = React.useState<Outcome[] | null>(null);
  const [pending, start] = React.useTransition();

  const run = () => {
    setResults(null);
    start(async () => {
      const out = await action(app);
      setResults(out);
      // The workspace reads drafts server-side, so without this the forms keep
      // showing the empty rows this just filled.
      router.refresh();
    });
  };

  // Counted from the details rather than tracked separately, so the summary
  // line and the list below it cannot disagree.
  const empty = results?.filter((r) => r.detail.startsWith('nothing to suggest')) ?? [];
  const palette = results?.filter((r) => r.detail.includes('NONE exclusive')) ?? [];
  const filled = results?.filter((r) => /^\d+ rows/.test(r.detail)) ?? [];

  return (
    <div
      style={{
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 9,
        padding: '11px 13px',
        marginBottom: 14,
      }}
    >
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <button
          type="button"
          onClick={run}
          disabled={pending}
          style={{
            background: 'none',
            border: `1px solid ${C.lineSoft}`,
            borderRadius: 7,
            color: pending ? C.faint : C.green,
            fontFamily: C.mono,
            fontSize: 11.5,
            padding: '5px 11px',
            cursor: pending ? 'default' : 'pointer',
          }}
        >
          {pending ? 'reading specs' : 'suggest feature rows'}
        </button>
        <span style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, lineHeight: 1.5 }}>
          fills any distro with no rows, from its own spec. never overwrites, never publishes.
        </span>
      </div>

      {results ? (
        <div style={{ marginTop: 11 }}>
          <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.dim, marginBottom: 7 }}>
            {filled.length} filled, {results.length - filled.length} skipped
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
                // Amber, never red. Nothing here failed: a distro with nothing
                // exclusive to claim is a true report about a spec, and marking
                // it as an error would train the eye to skip the colour that
                // means something is actually broken.
                color: r.detail.includes('NONE exclusive') ? C.amber : C.faint,
              }}
            >
              <span style={{ minWidth: 200, color: C.dim }}>{r.id}</span>
              <span>{r.detail}</span>
            </div>
          ))}

          {palette.length || empty.length ? (
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
              {palette.length + empty.length} distros have nothing exclusive to claim. Those specs
              set no panel, no desktop icons, no panel editing and no boot log, so there is nothing
              the free settings cannot already do. Better copy will not fix it; the spec has to
              change, and it matters most on the paid ones.
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
