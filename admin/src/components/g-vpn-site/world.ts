import 'server-only';

import world from '@/lib/g-vpn/world-map.json';

/**
 * The dotted world behind the hero and the closing banner.
 *
 * Built from the same Natural Earth country shapes as the admin live map
 * (lib/g-vpn/world-map.json, equirectangular, latitude 80 to -56), sampled
 * on a fixed grid. Computed once per server process and emitted as a single
 * SVG path of zero-length round-capped segments, which is a fraction of the
 * markup of one <circle> per dot.
 */

export const MAP_WIDTH = world.width;
export const MAP_HEIGHT = world.height;

/** Grid spacing in map units: about 2,100 dots over land. */
const STEP = 10;

type Ring = { pts: number[]; minX: number; maxX: number; minY: number; maxY: number };

/** Parses the `M x y L x y ... Z` paths the map file uses into closed rings. */
function rings(): Ring[] {
  const out: Ring[] = [];
  for (const d of Object.values(world.paths as Record<string, string>)) {
    for (const sub of d.split('M').slice(1)) {
      const nums = sub.match(/-?\d+(?:\.\d+)?/g)?.map(Number) ?? [];
      if (nums.length < 6) continue;
      let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
      for (let i = 0; i < nums.length - 1; i += 2) {
        minX = Math.min(minX, nums[i]); maxX = Math.max(maxX, nums[i]);
        minY = Math.min(minY, nums[i + 1]); maxY = Math.max(maxY, nums[i + 1]);
      }
      out.push({ pts: nums, minX, maxX, minY, maxY });
    }
  }
  return out;
}

/** Even-odd ray cast against one ring. */
function inside(x: number, y: number, r: Ring): boolean {
  if (x < r.minX || x > r.maxX || y < r.minY || y > r.maxY) return false;
  const p = r.pts;
  let hit = false;
  for (let i = 0, j = p.length - 2; i < p.length - 1; j = i, i += 2) {
    const xi = p[i], yi = p[i + 1], xj = p[j], yj = p[j + 1];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
}

let cached: string | null = null;

/** SVG path data for every land dot, memoised. */
export function landDotsPath(): string {
  if (cached !== null) return cached;
  const all = rings();
  const parts: string[] = [];
  for (let y = STEP / 2; y < MAP_HEIGHT; y += STEP) {
    for (let x = STEP / 2; x < MAP_WIDTH; x += STEP) {
      if (all.some((r) => inside(x, y, r))) parts.push(`M${x} ${y}h0`);
    }
  }
  cached = parts.join('');
  return cached;
}

/** Map position of a country's centre, or null when the file has none. */
export function countryPoint(code: string): [number, number] | null {
  const c = (world.centres as Record<string, number[]>)[code.toUpperCase()];
  return c && c.length >= 2 ? [c[0], c[1]] : null;
}
