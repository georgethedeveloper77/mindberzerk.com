'use client';

import * as React from 'react';
import { C, cssColor } from './console';
import {
  fontOptions,
  fontSample,
  googleFontsHref,
  isBundledFamily,
  isKnownFamily,
} from '@/lib/g-launcher/font-catalogue';

/**
 * Two literals used to live in this file: `#1A1200` on the segmented control
 * and `#0B1A0E` on the toggle knob, both hand-picked to sit on terminal amber.
 * They are `C.onAccent` now, so the accent can change without leaving two
 * near-black smudges behind on a violet fill.
 */
export function Section(props: {
  title: string;
  hint?: string;
  children: React.ReactNode;
  right?: React.ReactNode;
}) {
  return (
    <section
      style={{
        border: `1px solid ${C.lineSoft}`,
        borderRadius: 10,
        background: C.surface,
        marginBottom: 14,
      }}
    >
      <header
        style={{
          display: 'flex',
          alignItems: 'baseline',
          justifyContent: 'space-between',
          gap: 12,
          padding: '11px 14px',
          borderBottom: `1px solid ${C.lineSoft}`,
        }}
      >
        <div>
          <div style={{ fontFamily: C.mono, fontSize: 11, letterSpacing: '0.14em', color: C.dim }}>
            {props.title}
          </div>
          {props.hint ? (
            <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint, marginTop: 3 }}>
              {props.hint}
            </div>
          ) : null}
        </div>
        {props.right}
      </header>
      <div style={{ padding: 14 }}>{props.children}</div>
    </section>
  );
}

export function Field(props: {
  label: string;
  hint?: string;
  error?: string;
  children: React.ReactNode;
  htmlFor?: string;
}) {
  return (
    <label htmlFor={props.htmlFor} style={{ display: 'block', marginBottom: 12 }}>
      <div
        style={{
          fontFamily: C.mono,
          fontSize: 11.5,
          color: C.dim,
          marginBottom: 5,
          display: 'flex',
          gap: 8,
          alignItems: 'baseline',
        }}
      >
        <span>{props.label}</span>
        {props.hint ? <span style={{ color: C.faint }}>{props.hint}</span> : null}
      </div>
      {props.children}
      {props.error ? (
        <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.red, marginTop: 5 }}>
          {props.error}
        </div>
      ) : null}
    </label>
  );
}

export function TextInput(props: {
  id?: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  mono?: boolean;
}) {
  return (
    <input
      id={props.id}
      className="tb-input"
      value={props.value}
      placeholder={props.placeholder}
      onChange={(e) => props.onChange(e.target.value)}
      style={props.mono === false ? { fontFamily: C.sans } : undefined}
    />
  );
}

export function NumberInput(props: {
  id?: string;
  value: number | null;
  onChange: (v: number | null) => void;
  step?: number;
  min?: number;
  max?: number;
  placeholder?: string;
}) {
  return (
    <input
      id={props.id}
      className="tb-input"
      type="number"
      inputMode="decimal"
      value={props.value ?? ''}
      step={props.step}
      min={props.min}
      max={props.max}
      placeholder={props.placeholder}
      onChange={(e) => {
        const raw = e.target.value;
        props.onChange(raw === '' ? null : Number(raw));
      }}
    />
  );
}

export function SelectInput<T extends string>(props: {
  id?: string;
  value: T;
  options: readonly T[];
  onChange: (v: T) => void;
  labels?: Partial<Record<T, string>>;
}) {
  return (
    <select
      id={props.id}
      className="tb-select"
      value={props.value}
      onChange={(e) => props.onChange(e.target.value as T)}
    >
      {props.options.map((o) => (
        <option key={o} value={o} style={{ background: C.bg }}>
          {props.labels?.[o] ?? o}
        </option>
      ))}
    </select>
  );
}

/**
 * The font picker. A grouped listbox, not a `<select>`.
 *
 * ─── WHY IT IS NOT A NATIVE SELECT ──────────────────────────────────────────
 *
 * Every row has to be drawn in the family it names, because a column of
 * eighty-five names all set in one face is a quiz rather than a picker. Chrome
 * ignores `font-family` on `<option>` on several platforms, so a native select
 * would silently render the whole list in one face on exactly the machines it
 * needed to work on. Hence a button plus an absolutely positioned list.
 *
 * ─── THE STYLESHEET IS LOADED ONCE, LAZILY ──────────────────────────────────
 *
 * Injected the first time a picker mounts rather than sitting in the root
 * layout, so only the distro builder pays for it. Browsers fetch a woff2 only
 * when something actually renders in that family, so opening the list is what
 * pulls the faces, not loading the page.
 *
 * ─── FREE TEXT SURVIVES ─────────────────────────────────────────────────────
 *
 * A distro whose face is not on Google Fonts, and an older theme holding a
 * family the catalogue has since dropped, both have to stay editable. So the
 * dropdown is the default rather than a cage, and an unrecognised value opens
 * in custom mode showing exactly what is stored rather than blanking it. What
 * the picker removes is the silent typo, not the escape hatch.
 */
