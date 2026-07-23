import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { requireAdmin } from '@/lib/admin';
import { IconPackBuilder } from '@/components/icon-builder/IconPackBuilder';

export default async function IconPackBuilderPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  await requireAdmin();
  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  return <IconPackBuilder app={app as AppId} />;
}
