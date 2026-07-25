'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { Field, TextInput } from '@/components/theme-builder/primitives';
import { fileNameFor, isValidPackage } from '@/lib/hero-pack';

export interface Assignment {
  file: string;
  blob: Blob;
  url: string;
}

/**
 * Encode an uploaded image as PNG, KEEPING ITS SOURCE DIMENSIONS.
 *
 * icon-pack.ts is explicit: renderHero draws hero art at native size and applies
 * no keyline resize, so the panel must NOT shrink art to a fixed square. That
 * uniformly shrinks correctly-drawn icons. A PNG upload passes through as-is; a
 * non-PNG (WebP, SVG with an intrinsic size, JPEG) is redrawn at its own natural
 * size and re-encoded, preserving resolution and transparency.
 */
export function toPng(file: File): Promise<Blob> {
  if (file.type === 'image/png') return Promise.resolve(file);
  return new Promise((resolve, reject) => {
    const src = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const w = img.naturalWidth || img.width;
      const h = img.naturalHeight || img.height;
      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        URL.revokeObjectURL(src);
        reject(new Error('Canvas is unavailable'));
        return;
      }
      ctx.drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(src);
      canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Could not encode PNG'))), 'image/png');
    };
    img.onerror = () => {
      URL.revokeObjectURL(src);
      reject(new Error('Could not read that image'));
    };
    img.src = src;
  });
}

export function AppGrid(props: {
  entries: { pkg: string; label: string }[];
  assignments: Record<string, Assignment>;
  masked: boolean;
  onAssign: (pkg: string, a: Assignment | null) => void;
  onAddApp: (pkg: string, label: string) => void;
}) {
  return (
    <>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(148px, 1fr))', gap: 10 }}>
        {props.entries.map((e) => (
          <AppTile
            key={e.pkg}
            pkg={e.pkg}
            label={e.label}
            masked={props.masked}
            assignment={props.assignments[e.pkg]}
            onAssign={(a) => props.onAssign(e.pkg, a)}
          />
        ))}
      </div>
      <AddApp existing={props.entries.map((e) => e.pkg)} onAdd={props.onAddApp} />
    </>
  );
}

function AppTile(props: {
  pkg: string;
  label: string;
  masked: boolean;
  assignment?: Assignment;
  onAssign: (a: Assignment | null) => void;
}) {
  const inputRef = React.useRef<HTMLInputElement>(null);
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState(false);

  async function pick(file: File) {
    setBusy(true);
    setErr(false);
    try {
      const blob = await toPng(file);
      if (props.assignment) URL.revokeObjectURL(props.assignment.url);
      props.onAssign({ file: fileNameFor(props.pkg), blob, url: URL.createObjectURL(blob) });
    } catch {
      setErr(true);
    } finally {
      setBusy(false);
    }
  }

  const has = !!props.assignment;
  return (
    <div
      style={{
        border: `1px solid ${has ? C.line : C.lineSoft}`,
        borderRadius: 10,
        background: C.surface,
        padding: 10,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 8,
      }}
    >
      <button
        type="button"
        className="tb-btn"
        onClick={() => inputRef.current?.click()}
        style={{
          width: 60,
          height: 60,
          borderRadius: props.masked ? 15 : 10,
          border: has ? 'none' : `1px dashed ${C.line}`,
          background: has ? '#000' : C.bg,
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 0,
        }}
        aria-label={`Set icon for ${props.label}`}
      >
        {has ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={props.assignment!.url} alt="" width={60} height={60} style={{ objectFit: 'contain' }} />
        ) : (
          <span style={{ color: busy ? C.amber : C.faint, fontFamily: C.mono, fontSize: 11 }}>
            {busy ? '…' : err ? 'retry' : '+ image'}
          </span>
        )}
      </button>

      <div style={{ textAlign: 'center', width: '100%' }}>
        <div style={{ fontFamily: C.sans, fontSize: 12.5, color: C.inkStrong }}>{props.label}</div>
        <div style={{ fontFamily: C.mono, fontSize: 10, color: C.faint, wordBreak: 'break-all' }}>{props.pkg}</div>
      </div>

      {has ? (
        <button
          type="button"
          className="tb-btn"
          onClick={() => {
            URL.revokeObjectURL(props.assignment!.url);
            props.onAssign(null);
          }}
          style={{ background: 'none', border: 'none', color: C.dim, fontFamily: C.mono, fontSize: 10.5 }}
        >
          clear
        </button>
      ) : null}

      <input
        ref={inputRef}
        type="file"
        accept="image/png,image/webp,image/svg+xml,image/jpeg"
        style={{ display: 'none' }}
        onChange={(ev) => {
          const f = ev.target.files?.[0];
          if (f) void pick(f);
          ev.target.value = '';
        }}
      />
    </div>
  );
}

function AddApp(props: { existing: string[]; onAdd: (pkg: string, label: string) => void }) {
  const [pkg, setPkg] = React.useState('');
  const [label, setLabel] = React.useState('');
  const dup = props.existing.includes(pkg.trim());
  const ok = isValidPackage(pkg.trim()) && !!label.trim() && !dup;

  return (
    <div style={{ marginTop: 16, paddingTop: 14, borderTop: `1px solid ${C.lineSoft}` }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr auto', gap: 12, alignItems: 'end' }}>
        <Field label="app name" hint="any app not listed above">
          <TextInput value={label} placeholder="Duolingo" mono={false} onChange={setLabel} />
        </Field>
        <Field
          label="package name"
          error={pkg.trim() && !isValidPackage(pkg.trim()) ? 'not a valid package' : dup ? 'already listed' : undefined}
        >
          <TextInput value={pkg} placeholder="com.duolingo" onChange={setPkg} />
        </Field>
        <button
          type="button"
          className="tb-btn"
          disabled={!ok}
          onClick={() => {
            props.onAdd(pkg.trim(), label.trim());
            setPkg('');
            setLabel('');
          }}
          style={{
            marginBottom: 12,
            fontFamily: C.mono,
            fontSize: 12.5,
            color: C.ink,
            background: C.chip,
            border: `1px solid ${C.line}`,
            borderRadius: 7,
            padding: '8px 14px',
          }}
        >
          add app
        </button>
      </div>
    </div>
  );
}
