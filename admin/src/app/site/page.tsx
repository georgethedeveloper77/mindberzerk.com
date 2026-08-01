import { adminGate } from '@/app/components/admin-gate';
import { SiteEditor } from '@/components/studio/site-editor';
import { StudioShell } from '@/components/studio/shell';
import { readSiteContent } from '@/lib/studio/site-content';
import { readRegistry } from '@/lib/studio/apps';

export const dynamic = 'force-dynamic';

/**
 * PHASE C12 - site content, in the studio register.
 *
 * Lives at /site, not under an app: it is the PUBLISHER's page, describing
 * every app, so nesting it under g-launcher would be wrong.
 *
 * ─── THE APP ROWS COME FROM THE STORED REGISTRY, NOT THE COMPILED ONE ───────
 *
 * `readRegistry` returns site/registry.json when it exists and the compiled
 * array when it does not, which is the same list the public catalogue renders.
 * Reading `REGISTRY` directly here would mean an app added through the registry
 * screen could not be featured until a deploy, which is the exact problem that
 * screen exists to remove.
 *
 * ─── AN UNREADABLE BUCKET IS NOT AN EMPTY DOCUMENT ──────────────────────────
 *
 * `readSiteContent` seeds a default when it cannot read, which is right for a
 * fresh bucket and dangerous for a refused credential: the editor would open on
 * seed content, and publishing it would overwrite a live site with defaults.
 * The notice says so, and it is the bad tone for that reason.
 */
export default async function SitePage() {
  const gate = await adminGate();
  if (gate) return gate;

  const [{ content, corrupt, unreachable }, registry] = await Promise.all([
    readSiteContent(),
    readRegistry(),
  ]);

  const apps = registry.apps.map((a) => ({
    id: a.id,
    name: a.name,
    mark: a.mark,
    tint: a.tint,
    blurb: a.blurb,
    state: a.state,
    // What the site actually needs to know: is there anywhere for this card to
    // point. Either store counts.
    hasLink: !!a.pkg || !!a.appStoreAppId,
  }));

  return (
    <StudioShell>
      {unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so the editor below is seeded from defaults rather than from
          what is live. Publishing now would overwrite the real document with those defaults.{' '}
          {unreachable}
        </p>
      )}

      {corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          site/content.json is present but does not parse. Publishing overwrites it with a clean
          document; the editor below is seeded from defaults.
        </p>
      )}

      <SiteEditor apps={apps} initial={content} />
    </StudioShell>
  );
}
