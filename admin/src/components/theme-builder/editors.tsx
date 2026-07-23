'use client';

import * as React from 'react';
import { C } from './console';
import { Field, TextInput, NumberInput, SelectInput, Segmented, Toggle, ColorField } from './primitives';
import {
  CHROMES,
  DOCKS,
  ICON_TREATMENTS,
  SHELLS,
  isHexColor,
  type ChromeName,
  type IconStyleJson,
  type ShellName,
  type ThemeDraft,
  type ThemeLayoutJson,
  type ThemePaletteJson,
  type ThemeSpecJson,
} from '@/lib/theme-spec';

const shellLabels: Record<ShellName, string> = {
  gnome: 'GNOME',
  plasma: 'Plasma',
  tiling: 'Tiling',
  tui: 'Terminal',
  aqua: 'Aqua',
};

const twoCol: React.CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
  gap: '0 14px',
};

export function MetaEditor(props: {
  draft: ThemeDraft;
  setDraftFields: (p: Partial<ThemeDraft>) => void;
  setSpec: (p: Partial<ThemeSpecJson>) => void;
}) {
  const { draft, setDraftFields, setSpec } = props;
  const s = draft.spec;
  const chrome: ChromeName | 'auto' = s.chromeFamily ?? 'auto';

  return (
    <>
      <div style={twoCol}>
        <Field label="pack id" hint="lowercase, . _ -">
          <TextInput
            value={draft.id}
            placeholder="ubuntu-24-04"
            onChange={(v) => {
              const id = v.trim();
              setDraftFields({ id });
              setSpec({ id });
            }}
          />
        </Field>
        <Field label="name" hint="shown on the card">
          <TextInput value={s.name} placeholder="Ubuntu" onChange={(v) => setSpec({ name: v })} />
        </Field>
        <Field label="version" hint="display string">
          <TextInput value={s.version} placeholder="24.04" onChange={(v) => setSpec({ version: v })} />
        </Field>
        <Field label="shell">
          <SelectInput<ShellName>
            value={s.shell}
            options={SHELLS}
            labels={shellLabels}
            onChange={(v) => setSpec({ shell: v })}
          />
        </Field>
        <Field label="chrome family" hint="auto = follow shell">
          <SelectInput<ChromeName | 'auto'>
            value={chrome}
            options={['auto', ...CHROMES] as (ChromeName | 'auto')[]}
            onChange={(v) => setSpec({ chromeFamily: v === 'auto' ? null : v })}
          />
        </Field>
        <Field label="min app version" hint="gates old clients">
          <NumberInput
            value={s.minAppVersion}
            min={0}
            step={1}
            onChange={(v) => setSpec({ minAppVersion: v ?? 0 })}
          />
        </Field>
        <Field label="display font">
          <TextInput
            value={s.typography?.display ?? ''}
            placeholder="Ubuntu"
            onChange={(v) => setSpec({ typography: { ...s.typography, display: v || null } })}
          />
        </Field>
        <Field label="mono font">
          <TextInput
            value={s.typography?.mono ?? ''}
            placeholder="UbuntuMono"
            onChange={(v) => setSpec({ typography: { ...s.typography, mono: v || null } })}
          />
        </Field>
      </div>

      <div
        style={{
          marginTop: 6,
          paddingTop: 14,
          borderTop: `1px solid ${C.lineSoft}`,
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '0 14px',
        }}
      >
        <Field label="card title" hint="storefront">
          <TextInput
            value={draft.title}
            placeholder="Ubuntu"
            mono={false}
            onChange={(v) => setDraftFields({ title: v })}
          />
        </Field>
        <Field label="card summary" hint="storefront">
          <TextInput
            value={draft.summary}
            placeholder="24.04 · GNOME"
            mono={false}
            onChange={(v) => setDraftFields({ summary: v })}
          />
        </Field>
        <Field label="sku" hint="blank = free">
          <TextInput
            value={draft.sku ?? ''}
            placeholder="distro_kali"
            onChange={(v) => setDraftFields({ sku: v.trim() === '' ? null : v.trim() })}
          />
        </Field>
        <Field label="pack version" hint="whole number, bumps on publish">
          <NumberInput
            value={draft.packVersion}
            min={1}
            step={1}
            onChange={(v) => setDraftFields({ packVersion: v ?? 1 })}
          />
        </Field>
      </div>
    </>
  );
}

const PALETTE_FIELDS: { key: keyof ThemePaletteJson; label: string; hint: string }[] = [
  { key: 'bgTop', label: 'bg top', hint: 'desktop gradient start' },
  { key: 'bgBottom', label: 'bg bottom', hint: 'gradient end' },
  { key: 'bar', label: 'bar', hint: 'top bar / panel' },
  { key: 'dock', label: 'dock', hint: '#AARRGGBB for translucency' },
  { key: 'accent', label: 'accent', hint: 'the distro colour' },
  { key: 'onDark', label: 'on dark', hint: 'text on the desktop' },
];

export function PaletteEditor(props: {
  palette: ThemePaletteJson;
  setPalette: (p: Partial<ThemePaletteJson>) => void;
}) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0 14px' }}>
      {PALETTE_FIELDS.map((f) => {
        const v = props.palette[f.key];
        return (
          <div key={f.key}>
            <div style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, marginBottom: -4, marginLeft: 2 }}>
              {f.hint}
            </div>
            <ColorField
              label={f.label}
              value={v}
              error={isHexColor(v) ? undefined : 'not a hex colour'}
              onChange={(nv) => props.setPalette({ [f.key]: nv } as Partial<ThemePaletteJson>)}
            />
          </div>
        );
      })}
    </div>
  );
}

