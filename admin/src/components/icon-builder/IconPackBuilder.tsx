'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { BuilderShell, useToast } from '@/components/console';
import { Section, Field, TextInput, NumberInput, Toggle } from '@/components/theme-builder/primitives';
import { AppGrid, type Assignment } from './AppGrid';
import { publishHeroPackAction } from '@/app/apps/[app]/icons/actions';
import {
  COMMON_APPS,
  canonicalHeroPackJson,
  validateHeroPack,
  type HeroIconEntry,
} from '@/lib/hero-pack';

export function IconPackBuilder({ app }: { app: string }) {
  const [meta, setMeta] = React.useState({
    id: '',
    name: '',
    minAppVersion: 6,
    masked: false,
    sku: '' as string,
  });
  const [entries, setEntries] = React.useState<{ pkg: string; label: string }[]>(() => [...COMMON_APPS]);
  const [assignments, setAssignments] = React.useState<Record<string, Assignment>>({});
  const [publishing, setPublishing] = React.useState(false);
  const toast = useToast();

  const setM = (p: Partial<typeof meta>) => setMeta((m) => ({ ...m, ...p }));

  const order = React.useMemo(
    () => entries.filter((e) => assignments[e.pkg]).map((e) => ({ pkg: e.pkg, file: assignments[e.pkg].file })),
    [entries, assignments],
  );

  const packJson = React.useMemo(() => {
    const icons: Record<string, string> = {};
    for (const o of order) icons[o.pkg] = o.file;
    return canonicalHeroPackJson({ id: meta.id, name: meta.name, masked: meta.masked, icons });
  }, [order, meta.id, meta.name, meta.masked]);

  const problems = React.useMemo(() => {
    const forValidate: HeroIconEntry[] = entries.map((e) => ({
      pkg: e.pkg,
      label: e.label,
      file: assignments[e.pkg]?.file ?? '',
    }));
    return validateHeroPack(
      { id: meta.id, name: meta.name, minAppVersion: meta.minAppVersion, masked: meta.masked, sku: meta.sku || null },
      forValidate,
    );
  }, [entries, assignments, meta]);

  const valid = problems.length === 0;

  function onAssign(pkg: string, a: Assignment | null) {
    setAssignments((prev) => {
      const next = { ...prev };
      if (a) next[pkg] = a;
      else delete next[pkg];
      return next;
    });
  }

  function onAddApp(pkg: string, label: string) {
    setEntries((prev) => (prev.some((e) => e.pkg === pkg) ? prev : [{ pkg, label }, ...prev]));
  }

  async function publish() {
    setPublishing(true);
    try {
      const fd = new FormData();
      fd.append('meta', JSON.stringify({ app, ...meta, sku: meta.sku || null, order }));
      for (const o of order) {
        const a = assignments[o.pkg];
        fd.append(`icon:${o.file}`, a.blob, o.file);
      }
      const res = await publishHeroPackAction(fd);
      if (res.ok) toast.success(`Published ${meta.id} v${res.version}`);
      else toast.error(res.error);
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setPublishing(false);
    }
  }

  const count = order.length;

  return (
    <BuilderShell
      crumbs={[{ label: 'Apps', href: '/' }, { label: app, href: `/apps/${app}/packs` }, { label: 'Icons', href: `/apps/${app}/icons/builder` }, { label: meta.id || 'new' }]}
      title="Icon pack builder"
      meta={valid ? `✓ ${count} ${count === 1 ? 'icon' : 'icons'}` : `✗ ${problems.length} to fix`}
      actions={
        <button type="button" className="tb-btn" disabled={!valid || publishing} onClick={publish} style={{ fontFamily: C.mono, fontWeight: 700, fontSize: 12.5, color: C.onAccent, background: C.amber, border: 'none', borderRadius: 7, padding: '8px 16px' }}>
          {publishing ? 'publishing…' : `publish ${count} ${count === 1 ? 'icon' : 'icons'}`}
        </button>
      }
    >
      <style
        dangerouslySetInnerHTML={{
          __html: `
.ib-grid { display:grid; grid-template-columns: minmax(0,1fr) 360px; gap:18px; align-items:start; }
.ib-right { position: sticky; top: 70px; }
@media (max-width: 1000px){ .ib-grid { grid-template-columns:1fr; } .ib-right{ position:static; } }
`,
        }}
      />


        <div className="ib-grid">
          <div>
            <Section title="pack" hint="a hero pack is icons mapped to app packages">
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0 14px' }}>
                <Field label="pack id" hint="lowercase, . _ -">
                  <TextInput value={meta.id} placeholder="hero-ubuntu" onChange={(v) => setM({ id: v.trim() })} />
                </Field>
                <Field label="name">
                  <TextInput value={meta.name} placeholder="Ubuntu hero icons" mono={false} onChange={(v) => setM({ name: v })} />
                </Field>
                <Field label="min app version">
                  <NumberInput value={meta.minAppVersion} min={0} step={1} onChange={(v) => setM({ minAppVersion: v ?? 0 })} />
                </Field>
                <Field label="sku" hint="blank = free">
                  <TextInput value={meta.sku} placeholder="icons_kali" onChange={(v) => setM({ sku: v.trim() })} />
                </Field>
              </div>
              <div style={{ marginTop: 4 }}>
                <Toggle value={meta.masked} label="Masked (clip art to the theme's shape)" onChange={(v) => setM({ masked: v })} />
                <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: 6 }}>
                  Off is the usual case: the art ships with its own silhouette, drawn as authored.
                </div>
              </div>
            </Section>

            <Section title="icons" hint="assign an image per app; anything not covered falls through to the theme">
              <AppGrid
                entries={entries}
                assignments={assignments}
                masked={meta.masked}
                onAssign={onAssign}
                onAddApp={onAddApp}
              />
            </Section>
          </div>

          <div className="ib-right">
            <HeroPreview order={order} assignments={assignments} masked={meta.masked} />
            <div style={{ height: 16 }} />
            <GeneratedPack json={packJson} problems={problems} />
          </div>
        </div>

    </BuilderShell>
  );
}

