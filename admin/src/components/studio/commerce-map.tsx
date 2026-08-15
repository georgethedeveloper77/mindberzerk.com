import Link from 'next/link';

import type { SkuRow, SkuState } from '@/lib/core/commerce';
import { skuKindLabel, type SkuKind } from '@/lib/core/skus';

/**
 * PRODUCTS ON THE LEFT, PACKS ON THE RIGHT, AND THE LINES BETWEEN THEM.
 *
 * ─── WHY A DRAWING AND NOT A COLUMN ─────────────────────────────────────────
 *
 * `commerce.ts` argues at length that the SKU is the row because a pack is not
 * the unit of sale: `distro_kali` unlocks two packs, `icons_kali` unlocks one of
 * them, and a bundle unlocks six. It also notes what a pack-keyed list would get
 * wrong, which is showing the Kali icon pack twice with two prices and no way to
 * say which one is broken.
 *
 * A table with an "unlocks" column has the same blind spot from the other side:
 * it can tell you what a product sells, and it cannot show you that one pack is
 * sold three ways. That is the shape of this catalogue and it was invisible.
 * Two columns and the lines between them show it without a word of copy.
 *
 * ─── WHAT THE ABSENCE OF A LINE MEANS ───────────────────────────────────────
 *
 * A product with no line is either finished or broken, and the drawing
 * distinguishes them without a status column:
 *
 *   A FEATURE has no line and no stub. `terminal_pro` unlocks behaviour rather
 *   than a pack, so connecting to nothing is correct and complete.
 *
 *   AN UNLINKED PRODUCT has a stub that ends in a hollow circle. A line going
 *   nowhere reads as unfinished on sight.
 *
 * ─── GEOMETRY IS COMPUTED, NOT MEASURED ─────────────────────────────────────
 *
 * Rows are a fixed height and the curves are derived from their index, so this
 * renders on the server with no layout pass and no client JavaScript. The
 * alternative is measuring DOM nodes and drawing afterwards, which means a
 * frame with rows and no lines, on a page whose whole point is the lines.
 */

/** One row's height, and the vertical rhythm every curve is derived from. */
const ROW = 58;
const ROW_H = 48;
const TOP = ROW_H / 2;
const MID = 210;

export interface MapPack {
  packId: string;
  title: string;
  /** A pack with no sku is deliberately free, and has no product to draw. */
  free: boolean;
}

const KIND_TINT: Record<SkuKind, string> = {
  distro: 'var(--color-site-accent)',
  icons: '#7C5CFF',
  bundle: '#4ADE80',
  feature: '#F0B429',
  other: 'var(--color-site-ink-3)',
};

const STATE_NOTE: Record<SkuState, string> = {
  selling: '',
  feature: 'unlocks in the app',
  unlinked: 'attached to nothing',
  untracked: 'in Play only',
};

