import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { LegalEditor } from '@/components/studio/legal-editor';
import { StudioShell } from '@/components/studio/shell';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { publicUrl, readLegal } from '@/lib/studio/legal';

export const dynamic = 'force-dynamic';

/**
 * PHASE C13 - an app's legal documents.
 *
 * PER APP, not under /site, and that is the whole reason this page exists
 * separately. `site/content.json` is the publisher's homepage. A privacy policy
 * is the opposite: G Launcher's names its accessibility service and its three
 * analytics events, and G Recovery's will name storage access and a home server
 * it uploads to. One document could only be wrong for one of them.
 *
 * ## No AppSlab here, and that is not an oversight
 *
 * Every other per-app screen opens with one. `LegalEditor` draws its OWN slab,
 * because the document count and the problems-to-fix flag change as you type
 * and belong to the editor's state rather than to the page's. Two slabs would
 * be two headers arguing about which one is the header.
 *
 * ## One editor, two entry points
 *
 * The studio's own documents live at `/legal/studio` and use the same
 * component. The only difference between the two callers is which id they
 * resolve and which shell wraps them, which is exactly as much difference as
 * there should be.
 */
export default async function LegalPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { doc, exists, corrupt, unreachable } = await readLegal(app);

  // Built here because `publicUrl` reads CDN_BASE_URL, a server variable.
  // Passing a map down keeps the editor from needing to know the path shape.
  const urlFor: Record<string, string> = {};
  for (const d of doc.documents) urlFor[d.slug] = publicUrl(app, d.slug);

  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      {unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so the editor below holds the starting draft rather than
          what is published. Publishing now would overwrite a live policy with that draft.{' '}
          {unreachable}
        </p>
      )}

      {corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The stored document is present but does not parse. Publishing overwrites it with a clean
          one; the editor below is seeded from the starting draft.
        </p>
      )}

      {!exists && !unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          Nothing published yet for {appName(app)}. The drafts below are written against this
          app&apos;s real manifest. Read them before publishing, because they are a promise about
          what the app does.
        </p>
      )}

      <LegalEditor
        app={app}
        // The tint carries which app you are editing into the editor's own
        // slab, so a policy for the wrong app is visible before it is read.
        tint={meta?.tint}
        initial={{
          documents: doc.documents,
          contactEmail: doc.contactEmail,
          jurisdiction: doc.jurisdiction,
        }}
        urlFor={urlFor}
      />
    </StudioShell>
  );
}
