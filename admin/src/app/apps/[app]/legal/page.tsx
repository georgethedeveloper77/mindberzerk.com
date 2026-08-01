import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, PageHead, when } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { LegalEditor } from '@/components/studio/legal-editor';
import { publicUrl, readLegal } from '@/lib/studio/legal';
import { appName, isAppId } from '@/lib/core/registry';

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
 * ## It shares the editor with the studio, and only the editor
 *
 * `LegalEditor` is register-neutral in everything except its own slab, so this
 * page keeps the console `Shell` around it and the studio page keeps
 * `StudioShell`. One editor, two frames, until the restyle unifies them.
 */
export default async function LegalPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { doc, exists, corrupt, unreachable } = await readLegal(app);

  const urlFor: Record<string, string> = {};
  for (const d of doc.documents) urlFor[d.slug] = publicUrl(app, d.slug);

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      <Breadcrumb items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Legal' }]} />

      {unreachable && (
        <Banner tone="bad">
          The bucket could not be read, so the editor below holds the starting draft rather than
          what is published. Publishing now would overwrite a live policy with that draft.{' '}
          {unreachable}
        </Banner>
      )}

      {corrupt && (
        <Banner tone="bad">
          The stored document is present but does not parse. Publishing overwrites it with a clean
          one; the editor below is seeded from the starting draft.
        </Banner>
      )}

      {!exists && !unreachable && (
        <Banner tone="warn">
          Nothing published yet. The drafts below are written against this app&apos;s real
          manifest. Read them before you publish them, because they are a promise about what the
          app does.
        </Banner>
      )}

      <PageHead
        title="Legal documents"
        meta={doc.updatedAt ? `published ${when(doc.updatedAt)}` : 'never published'}
      />

      <LegalEditor
        app={app}
        initial={{
          documents: doc.documents,
          contactEmail: doc.contactEmail,
          jurisdiction: doc.jurisdiction,
        }}
        urlFor={urlFor}
      />
    </Shell>
  );
}
