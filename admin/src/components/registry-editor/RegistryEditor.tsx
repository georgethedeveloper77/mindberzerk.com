'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { BuilderShell, useToast } from '@/components/console';
import { Field, TextInput } from '@/components/theme-builder/primitives';
import { saveRegistry } from '@/app/apps/[app]/registry/actions';
import { blankApp, validateApp, STARTER_APPS, type RegistryApp } from '@/lib/app-registry';

export function RegistryEditor({ app, initial }: { app: string; initial: RegistryApp[] }) {
  const [apps, setApps] = React.useState<RegistryApp[]>(initial);
  const [query, setQuery] = React.useState('');
  const [expanded, setExpanded] = React.useState<Set<number>>(new Set());
  const [saving, setSaving] = React.useState(false);
  const toast = useToast();

  const q = query.trim().toLowerCase();
  const invalidCount = apps.reduce((n, a) => n + (validateApp(a, apps).length ? 1 : 0), 0);
  const valid = invalidCount === 0;
  const publishers = new Set(apps.map((a) => a.publisher.trim()).filter(Boolean)).size;

  function update(i: number, patch: Partial<RegistryApp>) {
    setApps((prev) => prev.map((a, j) => (j === i ? { ...a, ...patch } : a)));
  }
  function remove(i: number) {
    setApps((prev) => prev.filter((_, j) => j !== i));
    setExpanded((prev) => {
      const n = new Set<number>();
      prev.forEach((x) => n.add(x > i ? x - 1 : x));
      n.delete(i);
      return n;
    });
  }
  function add() {
    setApps((prev) => [blankApp(), ...prev]);
    setExpanded((prev) => new Set([0, ...[...prev].map((x) => x + 1)]));
  }
  function toggle(i: number) {
    setExpanded((prev) => {
      const n = new Set(prev);
      if (n.has(i)) n.delete(i);
      else n.add(i);
      return n;
    });
  }

  async function save() {
    setSaving(true);
    const res = await saveRegistry(app, apps);
    setSaving(false);
    if (res.ok) toast.success(`Saved ${apps.length} apps`);
    else toast.error(res.error);
  }

  function matches(a: RegistryApp): boolean {
    if (!q) return true;
    return (a.pkg + ' ' + a.name + ' ' + a.publisher).toLowerCase().includes(q);
  }

  return (
    <BuilderShell
      crumbs={[{ label: 'Apps', href: '/' }, { label: app, href: `/apps/${app}/packs` }, { label: 'Registry' }]}
      title="App registry"
      meta={`${apps.length} apps · ${publishers} publishers${valid ? '' : ` · ${invalidCount} to fix`}`}
      actions={
        <button
          type="button"
          className="tb-btn"
          disabled={!valid || saving}
          onClick={save}
          style={{ fontFamily: C.mono, fontWeight: 700, fontSize: 12.5, color: C.onAccent, background: C.amber, border: 'none', borderRadius: 7, padding: '8px 16px' }}
        >
          {saving ? 'saving…' : 'save'}
        </button>
      }
    >
        <div style={{ display: 'flex', gap: 10, marginBottom: 16, alignItems: 'center' }}>
          <input
            className="tb-input"
            placeholder="filter by package, name, or publisher"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            style={{ flex: 1 }}
          />
          <button
            type="button"
            className="tb-btn"
            onClick={add}
            style={{ fontFamily: C.mono, fontSize: 12.5, color: C.ink, background: C.chip, border: `1px solid ${C.line}`, borderRadius: 7, padding: '9px 14px', whiteSpace: 'nowrap' }}
          >
            + add app
          </button>
          {apps.length === 0 ? (
            <button
              type="button"
              className="tb-btn"
              onClick={() => setApps(STARTER_APPS.map((a) => ({ ...a })))}
              style={{ fontFamily: C.mono, fontSize: 12.5, color: C.amber, background: 'transparent', border: `1px solid ${C.line}`, borderRadius: 7, padding: '9px 14px', whiteSpace: 'nowrap' }}
            >
              seed common apps
            </button>
          ) : null}
        </div>

        <div style={{ border: `1px solid ${C.lineSoft}`, borderRadius: 10, overflow: 'hidden' }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1.5fr 1fr 1fr 64px',
              gap: 10,
              padding: '9px 14px',
              borderBottom: `1px solid ${C.lineSoft}`,
              fontFamily: C.mono,
              fontSize: 11,
              letterSpacing: '0.06em',
              color: C.faint,
              background: C.surface,
            }}
          >
            <span>package</span>
            <span>name</span>
            <span>publisher</span>
            <span />
          </div>

          {apps.length === 0 ? (
            <div style={{ padding: 24, textAlign: 'center', fontFamily: C.mono, fontSize: 12.5, color: C.faint }}>
              No apps yet. Add one, or seed the common set.
            </div>
          ) : null}

          {apps.map((a, i) => {
            if (!matches(a)) return null;
            const probs = validateApp(a, apps);
            const bad = probs.length > 0;
            const open = expanded.has(i);
            return (
              <div key={i} style={{ borderBottom: `1px solid ${C.lineSoft}`, background: open ? C.surface : 'transparent' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr 1fr 64px', gap: 10, padding: '8px 14px', alignItems: 'center' }}>
                  <input className="tb-input" value={a.pkg} placeholder="com.example" spellCheck={false} onChange={(e) => update(i, { pkg: e.target.value.trim() })} style={bad ? { borderColor: C.red } : undefined} />
                  <input className="tb-input" value={a.name} placeholder="Example" onChange={(e) => update(i, { name: e.target.value })} style={{ fontFamily: C.sans }} />
                  <input className="tb-input" value={a.publisher} placeholder="Publisher" onChange={(e) => update(i, { publisher: e.target.value })} style={{ fontFamily: C.sans }} />
                  <div style={{ display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
                    <button type="button" className="tb-btn" onClick={() => toggle(i)} aria-label="details" style={{ background: 'none', border: 'none', color: C.dim, fontFamily: C.mono, fontSize: 14, padding: '0 4px' }}>
                      {open ? '▾' : '▸'}
                    </button>
                    <button type="button" className="tb-btn" onClick={() => remove(i)} aria-label="delete" style={{ background: 'none', border: 'none', color: C.dim, fontFamily: C.mono, fontSize: 15, padding: '0 4px' }}>
                      ×
                    </button>
                  </div>
                </div>

                {open ? (
                  <div style={{ padding: '4px 14px 14px' }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
                      <Field label="play url">
                        <TextInput value={a.playUrl} placeholder="https://play.google.com/…" onChange={(v) => update(i, { playUrl: v })} />
                      </Field>
                      <Field label="app store url">
                        <TextInput value={a.appStoreUrl} placeholder="https://apps.apple.com/…" onChange={(v) => update(i, { appStoreUrl: v })} />
                      </Field>
                    </div>
                    <Field label="about">
                      <TextInput value={a.about} placeholder="one line" mono={false} onChange={(v) => update(i, { about: v })} />
                    </Field>
                    {bad ? (
                      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.red }}>{probs.join(' · ')}</div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>

        <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: 12 }}>
          The publisher field is the one that answers same-publisher questions (Tryst and Fructa) in data rather than in code.
          Stored unsigned, the same way site content is; it never reaches a device through the pack pipeline.
        </div>
    </BuilderShell>
  );
}
