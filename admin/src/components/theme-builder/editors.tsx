'use client';

import * as React from 'react';
import { C } from './console';
import { Field, TextInput, NumberInput, SelectInput, Segmented, Toggle, ColorField } from './primitives';
import {
  CHROMES,
  DOCKS,
  DRAWER_GROUPINGS,
  DRAWER_SCROLLS,
  ICON_TREATMENTS,
  SHELLS,
  isHexColor,
  luminance,
  TOP_BAR_SIDES,
  type ChromeName,
  type IconStyleJson,
  type ShellName,
  type ThemeDraft,
  type ThemeLayoutJson,
  type ThemePaletteJson,
  type DrawerGroupingName,
  type DrawerScrollName,
  type ThemeSpecJson,
  type TopBarSideName,
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

function PaletteGrid(props: {
  palette: ThemePaletteJson;
  setPalette: (p: Partial<ThemePaletteJson>) => void;
  /** Light variant: onDark is the DARK ink that reads on a pale surface. */
  light?: boolean;
}) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0 14px' }}>
      {PALETTE_FIELDS.map((f) => {
        const v = props.palette[f.key];
        const inverted =
          props.light &&
          f.key === 'onDark' &&
          isHexColor(v) &&
          luminance(v) > 0.5;
        return (
          <div key={f.key}>
            <div style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, marginBottom: -4, marginLeft: 2 }}>
              {props.light && f.key === 'onDark' ? 'ink on the light surface' : f.hint}
            </div>
            <ColorField
              label={f.label}
              value={v}
              error={
                !isHexColor(v)
                  ? 'not a hex colour'
                  : inverted
                    ? 'too light: this is the ink, it must read on a pale surface'
                    : undefined
              }
              onChange={(nv) => props.setPalette({ [f.key]: nv } as Partial<ThemePaletteJson>)}
            />
          </div>
        );
      })}
    </div>
  );
}

/**
 * Sensible starting point for a light variant, derived from nothing.
 *
 * Deliberately NOT computed from the dark palette. Inverting six colours
 * algorithmically produces something that is technically light and looks like
 * no desktop anyone ships, and an author who is handed a plausible-looking
 * result is far less likely to replace it than one handed obvious placeholders.
 * The accent carries over because an accent is the brand and does not change
 * between a desktop's light and dark sessions.
 */
function blankLight(dark: ThemePaletteJson): ThemePaletteJson {
  return {
    bgTop: '#E9E6E4',
    bgBottom: '#F7F5F4',
    bar: '#F6F5F4',
    dock: '#D9F6F5F4',
    accent: dark.accent,
    onDark: '#2C2A2B',
  };
}

export function PaletteEditor(props: {
  palette: ThemePaletteJson;
  setPalette: (p: Partial<ThemePaletteJson>) => void;
  paletteLight?: ThemePaletteJson | null;
  setPaletteLight?: (p: ThemePaletteJson | null) => void;
}) {
  const { paletteLight, setPaletteLight } = props;

  return (
    <>
      <PaletteGrid palette={props.palette} setPalette={props.setPalette} />

      {setPaletteLight ? (
        <div style={{ marginTop: 10, paddingTop: 12, borderTop: `1px solid ${C.lineSoft}` }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 12,
              marginBottom: paletteLight ? 12 : 0,
            }}
          >
            <div>
              <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.dim }}>
                light variant
              </div>
              <div style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, marginTop: 3 }}>
                {paletteLight
                  ? 'shown when the user picks light, or when the phone is light'
                  : 'no light mode: this distro stays dark whatever the user picks'}
              </div>
            </div>
            <button
              type="button"
              className="tb-btn"
              onClick={() =>
                setPaletteLight(paletteLight ? null : blankLight(props.palette))
              }
              style={{
                fontFamily: C.mono,
                fontSize: 11.5,
                color: paletteLight ? C.red : C.amber,
                background: 'transparent',
                border: `1px solid ${C.line}`,
                borderRadius: 6,
                padding: '5px 11px',
                flexShrink: 0,
              }}
            >
              {paletteLight ? 'remove' : 'add light variant'}
            </button>
          </div>

          {paletteLight ? (
            <PaletteGrid
              palette={paletteLight}
              setPalette={(p) => setPaletteLight({ ...paletteLight, ...p })}
              light
            />
          ) : null}
        </div>
      ) : null}
    </>
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
          label="Shell bar"
          onChange={(v) => setLayout({ topBar: v })}
        />
      </div>

      {/* Only meaningful when there IS a bar. Showing the position and the
          modules for a distro that has switched the bar off would be two
          controls that change nothing, which is how a builder teaches its own
          user that settings are unreliable. */}
      {layout.topBar ? (
        <>
          <Field label="bar side" hint="a vertical bar shrinks the workspace, the dock moves inboard">
            <Segmented<TopBarSideName>
              value={layout.topBarSide ?? 'top'}
              options={TOP_BAR_SIDES}
              onChange={(v) =>
                setLayout({ topBarSide: v === 'top' ? undefined : v })
              }
            />
          </Field>
          <div style={{ marginBottom: 12 }}>
            <Toggle
              value={layout.topBarStats ?? false}
              label="Show throughput, memory and free space"
              onChange={(v) => setLayout({ topBarStats: v || undefined })}
            />
          </div>
        </>
      ) : null}
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

      {/* A DEFAULT, NOT AN OVERRIDE, and the labels have to say so. Both of
          these are promoted to global prefs on the device, so they apply only
          to a user who has never touched the setting; anyone who has chosen
          keeps their choice through a distro switch. An author who reads this
          as "my distro forces a list drawer" will file the resulting bug
          against the device. */}
      <Field
        label="drawer motion"
        hint="the distro's default for someone who has not chosen"
      >
        <Segmented<DrawerScrollName | 'inherit'>
          value={layout.drawerScrollStyle ?? 'inherit'}
          options={['inherit', ...DRAWER_SCROLLS] as (DrawerScrollName | 'inherit')[]}
          onChange={(v) =>
            setLayout({
              // 'inherit' emits nothing at all rather than emitting 'pages'.
              // Writing today's engine default into the file would freeze this
              // theme on it forever.
              drawerScrollStyle: v === 'inherit' ? undefined : v,
            })
          }
        />
      </Field>
      <Field
        label="drawer grouping"
        hint="only applies where the drawer is a list"
      >
        <Segmented<DrawerGroupingName | 'inherit'>
          value={layout.drawerGrouping ?? 'inherit'}
          options={['inherit', ...DRAWER_GROUPINGS] as (DrawerGroupingName | 'inherit')[]}
          onChange={(v) =>
            setLayout({ drawerGrouping: v === 'inherit' ? undefined : v })
          }
        />
      </Field>
    </>
  );
}

