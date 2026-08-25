'use client';

import { useEffect, useState } from 'react';

import type { CoreRole } from '@/lib/g-launcher/icon-pack';
import { fetchGlyphs, glyphToBlob, glyphToDataUrl, type GlyphLite } from '@/lib/g-launcher/glyph-blob';
import {
  candidatesFor,
  loadGlyphStore,
  storeHasArt,
  type GlyphCandidate,
} from '@/lib/g-launcher/glyph-source';
import {
  fillSummary,
  parsePackageList,
  planFill,
  type FillPlan,
} from '@/lib/g-launcher/bulk-fill';
import { mismatchWarning, type SetCharacter } from '@/lib/g-launcher/svg-stroke';

/**
 * THE APPS WITH NO DRAWING, AND WHAT TO DO ABOUT EACH ONE.
 *
 * ─── WHAT THIS REPLACES ─────────────────────────────────────────────────────
 *
 * A row of dashed chips, each a hidden file input. It said which apps were
 * uncovered and offered exactly one answer: go and find a file. That is the
 * right answer when a drawing exists on disk and the wrong one the rest of the
 * time, and the rest of the time is most of the time.
 *
 * ─── THREE ROUTES, RANKED BY HOW LIKELY THEY ARE TO BE RIGHT ────────────────
 *
 *   The line set's own drawing, found by exact package id in a hand-written map
 *   of 32,951 ids. If it is there, it is the answer, and it matches the rest of
 *   the pack because it came from the same set.
 *
 *   A Simple Icons glyph. CC0, one click, and a solid shape. In a set of open
 *   outlines that is a visible mistake, so it is offered with the warning
 *   rather than withheld: the author may be filling the last gap in a brand row
 *   where a solid mark is correct.
 *
 *   A file. Still here, still the only answer when the other two miss.
 */

export interface Gap {
  role: CoreRole;
}

export function IconGaps({
  missing,
  character,
  covered,
  takenSlots,
  onAddFile,
  onAddSvg,
}: {
  missing: CoreRole[];
  /** Whether the set is outlines or solids, so a mismatch can be named. */
  character: SetCharacter;
  /** How many roles are already filled, for the heading. */
  covered: number;
  /** Slots the pack already holds, so a bulk fill does not duplicate them. */
  takenSlots: ReadonlySet<string>;
  onAddFile: (roleId: string, file: File) => void;
  /** Add art that came from a glyph source, as a file named after the role. */
  onAddSvg: (roleId: string, svg: string, name: string) => void;
}) {
  const [open, setOpen] = useState<string | null>(null);

  return (
    <section className="rounded-[18px] border border-site-line bg-site-card p-3 shadow-site-soft sm:p-4">
      <div className="mb-2 flex flex-wrap items-baseline gap-x-3">
        <h2 className="text-[13px] font-medium">Apps with no drawing</h2>
        <span className="text-[11.5px] text-site-ink-3">
          {covered} of {covered + missing.length} covered
        </span>
      </div>

      <BulkFill takenSlots={takenSlots} onAddSvg={onAddSvg} />

      {missing.length === 0 ? (
        <p className="text-[11.5px] leading-relaxed text-site-ink-3">
          Every app in the core set has art. Anything beyond it falls through to
          the generator, which uses your plate and the app&apos;s own drawing.
        </p>
      ) : (
        <div className="flex flex-col gap-1.5">
          {missing.map((role) => (
            <GapRow
              key={role.id}
              role={role}
              character={character}
              expanded={open === role.id}
              onToggle={() => setOpen((v) => (v === role.id ? null : role.id))}
              onAddFile={onAddFile}
              onAddSvg={onAddSvg}
            />
          ))}
        </div>
      )}

      <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
        The dock and the first drawer page are the only icons most people ever
        look at. An app left uncovered still works: it falls through to the
        generator, which keeps your plate and uses the app&apos;s own art.
      </p>
    </section>
  );
}

