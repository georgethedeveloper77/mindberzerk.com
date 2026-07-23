'use client';

import * as React from 'react';
import { C } from '@/components/theme-builder/console';
import { Field, TextInput } from '@/components/theme-builder/primitives';
import { isValidPackage } from '@/lib/hero-pack';

export interface Assignment {
  file: string;
  blob: Blob;
  url: string;
}

/** Draw any uploaded image (PNG, WebP, or an SVG with an intrinsic size) into a
 *  192px square, centred and contained, and hand back a PNG blob. Matches the
 *  "fitted to a 192 square, written as PNG" rule the device pipeline expects. */
export function rasterizeTo192(file: File): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const src = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = 192;
      canvas.height = 192;
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        URL.revokeObjectURL(src);
        reject(new Error('Canvas is unavailable'));
        return;
      }
      const scale = Math.min(192 / img.width, 192 / img.height) || 1;
      const w = img.width * scale;
      const h = img.height * scale;
      ctx.clearRect(0, 0, 192, 192);
      ctx.drawImage(img, (192 - w) / 2, (192 - h) / 2, w, h);
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
      const blob = await rasterizeTo192(file);
      if (props.assignment) URL.revokeObjectURL(props.assignment.url);
      props.onAssign({ file: `${props.pkg}.png`, blob, url: URL.createObjectURL(blob) });
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
