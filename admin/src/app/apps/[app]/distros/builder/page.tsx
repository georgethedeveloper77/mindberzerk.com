import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { readDraft } from '@/lib/themes';
import { DistroWorkspace } from '@/components/distro-builder/DistroWorkspace';

/**
 * The one editor.
 *
 *   /apps/<app>/distros/builder            a new distro
 *   /apps/<app>/distros/builder?id=<pack>  open an existing one
 *
 * The `?id=` form replaces `/themes/builder?id=`, which is deleted. A theme and
 * a distro were always the same artifact and having two editors meant two
 * places for the schema to drift apart.
 *
 * ─── LOADED ON THE SERVER, NOT FETCHED IN THE CLIENT ────────────────────────
 *
 * The draft is read here and handed down as a prop, so the workspace mounts
 * with the right values in its `useState` initialisers rather than mounting
 * blank and being corrected by an effect. That difference is visible: a builder
 * that flashes a blank palette and then fills in is a builder you do not trust
 * to have loaded everything.
 *
 * A MISSING DRAFT IS NOT A 404. `readDraft` returns null for an id that has no
 * draft, which includes every theme that only exists as a published pack. The
 * workspace opens empty in that case rather than refusing, because an empty
 * builder is a usable thing and a 404 on an Edit button is not.
 */
export default async function DistroWorkspacePage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();

  const { id } = await searchParams;
  // Never let a bad read take the builder down: the point of opening it may be
  // to replace whatever is broken.
  const initial = id
    ? await readDraft(app as AppId, id).catch(() => null)
    : null;

  return (
    <Shell app={app as AppId}>
      <DistroWorkspace app={app as AppId} initial={initial} />
    </Shell>
  );
}
