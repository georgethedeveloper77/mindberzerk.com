import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { IconPackBuilder } from '@/components/icon-builder/IconPackBuilder';

export default async function IconPackBuilderPage({
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
      <IconPackBuilder app={app as AppId} />
    </Shell>
  );
}
