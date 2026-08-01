'use client';

import * as React from 'react';
import { C } from './console';
import { canonicalThemeJson, validateDraft, type ThemeDraft } from '@/lib/g-launcher/theme-spec';

export function GeneratedJson({ draft }: { draft: ThemeDraft }) {
  const json = React.useMemo(() => canonicalThemeJson(draft.spec), [draft.spec]);
  const problems = React.useMemo(() => validateDraft(draft), [draft]);
  const [copied, setCopied] = React.useState(false);
  const valid = problems.length === 0;

  async function copy() {
    try {
      await navigator.clipboard.writeText(json);
      setCopied(true);
      setTimeout(() => setCopied(false), 1400);
    } catch {
      /* clipboard blocked; the text is visible to select by hand */
    }
  }

  return (
    <div style={{ border: `1px solid ${C.lineSoft}`, borderRadius: 10, background: C.surface, overflow: 'hidden' }}>
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 14px',
          borderBottom: `1px solid ${C.lineSoft}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontFamily: C.mono, fontSize: 11, letterSpacing: '0.14em', color: C.dim }}>
            theme.json
          </span>
          <span
            style={{
              fontFamily: C.mono,
              fontSize: 11,
              color: valid ? C.green : C.red,
            }}
          >
            {valid ? '✓ valid' : `✗ ${problems.length} ${problems.length === 1 ? 'problem' : 'problems'}`}
          </span>
        </div>
        <button
          type="button"
          className="tb-btn"
          onClick={copy}
          style={{
            fontFamily: C.mono,
            fontSize: 11.5,
            color: copied ? C.green : C.amber,
            background: 'transparent',
            border: `1px solid ${C.line}`,
            borderRadius: 6,
            padding: '4px 10px',
          }}
        >
          {copied ? 'copied' : 'copy'}
        </button>
      </header>

      {!valid ? (
        <ul style={{ margin: 0, padding: '10px 14px 10px 30px', borderBottom: `1px solid ${C.lineSoft}` }}>
          {problems.map((p, i) => (
            <li key={i} style={{ fontFamily: C.mono, fontSize: 12, color: C.red, marginBottom: 3 }}>
              {p}
            </li>
          ))}
        </ul>
      ) : null}

      <pre
        className="tb-scroll"
        style={{
          margin: 0,
          padding: 14,
          maxHeight: 340,
          overflow: 'auto',
          fontFamily: C.mono,
          fontSize: 12,
          lineHeight: 1.55,
          color: C.ink,
          whiteSpace: 'pre',
        }}
      >
        {json}
      </pre>
    </div>
  );
}