function GapRow({
  role,
  character,
  expanded,
  onToggle,
  onAddFile,
  onAddSvg,
}: {
  role: CoreRole;
  character: SetCharacter;
  expanded: boolean;
  onToggle: () => void;
  onAddFile: (roleId: string, file: File) => void;
  onAddSvg: (roleId: string, svg: string, name: string) => void;
}) {
  const [setMatches, setSetMatches] = useState<GlyphCandidate[] | null>(null);
  const [brand, setBrand] = useState<GlyphLite[]>([]);
  const [noArt, setNoArt] = useState(false);

  useEffect(() => {
    if (!expanded) return;
    let cancelled = false;

    void loadGlyphStore().then((store) => {
      if (cancelled) return;
      if (!store) {
        setSetMatches([]);
        return;
      }
      if (!storeHasArt(store)) setNoArt(true);
      setSetMatches(candidatesFor(store, role));
    });

    // The brand set is searched by the role's FIRST hint only. Simple Icons is
    // a brand index, so `phone` and `dialer` return unrelated companies, and
    // showing eight of those under an app that has a real drawing waiting is
    // worse than showing none.
    void fetchGlyphs(role.hints[0] ?? role.label).then((g) => {
      if (!cancelled) setBrand(g.slice(0, 6));
    });

    return () => {
      cancelled = true;
    };
  }, [expanded, role]);

  return (
    <div className="rounded-[10px] border border-site-line">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className="flex w-full items-center gap-2 px-3 py-2 text-left"
      >
        <span className="text-[12.5px] text-site-ink-2">{role.label}</span>
        <span className="font-mono text-[10px] text-site-ink-3" title={role.packages.join('\n')}>
          {role.packages.length === 1 ? role.packages[0] : `${role.packages.length} packages`}
        </span>
        <span className="ml-auto font-mono text-[10.5px] text-site-ink-3">
          {expanded ? 'close' : 'find art'}
        </span>
      </button>

      {expanded ? (
        <div className="border-t border-site-line px-3 py-2.5">
          {/* ── from the set itself ─────────────────────────────────────── */}
          {setMatches === null ? (
            <p className="font-mono text-[10.5px] text-site-ink-3">Looking in the line set</p>
          ) : setMatches.length > 0 ? (
            <>
              <p className="mb-1.5 font-mono text-[10px] uppercase tracking-[0.12em] text-site-ink-3">
                From the line set
              </p>
              <div className="flex flex-wrap gap-1.5">
                {setMatches.map((c) => (
                  <Candidate
                    key={c.slug}
                    label={c.slug}
                    note={c.via === 'package' ? `matched ${c.matched}` : 'name match'}
                    strong={c.via === 'package'}
                    warning={mismatchWarning(character, c.svg)}
                    preview={`data:image/svg+xml,${encodeURIComponent(c.svg)}`}
                    onPick={() => onAddSvg(role.id, c.svg, `${role.id}.svg`)}
                  />
                ))}
              </div>
            </>
          ) : (
            <p className="text-[11.5px] leading-relaxed text-site-ink-3">
              {noArt
                ? 'The index knows this app but the glyph bundle on the CDN does not carry its art. Re-run sync-arcticons.mjs with this package in the list.'
                : 'The line set has no drawing for this app.'}
            </p>
          )}

          {/* ── brand marks ─────────────────────────────────────────────── */}
          {brand.length > 0 ? (
            <>
              <p className="mb-1.5 mt-3 font-mono text-[10px] uppercase tracking-[0.12em] text-site-ink-3">
                Brand marks, CC0
              </p>
              <div className="flex flex-wrap gap-1.5">
                {brand.map((g) => {
                  const blob = glyphToBlob(g, '#FFFFFF');
                  return (
                    <Candidate
                      key={g.slug}
                      label={g.slug}
                      note={g.title}
                      strong={false}
                      // Simple Icons are solid paths by construction, so the
                      // warning is computed from the same rule rather than
                      // hardcoded here: if the set is also solid, there is
                      // nothing to warn about and nothing is shown.
                      warning={mismatchWarning(character, `<svg><path fill="#fff" d="${g.path}"/></svg>`)}
                      preview={glyphToDataUrl(g, '#E7EBF0')}
                      onPick={() => {
                        void blob.text().then((svg) => onAddSvg(role.id, svg, `${role.id}.svg`));
                      }}
                    />
                  );
                })}
              </div>
            </>
          ) : null}

          {/* ── a file ──────────────────────────────────────────────────── */}
          <label className="mt-3 inline-block cursor-pointer rounded-lg border border-site-line bg-site-sunk px-3 py-1.5 text-[11.5px] text-site-ink-2">
            Use a file
            <input
              type="file"
              accept="image/png,image/webp,image/jpeg,image/svg+xml"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onAddFile(role.id, f);
                e.target.value = '';
              }}
            />
          </label>
        </div>
      ) : null}
    </div>
  );
}

