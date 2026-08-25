'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

import { type ComposeSpec } from '@/lib/g-launcher/icon-compose';
import {
  DISTRO_RECIPES,
  shelfForPack,
  retargetPackId,
  type DistroRecipe,
} from '@/lib/g-launcher/distro-recipes';

/**
 * ONE SOURCE, SIX PRODUCTS, VISIBLE AS A ROW.
 *
 * ─── WHAT IT IS TRYING TO SHOW ──────────────────────────────────────────────
 *
 * The style bar can already produce any of these packs. What it cannot do is
 * make the RELATIONSHIP obvious: that the drawings are the asset, the palette
 * is four numbers, and the six SKUs on the roadmap are six recipes over one set
 * of art rather than six sets. An author who does not see that builds Kali,
 * ships it, and never gets around to the other five.
 *
 * So each tile composes the SAME icon under a different recipe, live, using the
 * same `composeIcon` the pack itself will be built with. Nothing is mocked: if
 * a tile looks wrong, the pack will look wrong.
 *
 * ─── WHY IT ONLY PREVIEWS ───────────────────────────────────────────────────
 *
 * Tapping a tile retargets the OPEN pack and stops. It does not publish six
 * packs, and it deliberately does not offer to. Six publishes is roughly 1,150
 * PNGs, six signatures and six index commits, and a control that starts that
 * from a strip of thumbnails is a control that will one day start it by
 * accident. Publishing stays where publishing already is.
 */

export function DistroStrip({
  packId,
  sample,
  style,
  onRetarget,
  busy,
}: {
  /** The pack being edited, so the strip can show which recipe it already is. */
  packId: string;
  /**
   * One icon's SOURCE art, used for every tile. Source rather than composed
   * output, because a tile has to recompose from scratch: composing over an
   * already-composed icon would stack a second plate on the first.
   */
  sample: Blob | null;
  /** The style currently applied, so a hand-edited pack does not claim a recipe. */
  style: ComposeSpec | null;
  /** Apply a recipe to every icon, and rename the pack to match. */
  onRetarget: (compose: ComposeSpec, packId: string, recipe: DistroRecipe) => void;
  busy: boolean;
}) {
  // SHELF, not identity. This decides which tile is highlighted, so a draft
  // called `kali-2024-mine` should still show as a Kali pack. `recipeForPack`
  // is exact and is reserved for anything deciding money or publishing.
  const current = useMemo(() => shelfForPack(packId), [packId]);

  return (
    <div className="rounded-[14px] border border-site-line bg-site-sunk p-3">
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <h4 className="text-[13px] font-semibold text-site-ink">One source, six distros</h4>
        <span className="text-[11.5px] text-site-ink-3">
          The drawings are the asset. The palette is four numbers.
        </span>
      </div>

      <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
        {DISTRO_RECIPES.map((r) => (
          <RecipeTile
            key={r.base}
            recipe={r}
            sample={sample}
            isCurrent={current?.base === r.base}
            busy={busy}
            onClick={() => onRetarget({ ...r.compose }, retargetPackId(packId, r), r)}
          />
        ))}
      </div>

      <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
        {current && style
          ? `This pack is styled as ${current.title}. Tapping another recipe recolours every icon and renames the pack.`
          : current
            ? `This pack shelves under ${current.title} but ships art as authored. Tapping a recipe styles the whole set.`
            : 'Tapping a recipe styles every icon and gives the pack that distro\u2019s id prefix.'}
      </p>
    </div>
  );
}

function RecipeTile({
  recipe,
  sample,
  isCurrent,
  busy,
  onClick,
}: {
  recipe: DistroRecipe;
  sample: Blob | null;
  isCurrent: boolean;
  busy: boolean;
  onClick: () => void;
}) {
  const ref = useRef<HTMLCanvasElement | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    let cancelled = false;

    void (async () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 3);
      const CSS = 52;
      canvas.width = Math.round(CSS * dpr);
      canvas.height = canvas.width;
      const g = canvas.getContext('2d');
      if (!g) return;

      // The wallpaper first, so the plate is judged against the surface it will
      // sit on rather than against the panel. A plate that disappears into its
      // own distro's wallpaper is a thing worth seeing before publishing it.
      g.clearRect(0, 0, canvas.width, canvas.height);
      g.fillStyle = recipe.canvas;
      g.fillRect(0, 0, canvas.width, canvas.height);
      const glow = g.createRadialGradient(
        canvas.width * 0.72, canvas.height * 0.28, 0,
        canvas.width * 0.72, canvas.height * 0.28, canvas.width * 0.9,
      );
      glow.addColorStop(0, recipe.wall);
      glow.addColorStop(1, recipe.canvas);
      g.globalAlpha = 0.55;
      g.fillStyle = glow;
      g.fillRect(0, 0, canvas.width, canvas.height);
      g.globalAlpha = 1;

      if (!sample) return;

      // `composeIcon` is imported lazily so this component costs nothing on a
      // page where the strip never renders art.
      const { composeIcon } = await import('@/lib/g-launcher/icon-compose');
      const png = await composeIcon(recipe.compose, sample);
      if (cancelled || !png) {
        if (!cancelled) setFailed(true);
        return;
      }
      let bmp: ImageBitmap;
      try {
        bmp = await createImageBitmap(png);
      } catch {
        if (!cancelled) setFailed(true);
        return;
      }
      if (cancelled) {
        bmp.close();
        return;
      }
      const pad = canvas.width * 0.16;
      g.drawImage(bmp, pad, pad, canvas.width - pad * 2, canvas.height - pad * 2);
      bmp.close();
    })();

    return () => {
      cancelled = true;
    };
  }, [recipe, sample]);

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={busy}
      aria-pressed={isCurrent}
      title={recipe.title}
      className="flex shrink-0 flex-col items-center gap-1.5 rounded-[11px] border p-2 transition disabled:opacity-50"
      style={{
        borderColor: isCurrent ? 'var(--color-site-accent)' : 'var(--color-site-line)',
        background: isCurrent ? 'var(--color-site-accent-soft)' : 'transparent',
      }}
    >
      <canvas
        ref={ref}
        style={{ width: 52, height: 52, borderRadius: 9, display: 'block' }}
      />
      <span className="text-[11px] font-semibold text-site-ink-2">{recipe.short}</span>
      <span className="font-mono text-[9px] text-site-ink-3">
        {failed ? 'no preview' : recipe.compose.tint ?? 'as authored'}
      </span>
    </button>
  );
}
