import { notFound } from 'next/navigation';

import { APPS, type AppId } from '@/lib/catalogue';
import { readDraft } from '@/lib/themes';
import { blankDraft, type ThemeDraft } from '@/lib/theme-spec';
import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { ThemeBuilder } from '@/components/theme-builder/ThemeBuilder';

/**
 * /apps/<app>/themes/builder            new theme
 * /apps/<app>/themes/builder?id=<pack>  edit an existing draft
 *
 * Params and searchParams are async in the App Router (Next 15+), hence awaited.
 */
export default async function ThemeBuilderPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  const { id } = await searchParams;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  const initial: ThemeDraft = id ? (await readDraft(appId, id)) ?? blankDraft(id) : blankDraft();

  return (
    <Shell app={appId}>
      <ThemeBuilder app={appId} initial={initial} />
    </Shell>
  );
}
