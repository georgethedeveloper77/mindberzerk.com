import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { readLiveIndex } from '@/lib/core/catalogue';
import {
  commitIndex,
  guardIndex,
  nextVersionFor,
  packKeyId,
  uploadPack,
} from '@/lib/core/publish-core';
import {
  CONTENT_PACKS,
  ContentValidationError,
  contentFile,
  validateContent,
} from '@/lib/g-recovery/content-packs';

/**
 * POST a G Recovery content document, get it validated, signed, uploaded and
 * listed.
 *
 * ## Node runtime, not Edge
 *
 * Load bearing, same as the pack route. Edge has no `node:crypto`, so `sign.ts`
 * cannot run there and neither can `firebase-admin`. Without this line a Next
 * upgrade that changes the default breaks signing and auth at the same time, at
 * deploy, with an error about a missing module.
 */
export const runtime = 'nodejs';

/**
 * A content pack is one small JSON file, not a 40 MB theme, so the pack route's
 * 300 seconds would only ever hide a hang.
 */
export const maxDuration = 60;

/** A registry or a guide. Anything approaching this is a mistake upstream. */
const MAX_DOCUMENT_BYTES = 1024 * 1024;

const APP = 'g-recovery' as const;

export async function POST(request: Request) {
  // FIRST LINE OF THE HANDLER, ALWAYS. proxy.ts is not a security boundary and
  // /api is excluded from it, so an auth failure here returns 401 JSON rather
  // than a redirect to an HTML page, which at the caller looks like a parse
  // error.
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: { packId?: string; document?: unknown };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return NextResponse.json({ error: 'Expected a JSON body' }, { status: 400 });
  }

  const packId = body.packId ?? '';
  const plan = CONTENT_PACKS[packId];
  if (!plan) {
    return NextResponse.json(
      { error: `Unknown content pack '${packId}'. Known: ${Object.keys(CONTENT_PACKS).join(', ')}` },
      { status: 400 },
    );
  }
  if (body.document === undefined || body.document === null) {
    return NextResponse.json({ error: 'Missing document' }, { status: 400 });
  }

  // VALIDATE BEFORE ANYTHING ELSE. The device degrades safely on a malformed
  // pack, which is the right behaviour there and the wrong place to find out:
  // by then it is published, the index points at it, and the symptom is a
  // chapter that is quietly shorter on some phones.
  try {
    validateContent(packId, body.document);
  } catch (e) {
    if (e instanceof ContentValidationError) {
      return NextResponse.json({ error: e.message }, { status: 400 });
    }
    throw e;
  }

  const file = contentFile(plan, body.document);
  if (file.bytes.length > MAX_DOCUMENT_BYTES) {
    return NextResponse.json(
      { error: `Document is ${file.bytes.length} bytes, over the ${MAX_DOCUMENT_BYTES} limit` },
      { status: 413 },
    );
  }

  const live = await readLiveIndex(APP);

  // THE DESTRUCTIVE CASE. Every merge below starts from live.packs, so a read
  // that failed to an empty list would replace a catalogue holding every pack
  // with one holding this pack alone, and every installed app would see the
  // rest vanish because a token expired.
  const refusal = guardIndex(APP, live);
  if (refusal) return NextResponse.json({ error: refusal }, { status: 409 });

  const version = nextVersionFor(live, plan.packId);
  const keyId = packKeyId();

  try {
    const entry = await uploadPack(
      APP,
      {
        packType: plan.packType,
        packId: plan.packId,
        version,
        minAppVersion: plan.minAppVersion,
        title: plan.title,
        summary: plan.summary,
        // Content is never sold. Coverage that a user has to pay for is
        // coverage most users do not get, and the whole point of this pipeline
        // is fixing recovery for devices nobody on the team owns.
        sku: null,
        files: [file],
      },
      keyId,
    );

    // AFTER the objects are up, never before. The index is what tells devices a
    // pack exists, and advertising one whose files are still uploading produces
    // a wave of failed installs across the install base at once.
    //
    // Entitlements are passed as undefined so the live list is carried through
    // untouched: publishing content must never be able to change who owns what.
    const generatedAt = await commitIndex(APP, live, [entry]);

    return NextResponse.json({
      ok: true,
      packId: plan.packId,
      version,
      path: entry.path,
      sizeBytes: entry.sizeBytes,
      keyId,
      generatedAt,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