export function LayoutEditor(props: {
  layout: ThemeLayoutJson;
  setLayout: (p: Partial<ThemeLayoutJson>) => void;
}) {
  const { layout, setLayout } = props;
  const grid = layout.grid ?? { rows: 5, cols: 4 };
  return (
    <>
      <Field label="dock">
        <Segmented<'left' | 'bottom' | 'off'>
          value={layout.dock}
          options={DOCKS}
          onChange={(v) => setLayout({ dock: v })}
        />
      </Field>
      <div style={{ marginBottom: 12 }}>
        <Toggle
          value={layout.topBar}
          label="Top bar"
          onChange={(v) => setLayout({ topBar: v })}
        />
      </div>
      <div style={twoCol}>
        <Field label="grid rows">
          <NumberInput
            value={grid.rows}
            min={1}
            max={9}
            step={1}
            onChange={(v) => setLayout({ grid: { ...grid, rows: v ?? 5 } })}
          />
        </Field>
        <Field label="grid cols">
          <NumberInput
            value={grid.cols}
            min={1}
            max={9}
            step={1}
            onChange={(v) => setLayout({ grid: { ...grid, cols: v ?? 4 } })}
          />
        </Field>
        <Field label="icon scale" hint="0.7 – 1.4, blank = 1.0">
          <NumberInput
            value={layout.iconScale ?? null}
            min={0.7}
            max={1.4}
            step={0.05}
            placeholder="1.0"
            onChange={(v) => setLayout({ iconScale: v ?? undefined })}
          />
        </Field>
      </div>
    </>
  );
}

export function IconStyleEditor(props: {
  icons: IconStyleJson;
  setIcons: (p: Partial<IconStyleJson>) => void;
}) {
  const { icons, setIcons } = props;
  return (
    <div style={twoCol}>
      <Field label="treatment">
        <SelectInput<string>
          value={icons.treatment ?? 'roundedSquare'}
          options={ICON_TREATMENTS as unknown as string[]}
          onChange={(v) => setIcons({ treatment: v })}
        />
      </Field>
      <Field label="corner radius" hint="0 – 1">
        <NumberInput
          value={icons.cornerRadius ?? null}
          min={0}
          max={1}
          step={0.01}
          placeholder="0.22"
          onChange={(v) => setIcons({ cornerRadius: v ?? undefined })}
        />
      </Field>
      <Field label="foreground scale">
        <NumberInput
          value={icons.foregroundScale ?? null}
          min={0.5}
          max={1.5}
          step={0.05}
          placeholder="1.0"
          onChange={(v) => setIcons({ foregroundScale: v ?? undefined })}
        />
      </Field>
      <Field label="background colour" hint="#hex, blank = none">
        <TextInput
          value={icons.backgroundColor ?? ''}
          placeholder="#31363B"
          onChange={(v) => setIcons({ backgroundColor: v.trim() === '' ? null : v.trim() })}
        />
      </Field>
      <Field label="hero pack" hint="hand-drawn set id">
        <TextInput
          value={icons.heroPack ?? ''}
          placeholder="yaru"
          onChange={(v) => setIcons({ heroPack: v.trim() === '' ? null : v.trim() })}
        />
      </Field>
      <Field label="brand pack" hint="CC0 brand glyphs">
        <TextInput
          value={icons.brandPack ?? ''}
          placeholder="simple-icons"
          onChange={(v) => setIcons({ brandPack: v.trim() === '' ? null : v.trim() })}
        />
      </Field>
    </div>
  );
}

/** boot / splash / desklets are stored verbatim; the builder validates JSON only. */
export function PassthroughEditor(props: {
  spec: ThemeSpecJson;
  setSpec: (p: Partial<ThemeSpecJson>) => void;
}) {
  return (
    <>
      <JsonArea
        label="boot"
        hint="the fake Linux boot log, or blank"
        value={props.spec.boot}
        onChange={(v) => props.setSpec({ boot: v })}
      />
      <JsonArea
        label="splash"
        hint="boot splash style + duration"
        value={props.spec.splash}
        onChange={(v) => props.setSpec({ splash: v })}
      />
      <JsonArea
        label="desklets"
        hint="starter desktop widgets"
        value={props.spec.desklets}
        onChange={(v) => props.setSpec({ desklets: v })}
      />
    </>
  );
}

function JsonArea(props: {
  label: string;
  hint: string;
  value: unknown;
  onChange: (v: unknown) => void;
}) {
  const [text, setText] = React.useState(() =>
    props.value == null ? '' : JSON.stringify(props.value, null, 2),
  );
  const [err, setErr] = React.useState<string | null>(null);

  function handle(t: string) {
    setText(t);
    if (t.trim() === '') {
      setErr(null);
      props.onChange(undefined);
      return;
    }
    try {
      props.onChange(JSON.parse(t));
      setErr(null);
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  return (
    <Field label={props.label} hint={props.hint} error={err ?? undefined}>
      <textarea
        className="tb-textarea tb-scroll"
        value={text}
        onChange={(e) => handle(e.target.value)}
        rows={props.value ? 7 : 3}
        spellCheck={false}
        style={{ resize: 'vertical', lineHeight: 1.5, fontFamily: C.mono, fontSize: 12.5 }}
      />
    </Field>
  );
}