let fontCssInjected = false;

function ensureFontCss() {
  if (fontCssInjected || typeof document === 'undefined') return;
  fontCssInjected = true;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = googleFontsHref();
  document.head.appendChild(link);
}

export function FontSelect(props: {
  value: string;
  mono: boolean;
  placeholder?: string;
  onChange: (v: string) => void;
}) {
  const { value, mono, onChange } = props;
  const { bundled, google } = fontOptions(mono);

  const known = !value.trim() || isKnownFamily(value);
  const [custom, setCustom] = React.useState(!known);
  const [open, setOpen] = React.useState(false);
  const [filter, setFilter] = React.useState('');
  const wrap = React.useRef<HTMLDivElement | null>(null);
  const search = React.useRef<HTMLInputElement | null>(null);

  // Eighty-five rows is a scroll, not a picker. Substring rather than prefix,
  // because someone reaching for Fira Code is as likely to type "code" as
  // "fira", and case-insensitive because nobody types "IBM Plex Mono".
  const q = filter.trim().toLowerCase();
  const match = (e: { family: string }) =>
    !q || e.family.toLowerCase().includes(q);

  // Cleared on close, so reopening does not present a list still narrowed by a
  // search the user has forgotten making.
  React.useEffect(() => {
    if (!open) {
      setFilter('');
      return;
    }
    // Focus after the list has painted, so typing works without a second click.
    const id = window.setTimeout(() => search.current?.focus(), 0);
    return () => window.clearTimeout(id);
  }, [open]);

  React.useEffect(() => ensureFontCss(), []);

  // Click-outside, not blur: a click on a row inside the list blurs the button
  // before the row's own handler runs, so closing on blur eats every selection.
  React.useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (wrap.current && !wrap.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDoc);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (custom) {
    return (
      <div>
        <TextInput
          value={value}
          placeholder={props.placeholder}
          onChange={onChange}
        />
        <button
          type="button"
          onClick={() => setCustom(false)}
          style={{
            marginTop: 5,
            background: 'none',
            border: 'none',
            padding: 0,
            cursor: 'pointer',
            fontFamily: C.mono,
            fontSize: 11,
            color: C.dim,
          }}
        >
          pick from list
        </button>
        {!known && value.trim() ? (
          <div style={{ fontFamily: C.mono, fontSize: 11, color: C.faint, marginTop: 4 }}>
            not bundled and not on Google Fonts: the pack must ship this file
          </div>
        ) : null}
      </div>
    );
  }

  const row = (family: string, isBundled: boolean) => (
    <button
      key={family}
      type="button"
      onClick={() => {
        onChange(family);
        setOpen(false);
      }}
      style={{
        display: 'block',
        width: '100%',
        textAlign: 'left',
        padding: '6px 10px',
        border: 'none',
        cursor: 'pointer',
        fontSize: 13,
        whiteSpace: 'nowrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        background: family === value ? C.lineSoft : 'transparent',
        color: family === value ? C.inkStrong : C.ink,
        // A bundled family has no Google Fonts entry, so it draws in the
        // panel's own face. That is correct rather than a gap: it is a font
        // that lives in the APK.
        fontFamily: isBundled ? C.sans : `'${family}', ${C.sans}`,
      }}
    >
      {isBundled ? family : fontSample(family, mono)}
    </button>
  );

  const shownBundled = bundled.filter(match);
  const shownGoogle = google.filter(match);

  const groupLabel = (text: string, top: boolean) => (
    <div
      style={{
        padding: top ? '7px 10px 3px' : '9px 10px 3px',
        fontFamily: C.mono,
        fontSize: 10.5,
        letterSpacing: '0.1em',
        color: C.faint,
        borderTop: top ? 'none' : `1px solid ${C.lineSoft}`,
      }}
    >
      {text}
    </div>
  );

  return (
    <div ref={wrap} style={{ position: 'relative' }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="tb-input"
        style={{
          width: '100%',
          textAlign: 'left',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 8,
        }}
      >
        <span style={{ color: value ? C.ink : C.faint }}>
          {value || props.placeholder || 'inherit'}
        </span>
        <span style={{ fontFamily: C.mono, fontSize: 10, color: C.faint }}>
          {value && isBundledFamily(value) ? 'bundled' : ''}
        </span>
      </button>

      {open ? (
        <div
          style={{
            position: 'absolute',
            zIndex: 20,
            top: 'calc(100% + 3px)',
            left: 0,
            right: 0,
            maxHeight: 300,
            overflowY: 'auto',
            background: C.surface,
            border: `1px solid ${C.line}`,
            borderRadius: 8,
          }}
        >
          <div style={{ padding: 6, borderBottom: `1px solid ${C.lineSoft}` }}>
            <input
              ref={search}
              className="tb-input"
              value={filter}
              placeholder="filter"
              onChange={(e) => setFilter(e.target.value)}
              style={{ width: '100%', fontFamily: C.mono, fontSize: 12 }}
            />
          </div>

          {shownBundled.length ? groupLabel('bundled, no fetch', true) : null}
          {shownBundled.map((e) => row(e.family, true))}
          {shownGoogle.length
            ? groupLabel('google fonts, fetched on device', shownBundled.length === 0)
            : null}
          {shownGoogle.map((e) => row(e.family, false))}

          {shownBundled.length + shownGoogle.length === 0 ? (
            <div style={{ padding: '10px', fontFamily: C.mono, fontSize: 11.5, color: C.faint }}>
              no family matches that
            </div>
          ) : null}
          <div style={{ borderTop: `1px solid ${C.lineSoft}`, padding: 4 }}>
            <button
              type="button"
              onClick={() => {
                setCustom(true);
                setOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                textAlign: 'left',
                padding: '6px 6px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                fontFamily: C.mono,
                fontSize: 11.5,
                color: C.dim,
              }}
            >
              type a family name
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

export function Segmented<T extends string>(props: {
  value: T;
  options: readonly T[];
  onChange: (v: T) => void;
  labels?: Partial<Record<T, string>>;
}) {
  return (
    <div
      style={{
        display: 'inline-flex',
        border: `1px solid ${C.line}`,
        borderRadius: 7,
        overflow: 'hidden',
      }}
    >
      {props.options.map((o, i) => {
        const on = o === props.value;
        return (
          <button
            key={o}
            type="button"
            className="tb-seg"
            onClick={() => props.onChange(o)}
            style={{
              padding: '7px 13px',
              fontFamily: C.mono,
              fontSize: 12.5,
              border: 'none',
              borderLeft: i === 0 ? 'none' : `1px solid ${C.line}`,
              background: on ? C.amber : 'transparent',
              color: on ? C.onAccent : C.dim,
              fontWeight: on ? 700 : 400,
            }}
          >
            {props.labels?.[o] ?? o}
          </button>
        );
      })}
    </div>
  );
}

export function Toggle(props: { value: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button
      type="button"
      className="tb-btn"
      onClick={() => props.onChange(!props.value)}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 9,
        background: 'transparent',
        border: 'none',
        padding: 0,
      }}
    >
      <span
        style={{
          width: 34,
          height: 20,
          borderRadius: 999,
          background: props.value ? C.green : C.chip,
          border: `1px solid ${props.value ? C.green : C.line}`,
          position: 'relative',
          transition: 'background .12s',
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 2,
            left: props.value ? 16 : 2,
            width: 14,
            height: 14,
            borderRadius: '50%',
            background: props.value ? C.onAccent : C.dim,
            transition: 'left .12s',
          }}
        />
      </span>
      <span style={{ fontFamily: C.mono, fontSize: 12.5, color: C.ink }}>{props.label}</span>
    </button>
  );
}

/**
 * A hex colour field: mono text you can type or paste, plus a live swatch that
 * opens the native picker. The swatch shows the true colour including its alpha
 * byte, so #CC1B1B22 reads as the translucent dock it is.
 */
export function ColorField(props: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  error?: string;
}) {
  // Native <input type=color> only speaks #RRGGBB; feed it the RGB part and keep
  // the author's full string (alpha included) as the source of truth.
  const rgb = '#' + props.value.replace(/^#/, '').slice(-6).padStart(6, '0');
  return (
    <Field label={props.label} error={props.error}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'stretch' }}>
        <span
          style={{
            width: 38,
            borderRadius: 6,
            border: `1px solid ${C.line}`,
            background: cssColor(props.value, C.chip),
            flexShrink: 0,
            position: 'relative',
            overflow: 'hidden',
          }}
        >
          <input
            className="tb-swatch"
            type="color"
            value={rgb}
            onChange={(e) => {
              // Preserve an existing alpha byte if the author had one.
              const s = props.value.replace(/^#/, '');
              const alpha = s.length === 8 ? s.slice(0, 2) : '';
              props.onChange('#' + alpha + e.target.value.replace(/^#/, '').toUpperCase());
            }}
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0 }}
            aria-label={`${props.label} colour picker`}
          />
        </span>
        <input
          className="tb-input"
          value={props.value}
          spellCheck={false}
          onChange={(e) => props.onChange(e.target.value)}
          style={{ flex: 1 }}
        />
      </div>
    </Field>
  );
}
