import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { loadRegistry } from './actions';
import { RegistryEditor } from '@/components/registry-editor/RegistryEditor';

export default async function RegistryPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const initial = await loadRegistry(app);
  return (
    <Shell app={app}>
      <RegistryEditor app={app} initial={initial} />
    </Shell>
  );
}
