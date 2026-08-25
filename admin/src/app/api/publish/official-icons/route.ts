import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import type { AppId } from '@/lib/core/catalogue';
import { DISTRO_RECIPES } from '@/lib/g-launcher/distro-recipes';
import { publishDerivedPacks } from '@/lib/g-launcher/publish-derived';

/**
 * PUBLISH THE FOURTEEN OFFICIAL ICON PACKS.
 *
 * ─── WHY THIS IS A ROUTE AND NOT THE ICON BUILDER ───────────────────────────
 *
 * The icon builder composes and uploads art. Building Ubuntu Icons there means
 * fourteen thousand PNGs, per distro, fourteen times: roughly 148 MB to say the
 * same thing fourteen ways. Every one of these packs is instead ~207 bytes
 * naming a colour and pointing at `arcticons-line`, which carries the geometry
 * they share, so there is no art to upload and nothing to compose.
 *
 * That makes this a button rather than a screen. There is no per-pack form
 * because there is nothing per-pack to fill in: the colours are in
 * `distro-recipes.ts`, they are the distros' own brand values, and changing one
 * changes a shipped product rather than a draft.
 *
 * ─── NODE RUNTIME, NOT EDGE ─────────────────────────────────────────────────
 *
 * Same reason as the pack route: `sign.ts` needs `node:crypto` and
 * `firebase-admin` needs Node. Without this line a Next upgrade that changes
 * the default breaks signing and auth at once, at deploy, with an error about a
 * missing module.
 */
export const runtime = 'nodejs';

/**
 * Fourteen uploads and one signed index write. Each pack is tiny, so this is
 * fast, but it is fourteen round trips to R2 and the default 15s is not a
 * margin worth relying on.
 */
export const maxDuration = 120;

export async function POST(request: Request) {
  // FIRST LINE OF THE HANDLER, ALWAYS. The middleware verifies nothing, it runs
  // on Edge, and /api is excluded from it so an auth failure here returns 401
  // JSON rather than a redirect to an HTML login page, which at the caller
  // looks like a parse error.
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: { app?: string; only?: string[] };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return NextResponse.json({ error: 'Expected a JSON body' }, { status: 400 });
  }

  const app = body.app;
  if (app !== 'g-launcher') {
    // Narrow rather than cast. `AppId` is a union and an unchecked cast here
    // would let a typo publish into a bucket prefix nothing reads, which looks
    // exactly like a publish that silently did nothing.
    return NextResponse.json(
      { error: `Unknown app '${String(app)}'.` },
      { status: 400 },
    );
  }

  /**
   * ─── `only` IS FOR REPUBLISHING ONE, NOT FOR PARTIAL FIRST PUBLISHES ──────
   *
   * Changing Mint's green should not bump the other thirteen versions, so a
   * subset is allowed. It is validated against the table rather than trusted:
   * an id that is not a recipe is a typo, and publishing zero packs while
   * reporting success is the worst possible answer to one.
   */
  let recipes = DISTRO_RECIPES;
  if (body.only && body.only.length > 0) {
    const wanted = new Set(body.only);
    recipes = DISTRO_RECIPES.filter((r) => wanted.has(r.packId));
    const unknown = body.only.filter(
      (id) => !DISTRO_RECIPES.some((r) => r.packId === id),
    );
    if (unknown.length > 0) {
      return NextResponse.json(
        {
          error:
            `Not official icon packs: ${unknown.join(', ')}. ` +
            'The fourteen are defined in distro-recipes.ts.',
        },
        { status: 400 },
      );
    }
  }

  const result = await publishDerivedPacks(app as AppId, recipes);

  if (!result.ok) {
    return NextResponse.json(
      { error: result.error ?? 'Publish failed.' },
      { status: result.status ?? 500 },
    );
  }

  return NextResponse.json({
    published: result.published,
    granted: result.granted,
    /** True when this run also hid the base pack from the storefront. */
    hidBase: result.hidBase,
    generatedAt: result.generatedAt,
    totalBytes: result.totalBytes,
    /**
     * Reported, and deliberately NOT fatal.
     *
     * A pack whose Play product does not exist yet still publishes correctly;
     * it simply cannot be bought until the product is created. Refusing the
     * whole operation over it would block eleven working packs on a console
     * task, and the three that already have products would go out alone.
     *
     * It is surfaced because the failure is otherwise silent and permanent: the
     * pack installs, the entitlement never arrives, and the user sees a Buy
     * button on something nothing can charge for.
     */
    missingSkus: result.missingSkus,
  });
}