/// The gestures a device can bind, and what a binding may name.
///
/// Mirrors `Gesture` and `GestureAction` in gesture_actions.dart. Duplicated
/// rather than shared because nothing crosses from Dart to this panel at build
/// time, and a stale entry here is survivable in a way the reverse is not: an
/// id the device does not recognise is screened at resolve and falls back to
/// the built-in default, so the worst case is a binding that does nothing
/// rather than a gesture that does the wrong thing.
const GESTURES: { id: string; label: string }[] = [
  { id: 'doubleTapLeftEdge', label: 'Double-tap left edge' },
  { id: 'swipeUp', label: 'Swipe up' },
  { id: 'swipeDown', label: 'Swipe down' },
  { id: 'swipeLeft', label: 'Swipe left' },
  { id: 'swipeRight', label: 'Swipe right' },
  { id: 'doubleTapHome', label: 'Double-tap home' },
  { id: 'twoFingerSwipeDown', label: 'Two-finger swipe down' },
];

/// `needsService` marks the four that ride the accessibility service. They are
/// allowed as theme defaults and simply no-op when the service is off, which is
/// the contract every binding already lives under, but the editor says so: an
/// author choosing one should know it can be inert on a phone that never
/// granted it.
const GESTURE_ACTIONS: { id: string; label: string; needsService?: boolean }[] = [
  { id: '', label: 'inherit' },
  { id: 'none', label: 'Nothing' },
  { id: 'activities', label: 'Open Activities' },
  { id: 'showDock', label: 'Show dock' },
  { id: 'search', label: 'Search apps' },
  { id: 'notifications', label: 'Notification shade', needsService: true },
  { id: 'quickSettings', label: 'Quick settings', needsService: true },
  { id: 'recents', label: 'Recent apps', needsService: true },
  { id: 'lockScreen', label: 'Lock screen', needsService: true },
];

/// `labels` is how [SelectInput] renders a value; an id with no entry falls
/// back to the raw id, which is exactly what an unrecognised binding from an
/// imported theme should show.
const gestureActionLabels: Record<string, string> = Object.fromEntries(
  GESTURE_ACTIONS.map((a) => [a.id, a.label]),
);

export function GesturesEditor(props: {
  gestures: Record<string, string> | undefined;
  setGestures: (next: Record<string, string> | undefined) => void;
}) {
  const { gestures, setGestures } = props;
  const current = gestures ?? {};

  const set = (id: string, action: string) => {
    const next = { ...current };
    // Absent, not empty-string: absent is what "this distro has no opinion"
    // means all the way down, and an empty value would ship a key the device
    // then has to decide how to read.
    if (action === '') delete next[id];
    else next[id] = action;
    setGestures(Object.keys(next).length ? next : undefined);
  };

  return (
    <>
      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginBottom: 12, lineHeight: 1.6 }}>
        Defaults for a user who has never bound that gesture. A gesture someone
        has set is never rebound by switching distro, so these change nothing
        for an existing user who has been through the gestures screen.
      </div>
      {GESTURES.map((g) => {
        const value = current[g.id] ?? '';
        const action = GESTURE_ACTIONS.find((a) => a.id === value);
        // A binding carried in from an imported theme that this panel does not
        // model. Shown as itself rather than silently reset to inherit, which
        // would delete an author's work on a round trip.
        const unknown = value !== '' && !action;
        return (
          <Field
            key={g.id}
            label={g.label}
            hint={
              unknown
                ? `'${value}' is not an action this panel knows. It is kept as written.`
                : action?.needsService
                  ? 'needs the accessibility service; does nothing without it'
                  : undefined
            }
          >
            <SelectInput<string>
              value={value}
              options={
                unknown
                  ? [...GESTURE_ACTIONS.map((a) => a.id), value]
                  : GESTURE_ACTIONS.map((a) => a.id)
              }
              labels={gestureActionLabels}
              onChange={(v) => set(g.id, v)}
            />
          </Field>
        );
      })}
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
