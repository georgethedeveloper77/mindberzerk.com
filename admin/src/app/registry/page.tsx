import { adminGate } from '@/app/components/admin-gate';
import { RegistryEditor } from '@/components/studio/registry-editor';
import { StudioShell } from '@/components/studio/shell';
import { isAnchored, readRegistry } from '@/lib/studio/apps';
import { REGISTRY } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * THE STUDIO APP REGISTRY, at /registry.
 *
 * ## Not to be confused with the launcher's
 *
 * `/apps/g-launcher/registry` edits the THIRD-PARTY app registry: WhatsApp,
 * Instagram, the packages G Launcher themes icons for. Different list, different
 * purpose, and it stays under the launcher.
 *
 * This one is the studio's own apps, the list four other things read: the
 * dashboard's counts, the public catalogue, the featured order in Site content,
 * and the legal documents keyed by app id.
 */
export default async function StudioRegistryPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const { apps, exists, corrupt, unreachable } = await readRegistry();
  const anchored = REGISTRY.filter((a) => isAnchored(a.id)).map((a) => a.id);

  return (
    <StudioShell>
      {unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The bucket could not be read, so the list below is the one compiled into the panel rather
          than what is published. Saving now would overwrite the stored registry with it.{' '}
          {unreachable}
        </p>
      )}

      {corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          site/registry.json is present but does not parse. Saving overwrites it with a clean
          document; the list below is the compiled one.
        </p>
      )}

      {!exists && !unreachable && (
        <p className="rounded-[14px] bg-site-info-soft px-4 py-3 text-[13px] leading-relaxed text-site-info">
          Nothing published yet, so this is the list compiled into the panel. Saving it once makes
          the registry editable without a deploy from then on.
        </p>
      )}

      <RegistryEditor initial={apps} anchored={anchored} />
    </StudioShell>
  );
}
