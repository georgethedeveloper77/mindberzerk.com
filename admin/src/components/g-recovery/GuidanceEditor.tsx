'use client';

import { useMemo, useState } from 'react';

/**
 * PER BRAND GUIDANCE. What to tell someone whose phone is not a Samsung.
 *
 * ─── WHY THIS IS KEYED BY MANUFACTURER AND NOT BY ANDROID VERSION ───────────
 *
 * Recovery behaviour diverges far more by OEM skin than by API level. Two
 * phones on the same Android 13 disagree about whether the gallery keeps a bin,
 * how long it keeps it, whether a cloud sync has already deleted the copy you
 * are looking for, and whether the file manager has a recycle folder at all.
 * None of that is discoverable from a version number.
 *
 * ─── THE BLOCK VOCABULARY IS BORROWED, ON PURPOSE ───────────────────────────
 *
 * These are the same six blocks the Learn guide uses, so the app renders brand
 * guidance with `ContentBlockView` and needs no second renderer. A vocabulary
 * of its own would have meant a second set of six cases on the device and a
 * second way for published content to draw wrong on a stranger's phone.
 *
 * ─── AND THE FALLBACK IS THE POINT, NOT AN EDGE CASE ────────────────────────
 *
 * The install base is a long tail. Most devices will never match a brand row,
 * and what they read is the fallback, so it is edited here beside the brands
 * rather than treated as a default nobody looks at.
 */

type BlockType = 'p' | 'h' | 'note' | 'warn' | 'path' | 'list';

interface Block {
  t: BlockType;
  text?: string;
  name?: string;
  items?: string[];
}

interface Brand {
  brand: string;
  label: string;
  summary: string;
  aliases?: string[];
  blocks: Block[];
}

interface Guide {
  id: string;
  version: number;
  generatedAt?: string;
  brands: Brand[];
  fallback?: { blocks: Block[] };
  [k: string]: unknown;
}

const EMPTY: Guide = { id: 'oem-guide', version: 1, brands: [] };

/** The type a new block starts as. Prose is what most rows want. */
const BLOCK_LABELS: Record<BlockType, string> = {
  p: 'paragraph',
  h: 'heading',
  note: 'note',
  warn: 'warning',
  path: 'path',
  list: 'list',
};

