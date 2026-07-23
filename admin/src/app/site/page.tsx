import { adminGate } from '@/app/components/admin-gate';
import { readSiteContent, resolveFeatured } from '@/lib/site-content';
import { REGISTRY } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { SiteForm } from '@/app/components/site-form';
import { Banner, Card, PageHead, when } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C12 — site content.
 *
 * Lives at /site, not under an app: it is the PUBLISHER's page, describing every
 * app, so nesting it under g-launcher would be wrong. The shell renders with no
 * `app`, which the mobile nav already handles (it defaults contextual links to
 * g-launcher and the bottom bar stays put).
 *
 * The preview strip resolves featured ids through the registry exactly as the
 * static site will, so this page and the deployed site cannot disagree about
 * what a featured card says.
 */
export default async function SitePage() {
  const gate = await adminGate();
  if (gate) return gate;

  const { content, corrupt } = await readSiteContent();
  const preview = resolveFeatured(content.featured);

  const apps = REGISTRY.map((a) => ({
    id: a.id,
    name: a.name,
    mark: a.mark,
    tint: a.tint,
    state: a.state,
    hasLink: !!a.pkg,
  }));

  return (
    <Shell subtitle="mindberzerk.com">
      {corrupt && (
        <Banner tone="bad">
          site/content.json is present but does not parse. Publishing overwrites
          it with a clean document; the editor below is seeded from defaults.
        </Banner>
      )}

      <PageHead
        title="Site content"
        meta={content.updatedAt ? `updated ${when(content.updatedAt)}` : 'never published'}
      />

      {/* Preview strip: the site's own resolution, so what you see is what builds. */}
      <Card title="Featured, as the site resolves it">
        {preview.length === 0 ? (
          <p className="text-data text-ink-3">Nothing featured.</p>
        ) : (
          <div className="grid gap-2 sm:grid-cols-3">
            {preview.map((a) => (
              <div key={a.id} className="rounded-lg border border-line-soft bg-surface-2 p-3">
                <span
                  className="grid size-8 place-items-center rounded-lg font-mono text-data font-bold text-surface-0"
                  style={{ background: a.tint }}
                >
                  {a.mark}
                </span>
                <div className="mt-2 text-data font-medium">{a.name}</div>
                <p className="mt-0.5 text-micro leading-relaxed text-ink-3">{a.blurb}</p>
              </div>
            ))}
          </div>
        )}
      </Card>

      <div className="mt-3 sm:mt-4">
        <SiteForm apps={apps} initial={content} />
      </div>
    </Shell>
  );
}