export function CommerceMap({
  app,
  rows,
  packs,
  selected,
}: {
  app: string;
  rows: SkuRow[];
  packs: MapPack[];
  selected: string | null;
}) {
  // Products that unlock something first, so the dense end of the drawing is at
  // the top and the stubs collect at the bottom where they read as a list of
  // work rather than as gaps in the middle.
  const order: Record<SkuState, number> = {
    selling: 0,
    feature: 1,
    unlinked: 2,
    untracked: 3,
  };
  const products = [...rows].sort(
    (a, b) => order[a.state] - order[b.state] || a.sku.localeCompare(b.sku),
  );

  const packIndex = new Map(packs.map((p, i) => [p.packId, i]));
  const y = (i: number) => TOP + i * ROW;
  const height = TOP + Math.max(products.length, packs.length) * ROW;

  // How many products reach each pack. This is the number the drawing exists to
  // make visible, and it is also the tag on the pack row.
  const soldWays = new Map<string, number>();
  for (const r of products) {
    for (const p of r.unlocks) soldWays.set(p, (soldWays.get(p) ?? 0) + 1);
  }

  const curves: { key: string; d: string; kind: SkuKind; dim: boolean }[] = [];
  const stubs: { key: string; y: number }[] = [];

  products.forEach((r, pi) => {
    if (r.state === 'unlinked') {
      stubs.push({ key: r.sku, y: y(pi) });
      return;
    }
    for (const packId of r.unlocks) {
      const ki = packIndex.get(packId);
      // A grant naming a pack that is not published yet is allowed on purpose,
      // and signIndex permits it. There is nothing on the right to draw to, so
      // the row's own problem list carries it instead.
      if (ki === undefined) continue;
      const y1 = y(pi);
      const y2 = y(ki);
      curves.push({
        key: `${r.sku}>${packId}`,
        d: `M0,${y1} C${MID * 0.45},${y1} ${MID * 0.55},${y2} ${MID},${y2}`,
        kind: r.kind,
        // A selection dims everything else rather than hiding it, so the shape
        // of the whole catalogue stays legible while one product is read.
        dim: !!selected && selected !== r.sku,
      });
    }
  });

  return (
    <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
      <div className="grid grid-cols-[1fr_210px_1fr] gap-0 px-5 pb-6 pt-4">
        <Column label="Products" hint="what a person buys">
          <div className="relative" style={{ height }}>
            {products.map((r, i) => (
              <ProductRow
                key={r.sku}
                app={app}
                row={r}
                top={y(i) - ROW_H / 2}
                selected={selected === r.sku}
                faded={!!selected && selected !== r.sku}
              />
            ))}
          </div>
        </Column>

        <Column label="unlocks" center>
          <div className="relative" style={{ height }}>
            <svg
              width={MID}
              height={height}
              viewBox={`0 0 ${MID} ${height}`}
              className="overflow-visible"
              aria-hidden
            >
              {curves.map((c) => (
                <path
                  key={c.key}
                  d={c.d}
                  fill="none"
                  stroke={KIND_TINT[c.kind]}
                  strokeWidth={1.4}
                  strokeDasharray={c.kind === 'bundle' ? '3 4' : undefined}
                  opacity={c.dim ? 0.12 : c.kind === 'bundle' ? 0.4 : 0.62}
                />
              ))}
              {stubs.map((s) => (
                <g key={s.key} opacity={selected && selected !== s.key ? 0.2 : 0.85}>
                  <path
                    d={`M0,${s.y} L46,${s.y}`}
                    stroke="#F0736F"
                    strokeWidth={1.4}
                    strokeDasharray="3 3"
                    fill="none"
                  />
                  <circle cx={52} cy={s.y} r={4} fill="none" stroke="#F0736F" strokeWidth={1.4} />
                </g>
              ))}
            </svg>
          </div>
        </Column>

        <Column label="Packs" hint="what a device downloads" right>
          <div className="relative" style={{ height }}>
            {packs.map((p, i) => (
              <PackRow
                key={p.packId}
                pack={p}
                top={y(i) - ROW_H / 2}
                ways={soldWays.get(p.packId) ?? 0}
              />
            ))}
          </div>
        </Column>
      </div>

      <Legend />
    </section>
  );
}

function Column({
  label,
  hint,
  right,
  center,
  children,
}: {
  label: string;
  hint?: string;
  right?: boolean;
  center?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div>
      <p
        className={`mb-3.5 border-b border-site-line pb-2 font-mono text-[10px] uppercase tracking-[0.15em] text-site-ink-3 ${
          right ? 'text-right' : center ? 'text-center' : ''
        }`}
      >
        {label}
        {hint && <span className="ml-2 normal-case tracking-normal opacity-70">{hint}</span>}
      </p>
      {children}
    </div>
  );
}

