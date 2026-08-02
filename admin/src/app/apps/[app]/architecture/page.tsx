import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { ArchitectureView } from '@/components/studio/architecture-view';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { ArchitectureMap } from '@/components/studio/architecture-map';
import { graphStatus, viewsFor } from '@/lib/core/architecture-graph';
import { readArchitecture } from '@/lib/core/docs';
import { renderMarkdown } from '@/lib/core/markdown';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * ARCHITECTURE - the diagrams, rendered from the repo.
 *
 * ## Read-only, deliberately
 *
 * There is no editor here and there should not be one. These docs live at
 * `admin/docs/<app>/architecture.md` so that a change to them appears in a diff
 * beside the change it describes; editing them through a form would create a
 * second source of truth that no review ever sees, and a diagram nobody
 * reviewed is a diagram that has quietly drifted.
 *
 * ## Prose on the server, diagrams in the browser
 *
 * The markdown goes through the SAME renderer the legal pages use, which
 * escapes everything before it formats anything, so a doc is not a way to get
 * HTML onto an admin page. Mermaid runs client-side because it needs a DOM to
 * measure text, and it is imported dynamically so no other screen pays for it.
 *
 * ## A missing doc is a normal state
 *
 * G Recovery has no architecture doc yet. That renders as an explanation of
 * where to put one rather than as a 404, because the nav entry exists for every
 * app and a dead link would be worse than an empty page.
 */
export default async function ArchitecturePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const views = viewsFor(app);
  // The map's statuses are read live, so a node saying "credential refused" is
  // reading the same bucket the Overview reads. Fetched alongside the document
  // rather than after it, since neither depends on the other.
  const [doc, status] = await Promise.all([
    readArchitecture(app),
    views.length > 0 ? graphStatus(app) : Promise.resolve({}),
  ]);
  const meta = appMeta(app);

  // Prose is rendered here, index-aligned with the segments, so the client
  // component never sees raw markdown and never needs a parser.
  const html: Record<number, string> = {};
  if (doc) {
    doc.segments.forEach((seg, i) => {
      if (seg.kind === 'markdown') html[i] = renderMarkdown(seg.body);
    });
  }

  const diagrams = doc?.segments.filter((s) => s.kind === 'mermaid').length ?? 0;

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Architecture"
        meta={
          [
            views.length > 0
              ? `${views.length} ${views.length === 1 ? 'view' : 'views'}, read live`
              : null,
            doc ? `${diagrams} ${diagrams === 1 ? 'diagram' : 'diagrams'} in docs/${app}/architecture.md` : null,
          ]
            .filter(Boolean)
            .join(' \u00b7 ') || 'nothing documented yet'
        }
        actions={
          <SlabButton
            href={`https://github.com/search?q=repo%3Amindberzerk+path%3Aadmin%2Fdocs%2F${app}`}
            external
          >
            Edit in the repo
          </SlabButton>
        }
      />

          {/* RENDERED UNCONDITIONALLY. The keyframes belong to the map and the
          prose rules to the document, and a page can have either without the
          other, so gating this on the document cost the map its animation.
          The prose styling and the map's keyframes live here rather than in
              globals.css: they apply to exactly one route's output, and putting
              them in the global sheet would make them look like a site-wide
              contract. */}
          <style
            dangerouslySetInnerHTML={{
              __html: `
@keyframes arch-dash { to { stroke-dashoffset: -32; } }
.arch-flow { animation: arch-dash 1.1s linear infinite; }
@keyframes arch-ping { 0% { transform: scale(.6); opacity: .6; } 100% { transform: scale(1.5); opacity: 0; } }
.arch-ping { animation: arch-ping 1.8s ease-out infinite; }
/* MOVEMENT IS THE FIRST THING TO GO. The colours already carry the whole state,
   so nothing is lost by stopping it. */
@media (prefers-reduced-motion: reduce) {
  .arch-flow, .arch-ping { animation: none; }
}
.arch-prose h1 { font-family: var(--font-site-display); font-size: 22px; font-weight: 800; letter-spacing: -0.025em; color: var(--color-site-ink); margin: 8px 0 10px; }
.arch-prose h2 { font-family: var(--font-site-display); font-size: 17px; font-weight: 700; letter-spacing: -0.02em; color: var(--color-site-ink); margin: 22px 0 8px; }
.arch-prose h3 { font-family: var(--font-site-display); font-size: 14.5px; font-weight: 700; color: var(--color-site-ink); margin: 16px 0 6px; }
.arch-prose p { margin: 0 0 10px; }
.arch-prose ul, .arch-prose ol { margin: 0 0 12px; padding-left: 20px; }
.arch-prose li { margin: 0 0 5px; }
.arch-prose strong { color: var(--color-site-ink); font-weight: 700; }
.arch-prose code { font-family: var(--font-mono); font-size: 11.5px; background: var(--color-site-sunk); color: var(--color-site-ink-2); border-radius: 5px; padding: 1.5px 5px; }
.arch-prose pre { background: var(--color-site-sunk); border-radius: 12px; padding: 12px 14px; overflow-x: auto; margin: 0 0 12px; }
.arch-prose pre code { background: none; padding: 0; font-size: 11.5px; line-height: 1.7; }
.arch-prose blockquote { border-left: 2px solid var(--color-site-accent); background: var(--color-site-accent-soft); border-radius: 0 12px 12px 0; padding: 10px 14px; margin: 0 0 14px; color: var(--color-site-ink-2); }
.arch-prose blockquote p:last-child { margin-bottom: 0; }
.arch-prose hr { border: 0; border-top: 1px solid var(--color-site-line); margin: 20px 0; }
.arch-prose a { color: var(--color-site-accent-deep); }
.arch-prose table { width: 100%; border-collapse: collapse; margin: 0 0 14px; font-size: 12.5px; }
.arch-prose th, .arch-prose td { border-bottom: 1px solid var(--color-site-line); padding: 7px 10px; text-align: left; }
.arch-prose th { color: var(--color-site-ink-3); font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; }
`,
            }}
          />
      {/* THE MAP FIRST, THE DOCUMENT UNDER IT. The map answers "is this working
          and where is the code"; the document answers "why is it shaped like
          this". Both are worth having and they are not the same question. */}
      {views.length > 0 && <ArchitectureMap views={views} status={status} />}

      {!doc ? (
        <div className="rounded-[18px] border border-dashed border-site-line bg-site-card px-6 py-12 text-center shadow-site-soft">
          <p className="text-[14px] font-semibold text-site-ink">
            {appName(app)} has no architecture {views.length > 0 ? 'document' : 'map or document'} yet.
          </p>
          <p className="mx-auto mt-2 max-w-[56ch] text-[12.5px] leading-relaxed text-site-ink-3">
            Create{' '}
            <code className="rounded bg-site-sunk px-1.5 py-0.5 font-mono text-[11.5px] text-site-ink-2">
              admin/docs/{app}/architecture.md
            </code>{' '}
            with mermaid blocks in it and this page renders them. It lives in the repo rather than
            in a form so that a change to the diagrams shows up in the same diff as the change they
            describe.
          </p>
        </div>
      ) : (
        <>
          <ArchitectureView segments={doc.segments} html={html} />
        </>
      )}
    </StudioShell>
  );
}
