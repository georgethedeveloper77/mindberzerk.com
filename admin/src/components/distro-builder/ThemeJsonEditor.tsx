'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { C } from '@/components/theme-builder/console';
import { canonicalThemeJson, type ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

interface Result {
  ok: boolean;
  canonical?: string;
  paths?: string[];
  problems?: string[];
  detail: string;
}

/**
 * PASTE PART OF A theme.json AND HAVE IT MERGED INTO THE DRAFT.
 *
 * ─── PARTIAL, NOT A WHOLE FILE ─────────────────────────────────────────────
 *
 * A published spec runs past a hundred keys. Retyping all of them to change a
 * panel is how a distro loses its wallpapers while someone fixes a clock, so
 * this takes what changes and `mergeThemeJson` does the rest. Arrays are
 * replaced whole, which is what an author means when they paste a `modules`
 * list.
 *
 * ─── PREVIEW IS NOT OPTIONAL, IT IS THE POINT ──────────────────────────────
 *
 * `canonicalThemeJson` rebuilds the spec field by field, so what you type is
 * not always what ships. The right pane is the canonical result of this exact
 * patch, which is the only place a silent rewrite is visible before it is
 * signed. Apply is enabled by having read it.
 */
export function ThemeJsonEditor({
  app,
  id,
  spec,
  action,
}: {
  app: string;
  id: string;
  /** The draft's current spec, used to prefill the box with its real file. */
  spec: ThemeSpecJson;
  /**
   * THE SERVER ACTION ITSELF, not a closure over it. A `'use server'` export
   * crosses the boundary as a callable reference; an arrow written here does
   * not, and fails at render.
   */
  action: (
    app: string,
    id: string,
    raw: string,
    opts: { apply: boolean; republish: boolean; replace: boolean },
  ) => Promise<Result>;
}) {
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [raw, setRaw] = React.useState('');
  const [result, setResult] = React.useState<Result | null>(null);
  const [previewed, setPreviewed] = React.useState(false);
  const [pending, start] = React.useTransition();

  /**
   * MERGE OR REPLACE.
   *
   * The box opens holding the whole current file, so both modes start from the
   * same text and behave identically until a key is DELETED. Merge keeps what
   * the text does not mention; replace treats the text as the entire document.
   * Deleting `"wallpapers"` therefore does nothing in one and strips the art in
   * the other, which is a difference worth a switch rather than a guess.
   */
  const [replace, setReplace] = React.useState(false);

  const current = React.useMemo(() => canonicalThemeJson(spec), [spec]);

  // A new selection in the rail must not leave the previous distro's patch in
  // the box, which would apply it to the wrong pack on the next press.
  React.useEffect(() => {
    setRaw('');
    setResult(null);
    setPreviewed(false);
    setOpen(false);
  }, [id]);

  // Opening loads the REAL file rather than an empty box. An editor that
  // starts blank is a patch form wearing an editor's clothes: you cannot read
  // what is there, so you cannot delete a key or fix a typo in place, which is
  // most of what anyone opens a JSON editor to do.
  const openEditor = () => {
    setRaw(current);
    setResult(null);
    setPreviewed(false);
    setOpen(true);
  };

  const run = (apply: boolean, republish: boolean) => {
    start(async () => {
      const out = await action(app, id, raw, { apply, republish, replace });
      setResult(out);
      if (!apply) setPreviewed(out.ok);
      if (apply && out.ok) {
        setPreviewed(false);
        router.refresh();
      }
    });
  };

  if (!open) {
    return (
      <button type="button" onClick={openEditor} style={btn(C.amber)}>
        edit theme.json
      </button>
    );
  }

  const ready = raw.trim().length > 0 && !pending;

  return (
    <div
      style={{
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 9,
        marginTop: 10,
        overflow: 'hidden',
      }}
    >
      <header
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '9px 12px',
          borderBottom: `1px solid ${C.lineSoft}`,
          fontFamily: C.mono,
          fontSize: 11,
          letterSpacing: '0.12em',
          color: C.dim,
        }}
      >
        <span>theme.json &middot; {id}</span>
        <div style={{ display: 'flex', gap: 7, alignItems: 'center' }}>
          <button
            type="button"
            onClick={() => {
              setReplace((v) => !v);
              setPreviewed(false);
            }}
            style={btn(replace ? C.amber : C.dim)}
          >
            {replace ? 'replace whole file' : 'merge'}
          </button>
          <button
            type="button"
            onClick={() => {
              setRaw(current);
              setPreviewed(false);
            }}
            style={btn(C.dim)}
          >
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
        onChange={(e) => {
          setRaw(e.target.value);
          // Any edit invalidates the preview that enabled Apply, so the button
          // cannot be armed by one document and fired with another.
          setPreviewed(false);
        }}
        onKeyDown={(e) => {
          // Tab INDENTS instead of leaving the field. In a box holding a
          // hundred lines of JSON, tabbing to the next control is never what
          // was meant, and losing the caret mid-edit is how a stray brace ends
          // up in a file that used to parse.
          if (e.key !== 'Tab') return;
          e.preventDefault();
          const el = e.currentTarget;
          const { selectionStart: a, selectionEnd: b, value } = el;
          const next = `${value.slice(0, a)}  ${value.slice(b)}`;
          setRaw(next);
          setPreviewed(false);
          requestAnimationFrame(() => el.setSelectionRange(a + 2, a + 2));
        }}
        style={{
          width: '100%',
          minHeight: 420,
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
          gap: 8,
          flexWrap: 'wrap',
          alignItems: 'center',
          padding: '9px 12px',
          borderTop: `1px solid ${C.lineSoft}`,
        }}
      >
        <button
          type="button"
          onClick={() => run(false, false)}
          disabled={!ready}
          style={btn(ready ? C.dim : C.faint)}
        >
          {pending ? 'working' : 'preview'}
        </button>
        <button
          type="button"
          onClick={() => run(true, false)}
          disabled={!previewed || pending}
          style={btn(previewed && !pending ? C.green : C.faint)}
        >
          apply to draft
        </button>
        <button
          type="button"
          onClick={() => run(true, true)}
          disabled={!previewed || pending}
          style={btn(previewed && !pending ? C.amber : C.faint)}
        >
          apply and republish
        </button>
        <span style={{ fontFamily: C.mono, fontSize: 10.5, color: C.faint }}>
          {replace
            ? 'the text IS the file \u00b7 a key you delete is gone'
            : 'merged over the draft \u00b7 arrays replaced whole \u00b7 null removes a key'}
        </span>
      </div>

      {result ? (
        <div style={{ borderTop: `1px solid ${C.lineSoft}`, padding: '10px 12px' }}>
          <div
            style={{
              fontFamily: C.mono,
              fontSize: 11.5,
              color: result.ok ? C.green : C.red,
              marginBottom: result.paths?.length ? 6 : 0,
            }}
          >
            {result.detail}
          </div>

          {result.paths?.length ? (
            <div style={{ fontFamily: C.mono, fontSize: 11, color: C.dim, lineHeight: 1.8 }}>
              {result.paths.join('  ')}
            </div>
          ) : null}

          {/* Amber, never red. An import note is a true report about a spec,
              and colouring it as an error trains the eye past the colour that
              means something is broken. */}
          {result.problems?.length ? (
            <ul style={{ margin: '8px 0 0', paddingLeft: 18 }}>
              {result.problems.map((p, i) => (
                <li
                  key={i}
                  style={{ fontFamily: C.mono, fontSize: 11, color: C.amber, lineHeight: 1.7 }}
                >
                  {p}
                </li>
              ))}
            </ul>
          ) : null}

          {result.canonical ? (
            <pre
              className="tb-scroll"
              style={{
                margin: '10px 0 0',
                padding: 10,
                maxHeight: 260,
                overflow: 'auto',
                border: `1px solid ${C.lineSoft}`,
                borderRadius: 7,
                fontFamily: C.mono,
                fontSize: 11.5,
                lineHeight: 1.55,
                color: C.ink,
                whiteSpace: 'pre',
              }}
            >
              {result.canonical}
            </pre>
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
