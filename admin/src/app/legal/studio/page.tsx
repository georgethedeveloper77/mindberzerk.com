import { adminGate } from '@/app/components/admin-gate';
import { LegalForm } from '@/app/components/legal-form';
import { Shell } from '@/app/components/shell';
import { Banner, PageHead, when } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { STUDIO_ID, publicUrl, readLegal } from '@/lib/legal';

export const dynamic = 'force-dynamic';

/**
 * THE STUDIO'S OWN TERMS AND PRIVACY, for mindberzerk.com.
 *
 * ## Why it is a route of its own and not `/apps/studio/legal`
 *
 * `/apps/[app]` calls `isAppId` and 404s on anything outside the closed `APPS`
 * tuple, which is exactly the protection that tuple exists to give. Adding
 * `studio` to it to reach this page would make the studio an app everywhere
 * else too: it would appear in the rail, in MANAGED, in the per-app catalogue
 * reads, and in every screen that assumes an app has a bucket prefix. A single
 * fixed route costs one file and keeps that guarantee intact.
 *
 * ## And why it looks like the per-app legal screen rather than the dashboard
 *
 * Same `Shell`, same `LegalForm`, same banners. This is a sibling of
 * `/apps/g-launcher/legal`, and a screen that does the same job in the same
 * tool should not be in a different visual register because it was written
 * later. The dashboard is the odd one out until the restyle lands, not this.
 *
 * `LegalForm` needed no change at all: it already types `app` as a string and
 * posts it verbatim, so the reserved id travelled through it untouched. The
 * publish route is where the gate widened from `isAppId` to `isLegalId`.
 */
export default async function StudioLegalPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const { doc, exists, corrupt, unreachable } = await readLegal(STUDIO_ID);

  return (
    <Shell subtitle="mindberzerk.com">
      <Breadcrumb items={[{ label: 'Mindberzerk' }, { label: 'Studio legal' }]} />

      {unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so the editor below holds the starting
          draft rather than what is published. Publishing now would overwrite a
          live policy with that draft. {unreachable}
        </Banner>
      )}

      {corrupt && (
        <Banner tone="bad">
          The stored document is present but does not parse. Publishing
          overwrites it with a clean one; the editor below is seeded from the
          starting draft.
        </Banner>
      )}

      {!exists && !unreachable && (
        <Banner tone="warn">
          Nothing published yet. The draft below describes what the website
          actually does: one analytics script, one contact form, server logs,
          and no accounts. Read it against the site before you publish it.
        </Banner>
      )}

      <PageHead
        title="Studio terms and privacy"
        meta={doc.updatedAt ? `published ${when(doc.updatedAt)}` : 'never published'}
      />

      <LegalForm
        app={STUDIO_ID}
        initial={{
          privacy: doc.privacy,
          terms: doc.terms,
          contactEmail: doc.contactEmail,
          jurisdiction: doc.jurisdiction,
        }}
        published={exists && doc.updatedAt > 0}
        urls={{ privacy: publicUrl(STUDIO_ID, 'privacy'), terms: publicUrl(STUDIO_ID, 'terms') }}
      />
    </Shell>
  );
}
