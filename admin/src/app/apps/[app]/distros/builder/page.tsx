import { notFound } from 'next/navigation';

import { APPS, readLiveIndex, type AppId } from '@/lib/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { listPlayProducts, playLite } from '@/lib/play';
import { appMeta } from '@/lib/registry';
import { readDraft } from '@/lib/themes';
import { DistroWorkspace } from '@/components/distro-builder/DistroWorkspace';

/**
 * The one editor.
 *
 *   /apps/<app>/distros/builder            a new distro
 *   /apps/<app>/distros/builder?id=<pack>  open an existing one
 *
 * The `?id=` form replaces `/themes/builder?id=`, which is deleted. A theme and
 * a distro were always the same artifact and having two editors meant two
 * places for the schema to drift apart.
 *
 * ─── LOADED ON THE SERVER, NOT FETCHED IN THE CLIENT ────────────────────────
 *
 * The draft is read here and handed down as a prop, so the workspace mounts
 * with the right values in its `useState` initialisers rather than mounting
 * blank and being corrected by an effect. That difference is visible: a builder
 * that flashes a blank palette and then fills in is a builder you do not trust
 * to have loaded everything.
 *
 * A MISSING DRAFT IS NOT A 404. `readDraft` returns null for an id that has no
 * draft, which includes every theme that only exists as a published pack. The
 * workspace opens empty in that case rather than refusing, because an empty
 * builder is a usable thing and a 404 on an Edit button is not.
 *
 * ─── AND THE PUBLISHED HERO PACKS, FOR THE SAME REASON ──────────────────────
 *
 * A distro's icon pack can now be one that already exists rather than one built
 * on this screen, so the workspace needs the list of what is published. Read
 * here, on the server, and passed down like the draft.
 *
 * AN UNREADABLE BUCKET IS NOT AN EMPTY ONE. `readLiveIndex` never throws now, so
 * a refused credential comes back as `unreachable` with an empty `packs`. Handed
 * down as-is that becomes a picker saying nothing is published, which is an
 * invitation to build a second copy of a pack that already exists. The flag
 * carries the difference and the picker says which it is. It does NOT refuse the
 * page, unlike the icon builder: nothing here derives a version number from the
 * index, `publishDistro` computes versions server-side and `guardIndex` refuses
 * an unreadable bucket before anything is written.
 *
 * ─── AND PLAY, SO THE PRICING TAB KNOWS WHAT ACTUALLY SELLS ─────────────────
 *
 * The sku fields become a picker over what exists in Play, with a status line
 * per product. `listPlayProducts` NEVER THROWS: an unreachable Play arrives as
 * `ok: false` and the workspace degrades to plain text inputs with the reason,
 * because pricing must stay editable when the reporting API is down. Read in
 * the same Promise.all so the slower of the three reads sets the page's
 * latency rather than their sum.
 */
export default async function DistroWorkspacePage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  const { id } = await searchParams;
  // Never let a bad read take the builder down: the point of opening it may be
  // to replace whatever is broken.
  const [initial, live, playRaw] = await Promise.all([
    id ? readDraft(appId, id).catch(() => null) : Promise.resolve(null),
    readLiveIndex(appId),
    listPlayProducts(appMeta(appId)?.pkg ?? null),
  ]);
  const play = playLite(playRaw);

  // 'hero' only. `brand` is the CC0 glyph layer and is chosen through
  // `icons.brandPack`, which is a different field with a different meaning, and
  // `icon`/`theme` are not hero art at all. Offering them here would let a
  // distro name a brand pack as its hero pack, which resolves to nothing.
  const heroPacks = live.packs
    .filter((p) => p.packType === 'hero')
    .map((p) => ({ packId: p.packId, title: p.title || p.packId, sku: p.sku ?? null }))
    .sort((a, b) => a.title.localeCompare(b.title));

  return (
    <Shell app={appId}>
      <DistroWorkspace
        app={appId}
        initial={initial}
        heroPacks={heroPacks}
        heroPacksUnreadable={!!live.unreachable || live.corrupt}
        play={play}
      />
    </Shell>
  );
}
