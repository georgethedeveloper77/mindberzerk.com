import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, PageHead, when } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { LegalForm } from '@/app/components/legal-form';
import { publicUrl, readLegal } from '@/lib/legal';
import { appName, isAppId } from '@/lib/registry';

export const dynamic = 'force-dynamic';

/**
 * PHASE C13 - an app's privacy policy and terms.
 *
 * PER APP, not under /site, and that is the whole reason this page exists
 * separately. `site/content.json` is the publisher's homepage: one hero, one
 * stat strip, an ordered set of registry ids, nothing about any single app.
 * A privacy policy is the opposite: G Launcher's names its accessibility
 * service and its three analytics events, and G Recovery's will name storage
 * access and a home server it uploads to. One document could only be wrong for
 * one of them.
 *
 * The URLs are the deliverable, so they live in the form's right-hand panel
 * beside the problems that are stopping them being safe to paste into Play.
 */
export default async function LegalPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { doc, exists, corrupt, unreachable } = await readLegal(app);

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Legal' }]}
      />

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
          Nothing published yet. The draft below is written against this app&apos;s
          real manifest. Read it before you publish it, because it is a promise
          about what the app does.
        </Banner>
      )}

      <PageHead
        title="Privacy and terms"
        meta={doc.updatedAt ? `published ${when(doc.updatedAt)}` : 'never published'}
      />

      <LegalForm
        app={app}
        initial={{
          privacy: doc.privacy,
          terms: doc.terms,
          contactEmail: doc.contactEmail,
          jurisdiction: doc.jurisdiction,
        }}
        published={exists && doc.updatedAt > 0}
        urls={{ privacy: publicUrl(app, 'privacy'), terms: publicUrl(app, 'terms') }}
      />
    </Shell>
  );
}