function HeroPreview(props: {
  order: { pkg: string; file: string }[];
  assignments: Record<string, Assignment>;
  masked: boolean;
}) {
  return (
    <div style={{ border: `1px solid ${C.lineSoft}`, borderRadius: 10, background: C.surface, overflow: 'hidden' }}>
      <header style={{ padding: '10px 14px', borderBottom: `1px solid ${C.lineSoft}` }}>
        <span style={{ fontFamily: C.mono, fontSize: 11, letterSpacing: '0.14em', color: C.dim }}>preview</span>
      </header>
      {props.order.length === 0 ? (
        <div style={{ padding: 22, textAlign: 'center', fontFamily: C.mono, fontSize: 12.5, color: C.faint }}>
          No icons yet. Add an image to an app on the left.
        </div>
      ) : (
        <div style={{ padding: 14, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          {props.order.map((o) => (
            <div key={o.pkg} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div
                style={{
                  width: 46,
                  height: 46,
                  borderRadius: props.masked ? 12 : 8,
                  overflow: 'hidden',
                  background: '#000',
                }}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={props.assignments[o.pkg].url} alt="" width={46} height={46} style={{ objectFit: 'contain' }} />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function GeneratedPack(props: { json: string; problems: string[] }) {
  const [copied, setCopied] = React.useState(false);
  const valid = props.problems.length === 0;
  async function copy() {
    try {
      await navigator.clipboard.writeText(props.json);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1400);
    } catch {
      /* clipboard blocked; select by hand */
    }
  }
  return (
    <div style={{ border: `1px solid ${C.lineSoft}`, borderRadius: 10, background: C.surface, overflow: 'hidden' }}>
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 14px',
          borderBottom: `1px solid ${C.lineSoft}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontFamily: C.mono, fontSize: 11, letterSpacing: '0.14em', color: C.dim }}>pack.json</span>
          <span style={{ fontFamily: C.mono, fontSize: 11, color: valid ? C.green : C.red }}>
            {valid ? '✓ valid' : `✗ ${props.problems.length}`}
          </span>
        </div>
        <button
          type="button"
          className="tb-btn"
          onClick={copy}
          style={{
            fontFamily: C.mono,
            fontSize: 11.5,
            color: copied ? C.green : C.amber,
            background: 'transparent',
            border: `1px solid ${C.line}`,
            borderRadius: 6,
            padding: '4px 10px',
          }}
        >
          {copied ? 'copied' : 'copy'}
        </button>
      </header>
      {!valid ? (
        <ul style={{ margin: 0, padding: '10px 14px 10px 30px', borderBottom: `1px solid ${C.lineSoft}` }}>
          {props.problems.map((p, i) => (
            <li key={i} style={{ fontFamily: C.mono, fontSize: 12, color: C.red, marginBottom: 3 }}>
              {p}
            </li>
          ))}
        </ul>
      ) : null}
      <pre
        className="tb-scroll"
        style={{
          margin: 0,
          padding: 14,
          maxHeight: 300,
          overflow: 'auto',
          fontFamily: C.mono,
          fontSize: 12,
          lineHeight: 1.55,
          color: C.ink,
          whiteSpace: 'pre',
        }}
      >
        {props.json}
      </pre>
    </div>
  );
}