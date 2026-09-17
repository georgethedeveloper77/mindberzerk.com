'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { mergeThemeJson, patchPaths } from '@/lib/g-launcher/theme-json-merge';
import {
  canonicalThemeJson,
  importTheme,
  type ThemeSpecJson,
} from '@/lib/g-launcher/theme-spec';

/**
 * PATCH THE SPEC BEING EDITED, IN THE WORKSPACE.
 *
 * ─── WHY THIS DOES NOT CALL THE SERVER ACTION ──────────────────────────────
 *
 * The rail on the distros list has no form open, so its editor writes the
 * draft straight to the bucket. Here the draft lives in this component's React
 * state and is written by Save. A server-side patch would land underneath an
 * open form, and the next Save would send the form's stale spec straight over
 * the top of it. The patch would vanish with no error, which is the whole
 * class of bug `writeDraft`'s merge-base comment is about.
 *
 * So this applies to the FORM. `setSpec` takes the merged result, every tab
 * redraws with it, the preview redraws with it, and Save writes it the way it
 * writes any other edit. One door.
 *
 * ─── THE MERGE IS THE SAME CODE THE ACTION USES ────────────────────────────
 *
 * `mergeThemeJson` and `importTheme` are pure and have no `server-only`
 * marker, which is what lets `GeneratedJson` canonicalise in the browser too.
 * Two implementations of "merge a patch" is how the rail and the workspace
 * start disagreeing about what a patch means.
 */
export function SpecJsonPatch({
  spec,
  onApply,
}: {
  spec: ThemeSpecJson;
  onApply: (next: ThemeSpecJson) => void;
}) {
  const [open, setOpen] = React.useState(false);
  const [raw, setRaw] = React.useState('');

  /**
   * MERGE OR REPLACE.
   *
   * The box opens holding the whole current file, so the two modes agree until
   * a key is DELETED: merge keeps what the text does not mention, replace
   * treats the text as the entire document. Deleting `"wallpapers"` does
   * nothing in one and strips the art in the other.
   */
  const [replace, setReplace] = React.useState(false);

  const current = React.useMemo(() => canonicalThemeJson(spec), [spec]);

  const outcome = React.useMemo(() => {
    const text = raw.trim();
    if (!text) return null;

    let patch: unknown;
    try {
      patch = JSON.parse(text);
    } catch (e) {
      return { error: `Not JSON: ${(e as Error).message}` } as const;
    }
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
      return { error: 'The patch must be a JSON object.' } as const;
    }

    // Merged over the CANONICAL form, so the document being patched is the
    // one shown in the preview underneath rather than the in-memory shape,
    // which carries keys the canonicaliser drops.
    const base = JSON.parse(current) as Record<string, unknown>;
    const imported = importTheme(
      replace ? (patch as Record<string, unknown>) : mergeThemeJson(base, patch),
    );
    if ('error' in imported) return { error: imported.error } as const;

    return {
      spec: imported.spec,
      notes: imported.notes,
      paths: replace
        ? Object.keys(base)
            .filter((k) => !(k in (patch as Record<string, unknown>)))
            .map((k) => `${k} (removed)`)
        : patchPaths(patch),
      canonical: canonicalThemeJson(imported.spec),
    } as const;
  }, [raw, current, replace]);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => {
          // Opens holding the REAL file. A box that starts empty is a patch
          // form wearing an editor's clothes: you cannot read what is there,
          // so you cannot delete a key or fix a typo in place.
          setRaw(current);
          setOpen(true);
        }}
        style={btn(C.amber)}
      >
        edit theme.json
      </button>
    );
  }

  const ready = outcome != null && !('error' in outcome);

  return (
    <div
      style={{
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 10,
        background: C.surface,
        overflow: 'hidden',
        marginBottom: 14,
      }}
    >
      <header
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '10px 14px',
          borderBottom: `1px solid ${C.lineSoft}`,
          fontFamily: C.mono,
          fontSize: 11,
          letterSpacing: '0.14em',
          color: C.dim,
        }}
      >
        <span>theme.json</span>
        <div style={{ display: 'flex', gap: 7, alignItems: 'center' }}>
          <button
            type="button"
            onClick={() => setReplace((v) => !v)}
            style={btn(replace ? C.amber : C.dim)}
          >
            {replace ? 'replace whole file' : 'merge'}
          </button>
          <button type="button" onClick={() => setRaw(current)} style={btn(C.dim)}>
            reset
          </button>
          <button type="button" onClick={() => setOpen(false)} style={btn(C.faint)}>
            close
          </button>
        </div>
      </header>

      <textarea
        spellCheck={false}
        value={raw}
        onChange={(e) => setRaw(e.target.value)}
        onKeyDown={(e) => {
          // Tab INDENTS rather than leaving the field. Tabbing to the next
          // control is never what was meant inside a hundred lines of JSON.
          if (e.key !== 'Tab') return;
          e.preventDefault();
          const el = e.currentTarget;
          const { selectionStart: a, selectionEnd: b, value } = el;
          setRaw(`${value.slice(0, a)}  ${value.slice(b)}`);
          requestAnimationFrame(() => el.setSelectionRange(a + 2, a + 2));
        }}
        style={{
          width: '100%',
          minHeight: 380,
          resize: 'vertical',
          background: 'transparent',
          border: 0,
          outline: 'none',
          padding: 12,
          color: C.ink,
          fontFamily: C.mono,
          fontSize: 12,
          lineHeight: 1.6,
        }}
      />

      <div
        style={{
          display: 'flex',
          gap: 9,
          alignItems: 'center',
          flexWrap: 'wrap',
          padding: '9px 12px',
          borderTop: `1px solid ${C.lineSoft}`,
        }}
      >
        <button
          type="button"
          disabled={!ready}
          onClick={() => {
            if (!ready) return;
            onApply(outcome.spec);
            setRaw('');
          }}
          style={btn(ready ? C.green : C.faint)}
        >
          merge into this distro
        </button>
        <span style={{ fontFamily: C.mono, fontSize: 10.5, color: C.faint }}>
          {replace
            ? 'the text IS the file \u00b7 a key you delete is gone \u00b7 save publishes it'
            : 'arrays replaced whole \u00b7 null removes a key \u00b7 save publishes it'}
        </span>
      </div>

      {outcome ? (
        <div style={{ borderTop: `1px solid ${C.lineSoft}`, padding: '10px 12px' }}>
          {'error' in outcome ? (
            <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.red }}>{outcome.error}</div>
          ) : (
            <>
              <div style={{ fontFamily: C.mono, fontSize: 11, color: C.dim, lineHeight: 1.8 }}>
                {outcome.paths.join('  ') || 'nothing to change'}
              </div>
              {/* Amber, never red: an import note is a true report about a
                  spec, and colouring it as an error trains the eye past the
                  colour that means something is broken. */}
              {outcome.notes.length ? (
                <ul style={{ margin: '8px 0 0', paddingLeft: 18 }}>
                  {outcome.notes.map((n, i) => (
                    <li
                      key={i}
                      style={{ fontFamily: C.mono, fontSize: 11, color: C.amber, lineHeight: 1.7 }}
                    >
                      {n}
                    </li>
                  ))}
                </ul>
              ) : null}
            </>
          )}
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
