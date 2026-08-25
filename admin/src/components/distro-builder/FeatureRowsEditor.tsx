'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { Section, Field, TextInput } from '@/components/theme-builder/primitives';
import type { ThemeFeatureJson } from '@/lib/g-launcher/theme-spec';

/**
 * THE ROWS A STOREFRONT CARD NAMES.
 *
 * ─── THE FOLD LINE IS THE WHOLE POINT ───────────────────────────────────────
 *
 * `theme_catalog` shows the first two `exclusive` rows on the card and leaves
 * the rest for the detail page. Written as a plain list with that rule in a
 * hint, the author has to hold it in their head while writing; written with a
 * divider, the rule is spatial and toggling `exclusive` off visibly drops a row
 * below the line.
 *
 * That matters more than it sounds. `exclusive` is not decoration: it is the
 * entire price argument, and `ThemeFeature`'s own doc says a distro whose rows
 * are all false is selling a palette. A checkbox nobody looks at would leave
 * that argument unmade, which is roughly how Manjaro reached the store.
 *
 * ─── ORDER IS SORTED NOWHERE ────────────────────────────────────────────────
 *
 * Not here, not in `canonicalThemeJson`, not in `buildIndex`, not on the
 * device. The first two exclusive rows sell, so the order they are dragged into
 * IS the editorial decision, and any sort in the pipeline quietly takes it away
 * from whoever wrote them.
 */
export function FeatureRowsEditor(props: {
  rows: ThemeFeatureJson[];
  setRows: (rows: ThemeFeatureJson[]) => void;
  /** Drives the verdict only. A free distro naming no exclusive row is fine. */
  free: boolean;
}) {
  const { rows, setRows, free } = props;
  const [dragFrom, setDragFrom] = React.useState<number | null>(null);

  // The card's rule, applied here exactly as the device applies it, so what the
  // editor calls "on the card" and what the card draws cannot drift.
  const selling = rows.filter((r) => r.exclusive && r.title.trim()).slice(0, 2);
  const sells = (r: ThemeFeatureJson) => selling.includes(r);
  const foldAt = rows.findIndex((r) => !sells(r));

  const patch = (i: number, p: Partial<ThemeFeatureJson>) =>
    setRows(rows.map((r, n) => (n === i ? { ...r, ...p } : r)));

  const drop = (to: number) => {
    if (dragFrom === null || dragFrom === to) return;
    const next = [...rows];
    const [moved] = next.splice(dragFrom, 1);
    next.splice(to, 0, moved);
    setDragFrom(null);
    setRows(next);
  };

  return (
    <Section
      title="feature rows"
      hint="the card shows the first two exclusive rows, in this order"
      right={
        <button
          type="button"
          onClick={() => setRows([...rows, { title: '', body: '', exclusive: true }])}
          style={{
            background: 'none',
            border: 'none',
            color: C.green,
            fontFamily: C.mono,
            fontSize: 11.5,
            cursor: 'pointer',
            padding: 0,
          }}
        >
          + add row
        </button>
      }
    >
      {rows.length === 0 ? (
        <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, lineHeight: 1.6 }}>
          No rows. A bundled distro keeps whatever its floor card authored in Dart; a CDN distro
          shows a bare card with a name and a price.
        </div>
      ) : null}

      {selling.length ? (
        <div
          style={{
            fontFamily: C.mono,
            fontSize: 10.5,
            letterSpacing: '0.14em',
            color: C.green,
            marginBottom: 8,
          }}
        >
          on the card
        </div>
      ) : null}

      {rows.map((r, i) => (
        <React.Fragment key={i}>
          {i === foldAt && foldAt !== -1 && selling.length ? <Fold /> : null}
          <div
            draggable
            onDragStart={() => setDragFrom(i)}
            onDragOver={(e) => e.preventDefault()}
            onDrop={() => drop(i)}
            style={{
              background: sells(r) ? C.surface : C.bg,
              border: `1px solid ${C.lineSoft}`,
              borderLeft: `2px solid ${sells(r) ? C.green : C.lineSoft}`,
              borderRadius: 8,
              padding: 10,
              marginBottom: 7,
              opacity: sells(r) ? 1 : 0.8,
            }}
          >
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
              <span
                aria-hidden
                style={{ color: C.faint, cursor: 'grab', fontSize: 14, lineHeight: 1, userSelect: 'none' }}
              >
                ⠿
              </span>
              <div style={{ flex: 1 }}>
                <TextInput
                  value={r.title}
                  placeholder="Cube drawer"
                  mono={false}
                  onChange={(v) => patch(i, { title: v })}
                />
              </div>
              <button
                type="button"
                onClick={() => setRows(rows.filter((_, n) => n !== i))}
                title="Remove row"
                style={{
                  background: 'none',
                  border: 'none',
                  color: C.faint,
                  cursor: 'pointer',
                  fontSize: 15,
                  lineHeight: 1,
                  padding: '0 2px',
                }}
              >
                ×
              </button>
            </div>

            <TextInput
              value={r.body}
              placeholder="One short sentence. It sits beside the title."
              mono={false}
              onChange={(v) => patch(i, { body: v })}
            />

            <label
              style={{
                display: 'inline-flex',
                gap: 8,
                alignItems: 'center',
                marginTop: 9,
                cursor: 'pointer',
                fontSize: 12,
                color: C.dim,
              }}
            >
              <input
                type="checkbox"
                checked={r.exclusive}
                onChange={(e) => patch(i, { exclusive: e.target.checked })}
              />
              exclusive
              <span style={{ fontFamily: C.mono, fontSize: 11, color: C.faint }}>
                settings cannot reproduce this
              </span>
            </label>
          </div>
        </React.Fragment>
      ))}

      <Verdict free={free} rows={rows} selling={selling.length} />
    </Section>
  );
}

