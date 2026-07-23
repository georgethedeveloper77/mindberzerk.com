'use client';

import * as React from 'react';
import { C, cssColor } from './console';

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
              color: on ? '#1A1200' : C.dim,
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
            background: props.value ? '#0B1A0E' : C.dim,
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
