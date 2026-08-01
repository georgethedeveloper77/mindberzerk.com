import { adminGate } from '@/app/components/admin-gate';
import { readSiteContent } from '@/lib/studio/site-content';
import { REGISTRY } from '@/lib/core/registry';
import { Shell } from '@/app/components/shell';
import { SiteForm } from '@/app/components/site-form';
import { Banner, PageHead, when } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C12 - site content.
 *
 * Lives at /site, not under an app: it is the PUBLISHER's page, describing every
 * app, so nesting it under g-launcher would be wrong. The shell renders with no
 * `app`, which the mobile nav already handles.
 *
 * ─── THE PREVIEW MOVED INTO THE FORM, AND THIS PAGE LOST IT ─────────────────
 *
 * This page used to render the featured strip itself, from its own
 * `resolveFeatured` call, ABOVE the editor. That made it a preview of what is
 * PUBLISHED while the editor below showed what you were typing, and the two
 * agreed only until you touched something. `site-form` now builds the same
 * strip from live form state, in the panel beside the editor, which is what its
 * own doc comment always claimed it did.
 *
 * So this page reads the document, resolves the registry rows the form needs,
 * and gets out of the way.
 *
 * ─── AN UNREADABLE BUCKET IS NOT AN EMPTY DOCUMENT ──────────────────────────
 *
 * `readSiteContent` seeds a default when it cannot read, which is right for a
 * fresh bucket and dangerous for a refused credential: the editor would open on
 * seed content, and publishing it would overwrite a live site with defaults.
 * The banner says so, and it is `bad` rather than `warn` for that reason.
 */
export default async function SitePage() {
  const gate = await adminGate();
  if (gate) return gate;

  const { content, corrupt, unreachable } = await readSiteContent();

  const apps = REGISTRY.map((a) => ({
    id: a.id,
    name: a.name,
    mark: a.mark,
    tint: a.tint,
    blurb: a.blurb,
    state: a.state,
    hasLink: !!a.pkg,
  }));

  return (
    <Shell subtitle="mindberzerk.com">
      {unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so the editor below is seeded from
          defaults rather than from what is live. Publishing now would overwrite
          the real document with those defaults. {unreachable}
        </Banner>
      )}

      {corrupt && (
        <Banner tone="bad">
          site/content.json is present but does not parse. Publishing overwrites
          it with a clean document; the editor below is seeded from defaults.
        </Banner>
      )}

      <PageHead
        title="Site content"
        meta={content.updatedAt ? `published ${when(content.updatedAt)}` : 'never published'}
      />

      <SiteForm apps={apps} initial={content} />
    </Shell>
  );
}