function Fold() {
  return (
    <div style={{ position: 'relative', margin: '15px 0 12px' }}>
      <div style={{ borderTop: `1px dashed ${C.line}` }} />
      <span
        style={{
          position: 'absolute',
          top: -8,
          left: '50%',
          transform: 'translateX(-50%)',
          background: C.surface,
          padding: '0 8px',
          fontFamily: C.mono,
          fontSize: 10,
          letterSpacing: '0.14em',
          color: C.faint,
        }}
      >
        detail page only
      </span>
    </div>
  );
}

/**
 * The price argument, checked at authoring time rather than discovered after
 * publish.
 *
 * FREE IS NOT WARNED. A free distro that is honestly just a palette is a fine
 * thing to ship, and warning about it would train the author to ignore the bar
 * on the distros where it matters.
 */
function Verdict({ free, rows, selling }: { free: boolean; rows: ThemeFeatureJson[]; selling: number }) {
  const titled = rows.filter((r) => r.title.trim()).length;
  if (!titled) return null;

  // ANNOTATED, because `C` is `as const` and an inferred `let` would take the
  // literal type of whichever token happened to be first, refusing every other
  // token below it.
  let tone: string = C.green;
  let text = `${selling} exclusive rows. This card has something to sell.`;

  if (selling === 0) {
    tone = free ? C.faint : C.red;
    text = free
      ? 'No exclusive rows. Fine for a free distro; the card will show none.'
      : 'Paid distro with no exclusive row. This card is selling a palette.';
  } else if (selling === 1) {
    tone = C.amber;
    text = 'Only one exclusive row. The card has a gap where the second should be.';
  }

  return (
    <div
      style={{
        marginTop: 12,
        border: `1px solid ${tone}`,
        borderRadius: 7,
        padding: '8px 11px',
        fontFamily: C.mono,
        fontSize: 11.5,
        color: tone,
      }}
    >
      {text}
    </div>
  );
}
