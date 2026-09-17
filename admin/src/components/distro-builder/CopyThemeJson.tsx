'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { canonicalThemeJson, type ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

/**
 * COPY THE CANONICAL theme.json FROM THE RAIL.
 *
 * ─── CANONICAL, NOT THE DRAFT OBJECT ───────────────────────────────────────
 *
 * The same bytes `publishDistro` signs. `GeneratedJson` in the workspace does
 * the same thing, and two copy buttons on one screen handing out two different
 * files is the bug this avoids: the one that matters is always the one that
 * ships.
 */
export function CopyThemeJson({ spec }: { spec: ThemeSpecJson }) {
  const [copied, setCopied] = React.useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(canonicalThemeJson(spec));
      setCopied(true);
      setTimeout(() => setCopied(false), 1400);
    } catch {
      // Clipboard blocked by permissions policy. The same text is readable in
      // the workspace, so this fails quietly rather than throwing a dialog at
      // someone who can get it another way.
    }
  };

  return (
    <button
      type="button"
      onClick={copy}
      style={{
        background: 'none',
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 7,
        color: copied ? C.green : C.dim,
        fontFamily: C.mono,
        fontSize: 11.5,
        padding: '5px 11px',
        cursor: 'pointer',
      }}
    >
      {copied ? 'copied' : 'copy theme.json'}
    </button>
  );
}