function ProductRow({
  app,
  row,
  top,
  selected,
  faded,
}: {
  app: string;
  row: SkuRow;
  top: number;
  selected: boolean;
  faded: boolean;
}) {
  const tint = KIND_TINT[row.kind];
  const note = STATE_NOTE[row.state];

  return (
    <Link
      href={`/apps/${app}/commerce?sel=${row.sku}#detail`}
      style={{ top, height: ROW_H }}
      className={`absolute inset-x-0 flex items-center gap-3 rounded-[10px] border px-3 transition ${
        selected
          ? 'border-white/25 bg-white/[0.07]'
          : row.state === 'unlinked'
            ? 'border-[#f0736f]/40 bg-[#f0736f]/[0.05]'
            : row.state === 'feature'
              ? 'border-[#f0b429]/35 bg-[#f0b429]/[0.05]'
              : 'border-site-line bg-white/[0.03] hover:bg-white/[0.06]'
      } ${faded ? 'opacity-40' : ''}`}
    >
      <span
        className="grid size-7 shrink-0 place-items-center rounded-lg font-mono text-[10px] font-semibold"
        style={{ background: `color-mix(in srgb, ${tint} 15%, transparent)`, color: tint }}
      >
        {skuKindLabel(row.kind).slice(0, 1)}
      </span>

      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate font-mono text-[12px] font-medium text-site-ink">{row.sku}</span>
        <span className="mt-0.5 truncate text-[11px] text-site-ink-3">
          {row.note ?? row.title}
          {note && <span className="opacity-70"> &middot; {note}</span>}
        </span>
      </span>

      {row.unlocks.length > 1 && (
        <span className="shrink-0 font-mono text-[10px] text-site-ink-3">{row.unlocks.length}</span>
      )}
    </Link>
  );
}

function PackRow({ pack, top, ways }: { pack: MapPack; top: number; ways: number }) {
  return (
    <div
      style={{ top, height: ROW_H }}
      className={`absolute inset-x-0 flex items-center justify-end gap-3 rounded-[10px] border px-3 ${
        pack.free
          ? 'border-dashed border-site-line bg-transparent opacity-50'
          : 'border-site-line bg-white/[0.03]'
      }`}
    >
      {/* The number this whole drawing exists to make visible. A pack reached by
          three products is the thing a table cannot say. */}
      {ways > 1 && (
        <span className="shrink-0 rounded-[5px] border border-[#7C5CFF]/35 px-1.5 py-0.5 font-mono text-[9.5px] uppercase tracking-[0.08em] text-[#A48CFF]">
          sold {ways} ways
        </span>
      )}
      {pack.free && (
        <span className="shrink-0 font-mono text-[9.5px] uppercase tracking-[0.08em] text-site-ink-3">
          free
        </span>
      )}
      <span className="flex min-w-0 flex-col items-end">
        <span className="truncate font-mono text-[12px] font-medium text-site-ink">{pack.packId}</span>
        <span className="mt-0.5 truncate text-[11px] text-site-ink-3">{pack.title}</span>
      </span>
    </div>
  );
}

function Legend() {
  const items: { tint: string; text: string; dashed?: boolean }[] = [
    { tint: KIND_TINT.distro, text: 'distro' },
    { tint: KIND_TINT.icons, text: 'icon pack' },
    { tint: KIND_TINT.bundle, text: 'bundle, dashed because it grants rather than carries', dashed: true },
    { tint: '#F0736F', text: 'ends nowhere', dashed: true },
  ];

  return (
    <div className="flex flex-wrap gap-x-6 gap-y-2 border-t border-site-line bg-white/[0.02] px-5 py-3 text-[12px] text-site-ink-3">
      {items.map((i) => (
        <span key={i.text} className="inline-flex items-center gap-2">
          <span
            className="inline-block h-0.5 w-4 rounded-full"
            style={{
              background: i.dashed
                ? `repeating-linear-gradient(90deg, ${i.tint} 0 3px, transparent 3px 6px)`
                : i.tint,
            }}
          />
          {i.text}
        </span>
      ))}
    </div>
  );
}
