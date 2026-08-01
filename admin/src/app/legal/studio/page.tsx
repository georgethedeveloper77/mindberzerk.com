import { adminGate } from '@/app/components/admin-gate';
import { LegalEditor } from '@/components/studio/legal-editor';
import { StudioShell } from '@/components/studio/shell';
import { STUDIO_ID, publicUrl, readLegal } from '@/lib/studio/legal';

export const dynamic = 'force-dynamic';

/**
 * THE STUDIO'S OWN LEGAL DOCUMENTS, for mindberzerk.com.
 *
 * ## Why a route of its own and not `/apps/studio/legal`
 *
 * `/apps/[app]` calls `isAppId` and 404s on anything outside the closed `APPS`
 * tuple, which is exactly the protection that tuple exists to give. Adding
 * `studio` to it would make the studio an app everywhere else too: in the rail,
 * in MANAGED, and in every screen that assumes an app has a bucket prefix.
 *
 * ## The URLs are built here, on the server
 *
 * `publicUrl` reads CDN_BASE_URL, which is a server variable. Passing a map
 * down rather than the base string keeps the editor from having to know that
 * the path shape exists at all.
 */
export default async function StudioLegalPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const { doc, exists, corrupt, unreachable } = await readLegal(STUDIO_ID);

  const urlFor: Record<string, string> = {};
  for (const d of doc.documents) urlFor[d.slug] = publicUrl(STUDIO_ID, d.slug);

  return (
    <StudioShell>
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
          Nothing published yet. The drafts below describe what the website actually does: one
          analytics script, one contact form, server logs, and no accounts. Read them against the
          site before publishing.
        </p>
      )}

      <LegalEditor
        app={STUDIO_ID}
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