function Candidate({
  label,
  note,
  strong,
  warning,
  preview,
  onPick,
}: {
  label: string;
  note: string;
  strong: boolean;
  warning: string | null;
  preview: string;
  onPick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onPick}
      title={warning ?? note}
      className="flex w-[104px] flex-col items-center gap-1 rounded-[9px] border p-2 text-center transition"
      style={{
        borderColor: warning
          ? 'var(--color-site-plan)'
          : strong
            ? 'var(--color-site-accent)'
            : 'var(--color-site-line)',
        background: strong ? 'var(--color-site-accent-soft)' : 'transparent',
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={preview} alt="" width={32} height={32} style={{ objectFit: 'contain' }} />
      <span className="w-full truncate font-mono text-[9.5px] text-site-ink-2">{label}</span>
      <span
        className="w-full truncate text-[9px]"
        style={{ color: warning ? 'var(--color-site-plan)' : 'var(--color-site-ink-3)' }}
      >
        {warning ? 'solid, not a line' : note}
      </span>
    </button>
  );
}

/**
 * FILL THE PACK FROM A LIST OF INSTALLED PACKAGES.
 *
 * ─── WHY A TEXTAREA AND NOT A PICKER ────────────────────────────────────────
 *
 * The list comes off a phone, in one command:
 *
 *     adb shell pm list packages | sed 's/^package://' | tr -d '\r'
 *
 * Anything the panel could offer instead would be a worse version of that. It
 * has no device, so a picker would be a list of apps somebody typed in, which
 * is the same paste with more steps and more chances to be wrong.
 *
 * ─── THE COUNT COMES BEFORE THE BUTTON ──────────────────────────────────────
 *
 * Two hundred rows is not undoable in one gesture. So the plan is computed and
 * reported first, including the parts that are not additions: how many folded
 * into shared roles, how many are already in the pack, how many the set has no
 * drawing for. An author who cannot see those three numbers cannot tell a good
 * source list from a bad one.
 */
function BulkFill({
  takenSlots,
  onAddSvg,
}: {
  takenSlots: ReadonlySet<string>;
  onAddSvg: (roleId: string, svg: string, name: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState('');
  const [plan, setPlan] = useState<FillPlan | null>(null);
  const [listed, setListed] = useState(0);
  const [working, setWorking] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  async function preview() {
    setNote(null);
    const packages = parsePackageList(text);
    setListed(packages.length);
    if (packages.length === 0) {
      setPlan(null);
      setNote('Paste one package id per line.');
      return;
    }
    const store = await loadGlyphStore();
    if (!store) {
      setPlan(null);
      setNote('The line-set index could not be read, so there is nothing to match against.');
      return;
    }
    if (!storeHasArt(store)) {
      setPlan(null);
      setNote('The index loaded but carries no art. Re-run sync-arcticons.mjs with a package list and upload glyphs.json.');
      return;
    }
    setPlan(planFill(store, packages, takenSlots));
  }

  async function apply() {
    if (!plan) return;
    setWorking(true);
    // Sequential, like every other intake loop here. Each row decodes and
    // re-encodes a full image, and two hundred at once stalls the tab long
    // enough to look like a crash.
    for (const row of plan.rows) {
      onAddSvg(row.slot, row.svg, `${row.slot}.svg`);
      await new Promise((r) => setTimeout(r, 0));
    }
    setWorking(false);
    setPlan(null);
    setText('');
    setNote(`Added ${plan.rows.length}. They are ordinary rows now, so the style bar restyles them with everything else.`);
  }

  return (
    <div className="mb-3 rounded-[10px] border border-site-line bg-site-sunk p-3">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center gap-2 text-left"
      >
        <span className="text-[12.5px] font-semibold text-site-ink">
          Fill from the line set
        </span>
        <span className="text-[11.5px] text-site-ink-3">
          paste a package list, match all of it at once
        </span>
        <span className="ml-auto font-mono text-[10.5px] text-site-ink-3">
          {open ? 'close' : 'open'}
        </span>
      </button>

      {open ? (
        <div className="mt-2.5">
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={5}
            spellCheck={false}
            placeholder={'com.whatsapp\ncom.instagram.android\ncom.safaricom.mpesa.lifestyle'}
            className="w-full rounded-lg border border-site-line bg-site-card px-2.5 py-2 font-mono text-[11px] text-site-ink-2"
          />
          <p className="mt-1 font-mono text-[10px] leading-relaxed text-site-ink-3">
            adb shell pm list packages | sed &apos;s/^package://&apos; | tr -d &apos;\r&apos;
          </p>

          <div className="mt-2 flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => void preview()}
              disabled={working}
              className="rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-[11.5px] text-site-ink-2"
            >
              Preview
            </button>
            {plan && plan.rows.length > 0 ? (
              <button
                type="button"
                onClick={() => void apply()}
                disabled={working}
                className="rounded-lg bg-site-accent px-3 py-1.5 text-[11.5px] font-semibold text-white"
              >
                {working ? 'Adding' : `Add ${plan.rows.length}`}
              </button>
            ) : null}
            {plan ? (
              <span className="font-mono text-[10.5px] text-site-ink-3">
                {fillSummary(plan, listed)}
              </span>
            ) : null}
          </div>

          {note ? (
            <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">{note}</p>
          ) : null}

          {plan && plan.missed.length > 0 ? (
            <details className="mt-2">
              <summary className="cursor-pointer text-[11.5px] text-site-ink-3">
                {plan.missed.length} apps with no drawing
              </summary>
              <p className="mt-1 font-mono text-[10px] leading-relaxed text-site-ink-3">
                {plan.missed.slice(0, 40).join(', ')}
                {plan.missed.length > 40 ? ', and more' : ''}
              </p>
            </details>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
