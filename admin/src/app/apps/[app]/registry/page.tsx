import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/core/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner, PageHead } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { appName } from '@/lib/core/registry';
import { loadRegistrySafe } from './actions';
import { RegistryEditor } from '@/components/registry-editor/RegistryEditor';

export const dynamic = 'force-dynamic';

/**
 * THE APP REGISTRY - what G Launcher knows about the apps it can theme, link
 * to, and group.
 *
 * ─── THIS PAGE NOW READS `loadRegistrySafe`, AND THAT IS THE POINT ──────────
 *
 * It called `loadRegistry`, which throws. `actions.ts` says in as many words
 * that the page should show a banner and that "until it reads
 * `loadRegistrySafe`, an unreachable bucket looks like an empty registry". It
 * did, and this is that fix.
 *
 * The stakes here are higher than anywhere else in the panel. The editor loads
 * the WHOLE array, edits it in the browser, and `saveRegistry` writes the whole
 * array back. A read that quietly resolved to an empty list would put an empty
 * editor in front of someone, and the moment they added one app and saved,
 * every other app would be gone. `saveRegistry` refuses that from its own end
 * with a read-before-write guard, so nothing is destroyed either way, but a
 * save that fails after ten minutes of typing is a bad way to learn the bucket
 * is down.
 *
 * So the flag does two things: it draws the banner, and it disables the editor's
 * save. Both are required. The banner alone is an explanation nobody reads
 * before clicking the button.
 */
export default async function RegistryPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();

  const { apps, unreachable } = await loadRegistrySafe(app);

  return (
    <Shell app={app} subtitle={`${app} / registry`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Registry' }]}
      />

      {unreachable && (
        <Banner tone="bad">
          The registry could not be read, so the editor below is empty rather
          than showing what is stored. Saving is disabled: writing an empty list
          over a real registry is not a mistake that can be undone from here.{' '}
          {unreachable}
        </Banner>
      )}

      <PageHead
        title="App registry"
        meta={`${apps.length} ${apps.length === 1 ? 'app' : 'apps'}`}
      />

      <RegistryEditor app={app} initial={apps} readOnly={!!unreachable} />
    </Shell>
  );
}
