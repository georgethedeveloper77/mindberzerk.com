import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { RegistryEditor } from '@/components/registry-editor/RegistryEditor';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab } from '@/components/studio/ui';
import { APPS, type AppId } from '@/lib/core/catalogue';
import { appMeta, appName } from '@/lib/core/registry';
import { loadRegistrySafe } from './actions';

export const dynamic = 'force-dynamic';

/**
 * THE THIRD-PARTY APP REGISTRY - what G Launcher knows about the apps it can
 * theme, link to, and group.
 *
 * NOT the studio's own app list. That one lives at `/registry` and holds
 * G Launcher, G Recovery and the rest of what Mindberzerk publishes. This holds
 * WhatsApp, Instagram and everything else the launcher draws icons for, which
 * is a different list with a different purpose, so it stays under the app.
 *
 * ─── IT READS `loadRegistrySafe`, AND THAT IS THE POINT ─────────────────────
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
 * So the flag does two things: it draws the banner, and it disables the
 * editor's save. Both are required. The banner alone is an explanation nobody
 * reads before clicking the button.
 */
export default async function RegistryPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();

  const { apps, unreachable } = await loadRegistrySafe(app);
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      {unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The registry could not be read, so the editor below is empty rather than showing what is
          stored. Saving is disabled: writing an empty list over a real registry is not a mistake
          that can be undone from here. {unreachable}
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="App registry"
        meta={`${apps.length} third-party ${apps.length === 1 ? 'app' : 'apps'} the launcher can theme`}
      />

      <RegistryEditor app={app} initial={apps} readOnly={!!unreachable} />
    </StudioShell>
  );
}
