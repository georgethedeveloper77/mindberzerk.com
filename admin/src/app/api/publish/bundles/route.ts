import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { nextGeneratedAt, readLiveIndex } from '@/lib/catalogue';
import { isAppId } from '@/lib/registry';
import { putObject } from '@/lib/r2';
import {
  INDEX_NAME,
  INDEX_SIGNATURE_NAME,
  isSafePackId,
  isSafeSku,
  signIndex,
  type IndexEntitlement,
} from '@/lib/sign';

/**
 * PHASE C6 - bundles, which is the entitlements half of the index.
 *
 * ## Why this is a separate route from publishing a pack
 *
 * The pack route carries `live.entitlements` through UNTOUCHED, deliberately:
 * uploading a theme must never be able to change who owns what. The inverse is
 * true here. This route rewrites the entitlements array and copies `live.packs`
 * across without looking at it, so editing a bundle can never drop a pack from
 * the store.
 *
 * Both routes therefore do the same dance for the same reason: read the LIVE
 * index, replace exactly one part of it, bump `generatedAt`, re-sign, write.
 *
 * ## Wholesale replacement, not a patch
 *
 * The client sends the entire entitlements array. A per-bundle PATCH would need
 * optimistic concurrency to be safe, and with one admin and a screen that loads
 * the live list on every render, last-write-wins over the whole array is both
 * simpler and easier to reason about. The cost is that two tabs open at once can
 * clobber each other, which is a real but acceptable trade at this size.
 */
export const runtime = 'nodejs';

interface Body {
  app?: string;
  entitlements?: unknown;
}

export async function POST(request: Request) {
  // FIRST LINE, ALWAYS. The proxy verifies nothing, and /api is excluded from it
  // so that an auth failure here is 401 JSON rather than a redirect to an HTML
  // login page, which at the caller looks like a parse error.
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: Body;
  try {
    body = (await request.json()) as Body;
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const app = String(body.app ?? '');
  if (!isAppId(app)) {
    return NextResponse.json({ error: `Unknown app '${app}'` }, { status: 400 });
  }

  if (!Array.isArray(body.entitlements)) {
    return NextResponse.json({ error: 'entitlements must be an array' }, { status: 400 });
  }

  // ── shape check before anything is read ────────────────────────────────────
  //
  // signIndex validates all of this too and throwing there would be correct, but
  // its messages are written for a CLI. Checking here means the panel can say
  // which bundle is wrong instead of which rule was broken.
  const entitlements: IndexEntitlement[] = [];
  for (const [i, raw] of body.entitlements.entries()) {
    if (typeof raw !== 'object' || raw === null) {
      return NextResponse.json({ error: `Bundle ${i + 1} is not an object` }, { status: 400 });
    }
    const e = raw as Record<string, unknown>;
    const sku = String(e.sku ?? '').trim();
    const title = String(e.title ?? '').trim();
    const summary = String(e.summary ?? '').trim();
    const grants = Array.isArray(e.grants) ? e.grants.map(String) : [];

    if (!isSafeSku(sku)) {
      return NextResponse.json(
        {
          error:
            `Bundle ${i + 1}: "${sku}" is not a valid SKU. Play requires lowercase ` +
            'letters, digits and underscores, starting with a letter or digit.',
        },
        { status: 400 },
      );
    }
    if (!title) {
      return NextResponse.json({ error: `${sku} has no title` }, { status: 400 });
    }
    // An entitlement that grants nothing is a product a buyer receives nothing
    // for. signIndex refuses it; saying so by name is more useful.
    if (grants.length === 0) {
      return NextResponse.json(
        { error: `${sku} grants nothing. Delete it, or give it at least one pack.` },
        { status: 400 },
      );
    }
    for (const g of grants) {
      // '*' is everything present AND FUTURE, which is what an all-access pass
      // means. A named grant may point at a pack that has not shipped yet: a
      // bundle can be announced before its contents are live.
      if (g !== '*' && !isSafePackId(g)) {
        return NextResponse.json(
          { error: `${sku} grants "${g}", which is not a valid pack id` },
          { status: 400 },
        );
      }
    }

    entitlements.push({ sku, title, summary, grants });
  }

  const skus = new Set<string>();
  for (const e of entitlements) {
    if (skus.has(e.sku)) {
      return NextResponse.json(
        { error: `${e.sku} appears twice. A SKU is one product.` },
        { status: 409 },
      );
    }
    skus.add(e.sku);
  }

  // ── the live index ─────────────────────────────────────────────────────────
  const live = await readLiveIndex(app);

  if (live.corrupt) {
    return NextResponse.json(
      { error: `${app}/${INDEX_NAME} exists but does not parse. Refusing to overwrite it.` },
      { status: 409 },
    );
  }
  if (live.packs.length === 0) {
    // signIndex refuses an index with no packs, so there is nothing to attach a
    // bundle to yet. Publishing one pack first is the fix.
    return NextResponse.json(
      { error: 'Nothing is published yet. A bundle needs at least one pack to grant.' },
      { status: 409 },
    );
  }

  const keyId = process.env.PACK_KEY_ID ?? 'mh-2026-07';
  const generatedAt = nextGeneratedAt(live);

  let index;
  try {
    index = signIndex({
      generatedAt,
      keyId,
      // Copied across without inspection. This route may not change the
      // catalogue, only who owns it.
      packs: live.packs,
      entitlements,
    });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 400 });
  }

  await putObject(`${app}/${INDEX_NAME}`, index.index, 'application/json');
  await putObject(
    `${app}/${INDEX_SIGNATURE_NAME}`,
    index.signature,
    'application/octet-stream',
  );

  return NextResponse.json({
    ok: true,
    bundles: entitlements.length,
    packs: live.packs.length,
    generatedAt,
    previousGeneratedAt: live.generatedAt,
  });
}
