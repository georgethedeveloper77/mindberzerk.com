'use client';

import * as React from 'react';
import { C } from './console';
import { BuilderShell, useToast } from '@/components/console';
import { Section } from './primitives';
import {
  MetaEditor,
  PaletteEditor,
  LayoutEditor,
  IconStyleEditor,
  PassthroughEditor,
} from './editors';
import { ThemePreview } from './ThemePreview';
import { GeneratedJson } from './GeneratedJson';
import { saveThemeDraft } from '@/app/apps/[app]/themes/actions';
import {
  validateDraft,
  type IconStyleJson,
  type ThemeDraft,
  type ThemeLayoutJson,
  type ThemePaletteJson,
  type ThemeSpecJson,
} from '@/lib/theme-spec';

export function ThemeBuilder({ app, initial }: { app: string; initial: ThemeDraft }) {
  const [draft, setDraft] = React.useState<ThemeDraft>(initial);
  const [saving, setSaving] = React.useState(false);
  const toast = useToast();

  const setDraftFields = (p: Partial<ThemeDraft>) => setDraft((d) => ({ ...d, ...p }));
  const setSpec = (p: Partial<ThemeSpecJson>) => setDraft((d) => ({ ...d, spec: { ...d.spec, ...p } }));
  const setPalette = (p: Partial<ThemePaletteJson>) =>
    setDraft((d) => ({ ...d, spec: { ...d.spec, palette: { ...d.spec.palette, ...p } } }));
  const setLayout = (p: Partial<ThemeLayoutJson>) =>
    setDraft((d) => ({ ...d, spec: { ...d.spec, layout: { ...d.spec.layout, ...p } } }));
  const setIcons = (p: Partial<IconStyleJson>) =>
    setDraft((d) => ({ ...d, spec: { ...d.spec, icons: { ...(d.spec.icons ?? {}), ...p } } }));

  const problems = validateDraft(draft);
  const valid = problems.length === 0;

  async function save() {
    setSaving(true);
    const res = await saveThemeDraft(app, draft);
    setSaving(false);
    if (res.ok) toast.success(`Saved ${draft.id}`);
    else toast.error(res.error ?? 'Save failed');
  }

  return (
    <BuilderShell
      crumbs={[{ label: 'Apps', href: '/' }, { label: app, href: `/apps/${app}/packs` }, { label: 'Themes', href: `/apps/${app}/themes/builder` }, { label: draft.id || 'new' }]}
      title="Theme builder"
      meta={valid ? '✓ valid' : `✗ ${problems.length} to fix`}
      actions={
        <button type="button" className="tb-btn" disabled={!valid || saving} onClick={save} style={{ fontFamily: C.mono, fontWeight: 700, fontSize: 12.5, color: C.onAccent, background: C.amber, border: 'none', borderRadius: 7, padding: '8px 16px' }}>
          {saving ? 'saving…' : 'save draft'}
        </button>
      }
    >
      <style
        dangerouslySetInnerHTML={{
          __html: `
.tb-grid { display:grid; grid-template-columns: minmax(0,1fr) 404px; gap:18px; align-items:start; }
.tb-right { position: sticky; top: 70px; }
@media (max-width: 1000px){ .tb-grid { grid-template-columns:1fr; } .tb-right{ position:static; } }
`,
        }}
      />


        <div className="tb-grid">
          <div>
            <Section title="theme" hint="identity, fonts, and the storefront card">
              <MetaEditor draft={draft} setDraftFields={setDraftFields} setSpec={setSpec} />
            </Section>
            <Section title="palette" hint="six colours; dock takes an #AARRGGBB alpha byte">
              <PaletteEditor palette={draft.spec.palette} setPalette={setPalette} />
            </Section>
            <Section title="layout" hint="dock side, top bar, grid">
              <LayoutEditor layout={draft.spec.layout} setLayout={setLayout} />
            </Section>
            <Section title="icons" hint="how app icons are shaped and sourced">
              <IconStyleEditor icons={draft.spec.icons ?? {}} setIcons={setIcons} />
            </Section>
            <Section title="boot · splash · desklets" hint="stored verbatim; must be valid JSON">
              <PassthroughEditor spec={draft.spec} setSpec={setSpec} />
            </Section>
          </div>

          <div className="tb-right">
            <div style={{ marginBottom: 16 }}>
              <ThemePreview spec={draft.spec} />
            </div>
            <GeneratedJson draft={draft} />
          </div>
        </div>

    </BuilderShell>
  );
}