import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { requireAdmin } from '@/lib/admin';
import { loadRegistry } from './actions';
import { RegistryEditor } from '@/components/registry-editor/RegistryEditor';

export default async function RegistryPage({ params }: { params: Promise<{ app: string }> }) {
  await requireAdmin();
  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const initial = await loadRegistry(app);
  return <RegistryEditor app={app} initial={initial} />;
}