export function GuidanceEditor({
  initial,
  liveVersion,
  unreachable,
}: {
  initial: unknown | null;
  liveVersion: number;
  unreachable: string | null;
}) {
  const [doc, setDoc] = useState<Guide>(() => normalise(initial));
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);
  const [open, setOpen] = useState<number | null>(0);

  const counts = useMemo(
    () => ({
      brands: doc.brands.length,
      blocks: doc.brands.reduce((n, b) => n + b.blocks.length, 0),
      aliases: doc.brands.reduce((n, b) => n + (b.aliases?.length ?? 0), 0),
      /** Rows that would fail validation, counted before the server says so. */
      broken: doc.brands.filter(
        (b) =>
          b.brand.trim() === '' ||
          b.brand !== b.brand.toLowerCase() ||
          b.label.trim() === '' ||
          b.summary.trim() === '' ||
          b.blocks.length === 0,
      ).length,
    }),
    [doc],
  );

  function mutateBrand(index: number, patch: Partial<Brand>) {
    setDoc((d) => {
      const brands = [...d.brands];
      brands[index] = { ...brands[index], ...patch };
      return { ...d, brands };
    });
  }

  function addBrand() {
    setDoc((d) => ({
      ...d,
      brands: [...d.brands, { brand: '', label: '', summary: '', blocks: [] }],
    }));
    setOpen(doc.brands.length);
  }

  function removeBrand(index: number) {
    setDoc((d) => ({ ...d, brands: d.brands.filter((_, i) => i !== index) }));
    setOpen(null);
  }

  function moveBrand(index: number, by: number) {
    setDoc((d) => {
      const to = index + by;
      if (to < 0 || to >= d.brands.length) return d;
      const brands = [...d.brands];
      const [row] = brands.splice(index, 1);
      brands.splice(to, 0, row);
      return { ...d, brands };
    });
    setOpen(index + by);
  }

  async function publish() {
    setBusy(true);
    setMessage(null);
    try {
      // Blank rows are dropped on the way out rather than on the way in, so a
      // half typed brand does not vanish under the cursor.
      const brands = doc.brands
        .filter((b) => b.brand.trim() !== '')
        .map((b) => ({
          ...b,
          brand: b.brand.trim().toLowerCase(),
          aliases: b.aliases && b.aliases.length > 0 ? b.aliases : undefined,
        }));
      const document = {
        ...doc,
        id: 'oem-guide',
        brands,
        version: doc.version + 1,
        generatedAt: new Date().toISOString(),
      };
      const res = await fetch('/api/publish/content', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packId: 'oem-guide', document }),
      });
      const body = (await res.json()) as { error?: string; version?: number };
      if (!res.ok) {
        setMessage({ tone: 'bad', text: body.error ?? `HTTP ${res.status}` });
      } else {
        setDoc(document);
        setMessage({
          tone: 'ok',
          text: `Published pack v${body.version}. Devices pick it up on next launch.`,
        });
      }
    } catch (e) {
      setMessage({ tone: 'bad', text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  const blocked = unreachable !== null;

  return (
    <div className="space-y-4">
      {blocked && (
        <p className="rounded-[14px] border border-site-plan/40 bg-site-plan/10 px-4 py-3 text-[12.5px] text-site-ink">
          {unreachable}. Publishing is disabled: editing from an empty document and saving would
          replace the live guide rather than update it.
        </p>
      )}

      <div className="flex flex-wrap items-center gap-4 text-[12.5px] text-site-ink-3">
        <span>
          Live pack <strong className="text-site-ink">v{liveVersion || 0}</strong>
        </span>
        <span>
          Guide <strong className="text-site-ink">v{doc.version}</strong>
        </span>
        <span>{counts.brands} brands</span>
        <span>{counts.aliases} aliases</span>
        <span>{counts.blocks} blocks</span>
        <span>{doc.fallback ? 'fallback set' : 'no fallback'}</span>
        {counts.broken > 0 && (
          <span className="text-site-plan">{counts.broken} incomplete</span>
        )}
      </div>

      <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
        <header className="flex items-center gap-2.5 px-[18px] py-3.5">
          <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">
            Brands
          </h2>
          <span className="text-[11.5px] text-site-ink-3">
            Matched against a lowercased Build.MANUFACTURER, first match wins
          </span>
          <button
            type="button"
            onClick={addBrand}
            className="ml-auto rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45"
          >
            Add brand
          </button>
        </header>

        <div className="divide-y divide-site-line border-t border-site-line">
          {doc.brands.length === 0 && (
            <p className="px-[18px] py-6 text-[12.5px] text-site-ink-3">
              No brands yet. Start with the manufacturers in the install base rather than the ones
              that are interesting to write about.
            </p>
          )}
          {doc.brands.map((brand, i) => (
            <BrandRow
              key={i}
              brand={brand}
              open={open === i}
              onToggle={() => setOpen(open === i ? null : i)}
              onChange={(patch) => mutateBrand(i, patch)}
              onRemove={() => removeBrand(i)}
              onMove={(by) => moveBrand(i, by)}
            />
          ))}
        </div>
      </section>

      <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
        <header className="flex items-center gap-2.5 px-[18px] py-3.5">
          <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">
            Fallback
          </h2>
          <span className="text-[11.5px] text-site-ink-3">
            What every unmatched device reads, which is most of them
          </span>
          <button
            type="button"
            onClick={() =>
              setDoc((d) => ({ ...d, fallback: d.fallback ? undefined : { blocks: [] } }))
            }
            className="ml-auto rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45"
          >
            {doc.fallback ? 'Remove fallback' : 'Add fallback'}
          </button>
        </header>
        {doc.fallback && (
          <div className="border-t border-site-line p-3">
            <BlockList
              blocks={doc.fallback.blocks}
              onChange={(blocks) => setDoc((d) => ({ ...d, fallback: { blocks } }))}
            />
          </div>
        )}
      </section>

      <div className="flex items-center gap-3">
        <button
          type="button"
          disabled={busy || blocked}
          onClick={publish}
          className="rounded-lg border border-site-accent bg-site-accent px-4 py-2 text-xs font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-45"
        >
          {busy ? 'Publishing' : 'Sign and publish'}
        </button>
        {message && (
          <span
            className={`text-[12.5px] ${message.tone === 'ok' ? 'text-site-ok' : 'text-site-plan'}`}
          >
            {message.text}
          </span>
        )}
      </div>

      <p className="text-[11.5px] leading-relaxed text-site-ink-3">
        Guidance is advice, not behaviour. Nothing here changes what the scanner probes, so a wrong
        sentence misleads one reader rather than breaking a scan. The trashmap is where a claim
        about where files live belongs.
      </p>
    </div>
  );
}

// ── brand ───────────────────────────────────────────────────────────────────

function BrandRow({
  brand,
  open,
  onToggle,
  onChange,
  onRemove,
  onMove,
}: {
  brand: Brand;
  open: boolean;
  onToggle: () => void;
  onChange: (patch: Partial<Brand>) => void;
  onRemove: () => void;
  onMove: (by: number) => void;
}) {
  const capital = brand.brand !== brand.brand.toLowerCase();

  return (
    <div>
      <div className="flex items-center gap-3 px-[18px] py-3">
        <button
          type="button"
          onClick={onToggle}
          className="flex min-w-0 flex-1 items-baseline gap-3 text-left"
        >
          <span className="font-mono text-[12.5px] font-semibold text-site-ink">
            {brand.brand || 'unnamed'}
          </span>
          <span className="truncate text-[12px] text-site-ink-3">
            {brand.summary || 'no summary'}
          </span>
        </button>
        <span className="shrink-0 font-mono text-[11px] text-site-ink-3">
          {brand.blocks.length} {brand.blocks.length === 1 ? 'block' : 'blocks'}
        </span>
        <button
          type="button"
          onClick={() => onMove(-1)}
          className="shrink-0 rounded px-1.5 py-1 text-[11px] font-semibold text-site-ink-3 hover:text-site-ink"
        >
          up
        </button>
        <button
          type="button"
          onClick={() => onMove(1)}
          className="shrink-0 rounded px-1.5 py-1 text-[11px] font-semibold text-site-ink-3 hover:text-site-ink"
        >
          down
        </button>
      </div>

      {open && (
        <div className="border-t border-site-line bg-site-page/40 p-3">
          <div className="grid gap-2 md:grid-cols-[1fr_1fr_2fr]">
            <Field label="Brand key">
              <input
                value={brand.brand}
                onChange={(e) => onChange({ brand: e.target.value })}
                className={`${input} font-mono`}
                placeholder="tecno"
              />
            </Field>
            <Field label="Label">
              <input
                value={brand.label}
                onChange={(e) => onChange({ label: e.target.value })}
                className={input}
                placeholder="Tecno"
              />
            </Field>
            <Field label="Summary">
              <input
                value={brand.summary}
                onChange={(e) => onChange({ summary: e.target.value })}
                className={input}
                placeholder="HiOS keeps a recycle folder for 30 days"
              />
            </Field>
          </div>

          {capital && (
            <p className="mt-2 text-[11.5px] text-site-plan">
              The brand key must be lowercase. Build.MANUFACTURER is lowercased before it is
              compared, so a capital here matches nothing and the publish will be refused.
            </p>
          )}

          <div className="mt-2">
            <Field label="Aliases, one per line. Other strings the same maker ships">
              <textarea
                rows={Math.max(2, (brand.aliases?.length ?? 0) + 1)}
                value={(brand.aliases ?? []).join('\n')}
                onChange={(e) =>
                  onChange({
                    aliases: e.target.value
                      .split('\n')
                      .map((s) => s.trim())
                      .filter((s) => s.length > 0),
                  })
                }
                className={`${input} font-mono text-[12px]`}
                placeholder={'tecno mobile limited\ninfinix mobility limited'}
              />
            </Field>
          </div>

          <div className="mt-3">
            <BlockList blocks={brand.blocks} onChange={(blocks) => onChange({ blocks })} />
          </div>

          <button
            type="button"
            onClick={onRemove}
            className="mt-3 text-[11.5px] font-semibold text-site-plan hover:underline"
          >
            Remove this brand
          </button>
        </div>
      )}
    </div>
  );
}

// ── blocks ──────────────────────────────────────────────────────────────────

/**
 * The block list.
 *
 * A TYPE SELECT AND ONE OR TWO FIELDS, rather than a JSON box. The six types
 * are a closed set the app switches on, so a typo in `t` is a block that
 * silently renders as nothing on a phone and as valid JSON here.
 */
function BlockList({
  blocks,
  onChange,
}: {
  blocks: Block[];
  onChange: (blocks: Block[]) => void;
}) {
  function set(i: number, patch: Partial<Block>) {
    const next = [...blocks];
    next[i] = { ...next[i], ...patch };
    onChange(next);
  }
  function move(i: number, by: number) {
    const to = i + by;
    if (to < 0 || to >= blocks.length) return;
    const next = [...blocks];
    const [row] = next.splice(i, 1);
    next.splice(to, 0, row);
    onChange(next);
  }

  return (
    <div>
      <div className="mb-1.5 flex items-center gap-2">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-site-ink-3">
          Content
        </span>
        <button
          type="button"
          onClick={() => onChange([...blocks, { t: 'p', text: '' }])}
          className="ml-auto rounded-lg border border-site-line bg-site-card px-2.5 py-1 text-[11px] font-semibold text-site-ink transition hover:border-site-ink-3/45"
        >
          Add block
        </button>
      </div>

      {blocks.length === 0 && (
        <p className="rounded-lg border border-dashed border-site-line px-3 py-4 text-[12px] text-site-ink-3">
          No content. A brand with no blocks is refused at publish rather than shipped as an empty
          page.
        </p>
      )}

      <div className="space-y-2">
        {blocks.map((block, i) => (
          <div key={i} className="rounded-lg border border-site-line bg-site-card p-2.5">
            <div className="flex flex-wrap items-center gap-2">
              <select
                value={block.t}
                onChange={(e) => set(i, { t: e.target.value as BlockType })}
                className={`${input} w-auto`}
              >
                {(Object.keys(BLOCK_LABELS) as BlockType[]).map((t) => (
                  <option key={t} value={t}>
                    {BLOCK_LABELS[t]}
                  </option>
                ))}
              </select>
              <div className="flex-1" />
              <button
                type="button"
                onClick={() => move(i, -1)}
                className="text-[11px] font-semibold text-site-ink-3 hover:text-site-ink"
              >
                up
              </button>
              <button
                type="button"
                onClick={() => move(i, 1)}
                className="text-[11px] font-semibold text-site-ink-3 hover:text-site-ink"
              >
                down
              </button>
              <button
                type="button"
                onClick={() => onChange(blocks.filter((_, k) => k !== i))}
                className="text-[11px] font-semibold text-site-plan hover:underline"
              >
                remove
              </button>
            </div>

            {block.t === 'path' && (
              <input
                value={block.name ?? ''}
                onChange={(e) => set(i, { name: e.target.value })}
                className={`${input} mt-2`}
                placeholder="Where the gallery keeps deleted photos"
              />
            )}

            {block.t === 'list' ? (
              <textarea
                rows={Math.max(2, (block.items?.length ?? 0) + 1)}
                value={(block.items ?? []).join('\n')}
                onChange={(e) =>
                  set(i, {
                    items: e.target.value
                      .split('\n')
                      .map((s) => s.trim())
                      .filter((s) => s.length > 0),
                  })
                }
                className={`${input} mt-2`}
                placeholder={'One item per line'}
              />
            ) : (
              <textarea
                rows={block.t === 'h' ? 1 : 3}
                value={block.text ?? ''}
                onChange={(e) => set(i, { text: e.target.value })}
                className={`${input} mt-2 ${block.t === 'path' ? 'font-mono text-[12px]' : ''}`}
                placeholder={
                  block.t === 'path'
                    ? 'Android/data/com.example/files/.trash'
                    : block.t === 'warn'
                      ? 'What will lose them their files'
                      : 'What this brand does differently'
                }
              />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-site-ink-3">
        {label}
      </span>
      {children}
    </label>
  );
}

const input =
  'w-full rounded-lg border border-site-line bg-site-page px-2.5 py-1.5 text-[12.5px] text-site-ink outline-none focus:border-site-accent';

/** Tolerant of anything, because the live document may predate a field. */
function normalise(raw: unknown): Guide {
  if (typeof raw !== 'object' || raw === null) return EMPTY;
  const d = raw as Partial<Guide>;
  const brands = Array.isArray(d.brands)
    ? d.brands.map((b) => ({
        brand: typeof b?.brand === 'string' ? b.brand : '',
        label: typeof b?.label === 'string' ? b.label : '',
        summary: typeof b?.summary === 'string' ? b.summary : '',
        aliases: Array.isArray(b?.aliases) ? b.aliases.filter((a) => typeof a === 'string') : undefined,
        blocks: Array.isArray(b?.blocks) ? b.blocks.map(fixBlock) : [],
      }))
    : [];
  const fallback =
    d.fallback && Array.isArray(d.fallback.blocks)
      ? { blocks: d.fallback.blocks.map(fixBlock) }
      : undefined;
  return {
    ...EMPTY,
    ...d,
    id: 'oem-guide',
    version: typeof d.version === 'number' ? d.version : 1,
    brands,
    fallback,
  };
}

function fixBlock(b: Block): Block {
  const t: BlockType = b && typeof b.t === 'string' && b.t in BLOCK_LABELS ? (b.t as BlockType) : 'p';
  return {
    t,
    text: typeof b?.text === 'string' ? b.text : undefined,
    name: typeof b?.name === 'string' ? b.name : undefined,
    items: Array.isArray(b?.items) ? b.items.filter((i) => typeof i === 'string') : undefined,
  };
}
