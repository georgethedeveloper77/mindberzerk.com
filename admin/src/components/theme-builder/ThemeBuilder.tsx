'use client';

import * as React from 'react';
import { C, ConsoleStyle } from './console';
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
  const [toast, setToast] = React.useState<{ kind: 'ok' | 'err'; msg: string } | null>(null);

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
    setToast(res.ok ? { kind: 'ok', msg: `Saved ${draft.id}` } : { kind: 'err', msg: res.error ?? 'Save failed' });
    window.setTimeout(() => setToast(null), 2800);
  }

  return (
    <div
      className="tb-root tb-scroll"
      style={{
        background: C.bg,
        color: C.ink,
        minHeight: '100vh',
        fontFamily: C.mono,
      }}
    >
      <ConsoleStyle />
      <style
        dangerouslySetInnerHTML={{
          __html: `
.tb-grid { display:grid; grid-template-columns: minmax(0,1fr) 404px; gap:18px; align-items:start; }
.tb-right { position: sticky; top: 70px; }
@media (max-width: 1000px){ .tb-grid { grid-template-columns:1fr; } .tb-right{ position:static; } }
`,
        }}
      />

      <header
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 5,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 16,
          padding: '12px 20px',
          background: 'rgba(8,13,8,0.82)',
          backdropFilter: 'blur(8px)',
          WebkitBackdropFilter: 'blur(8px)',
          borderBottom: `1px solid ${C.line}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
          <span style={{ width: 15, height: 15, borderRadius: 4, background: C.orange, flexShrink: 0 }} />
          <span style={{ fontFamily: C.sans, fontWeight: 500, fontSize: 14, color: C.inkStrong }}>
            theme builder
          </span>
          <span style={{ color: C.faint, fontSize: 13 }}>/ {app}</span>
          <span style={{ color: C.faint, fontSize: 13 }}>/</span>
          <span style={{ color: C.ink, fontSize: 13 }}>{draft.id || 'new'}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <span style={{ fontSize: 11.5, color: valid ? C.green : C.red }}>
            {valid ? '✓ valid' : `✗ ${problems.length} to fix`}
          </span>
          <button
            type="button"
            className="tb-btn"
            disabled={!valid || saving}
            onClick={save}
            style={{
              fontFamily: C.mono,
              fontWeight: 700,
              fontSize: 12.5,
              color: '#1A1200',
              background: C.amber,
              border: 'none',
              borderRadius: 7,
              padding: '8px 16px',
            }}
          >
            {saving ? 'saving…' : 'save draft'}
          </button>
        </div>
      </header>

      <main style={{ maxWidth: 1180, margin: '0 auto', padding: '18px 20px 80px' }}>
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
      </main>

      {toast ? (
        <div
          role="status"
          style={{
            position: 'fixed',
            right: 20,
            bottom: 20,
            zIndex: 50,
            fontFamily: C.mono,
            fontSize: 13,
            color: toast.kind === 'ok' ? C.green : C.red,
            background: C.raised,
            border: `1px solid ${toast.kind === 'ok' ? C.green : C.red}`,
            borderRadius: 8,
            padding: '10px 14px',
            maxWidth: 360,
            boxShadow: '0 12px 30px -12px rgba(0,0,0,0.7)',
          }}
        >
          {toast.msg}
        </div>
      ) : null}
    </div>
  );
}
