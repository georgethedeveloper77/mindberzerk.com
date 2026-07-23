import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { requireAdmin } from '@/lib/admin';
import { DistroWorkspace } from '@/components/distro-builder/DistroWorkspace';

export default async function DistroWorkspacePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  await requireAdmin();
  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  return <DistroWorkspace app={app as AppId} />;
}
