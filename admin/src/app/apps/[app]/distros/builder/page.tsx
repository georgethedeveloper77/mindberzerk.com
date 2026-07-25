import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { DistroWorkspace } from '@/components/distro-builder/DistroWorkspace';

export default async function DistroWorkspacePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  return (
    <Shell app={app as AppId}>
      <DistroWorkspace app={app as AppId} />
    </Shell>
  );
}
