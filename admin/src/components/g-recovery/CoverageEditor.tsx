'use client';

import { useMemo, useState } from 'react';

/**
 * The trashmap editor. THE SCREEN THIS WHOLE PIPELINE EXISTS FOR.
 *
 * Adding a candidate path for a Tecno recycle bin has to be a two minute job
 * done from a laptop, because nobody on this team owns a Tecno and the
 * alternative is a Play release per guess. Everything else here is in service of
 * that being trivial and hard to get wrong.
 *
 * ─── A TABLE, MATCHING STORAGE ──────────────────────────────────────────────
 *
 * This used to be a stack of cards, one per rule, each with its own labelled
 * fields. Fine for three rows and unusable at thirty: comparing two Transsion
 * paths meant scrolling between two cards that looked identical. Rows put every
 * package on one screen, which is how you notice the duplicate you just typed.
 *
 * ─── CLOSED SETS ARE SELECTS, PATHS ARE TEXT ────────────────────────────────
 *
 * `role` picks between Restore and Save on the device, `fidelity` picks the
 * stamp a user reads before they act, and `confidence` decides whether the app
 * promises a result at all. All three are closed, so all three are selects and a
 * typo is impossible. Paths are genuinely free text and stay a box, one per
 * line, which grows as it fills.
 */

type Role = 'trash' | 'status' | 'cache';
type Fidelity = 'full' | 'preview' | 'none';

/**
 * How much this row is trusted. UNDEFINED IS A THIRD STATE, not a default.
 *
 * The scanner cannot tell a path reproduced on hardware from one copied off a
 * forum, so only the person adding the row knows, and an absent value means
 * nobody has said. Writing a value in on their behalf would be inventing one.
 */
type Confidence = 'verified' | 'reported';

interface Entry {
  pkg?: string;
  brand?: string;
  label: string;
  paths: string[];
  role?: Role;
  fidelity?: Fidelity;
  confidence?: Confidence;
  retentionDays?: number;
  _note?: string;
}

interface TrashMap {
  id: string;
  version: number;
  generatedAt?: string;
  restoreFolder?: string;
  apps: Entry[];
  oem: Entry[];
  thumbnails: { paths: string[]; fidelity?: string; role?: string; _note?: string };
  [k: string]: unknown;
}

const EMPTY: TrashMap = {
  id: 'trashmap',
  version: 1,
  restoreFolder: 'Pictures/G Recovery',
  apps: [],
  oem: [],
  thumbnails: { paths: [], fidelity: 'preview', role: 'cache' },
};

export function CoverageEditor({
  initial,
  liveVersion,
  unreachable,
}: {
  initial: unknown | null;
  liveVersion: number;
  unreachable: string | null;
}) {
  const [doc, setDoc] = useState<TrashMap>(() => normalise(initial));
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const counts = useMemo(
    () => ({
      apps: doc.apps.length,
      oem: doc.oem.length,
      paths:
        doc.apps.reduce((n, e) => n + e.paths.length, 0) +
        doc.oem.reduce((n, e) => n + e.paths.length, 0) +
        doc.thumbnails.paths.length,
      status: doc.apps.filter((e) => e.role === 'status').length,
      unstated: [...doc.apps, ...doc.oem].filter((e) => e.confidence === undefined).length,
      empty: [...doc.apps, ...doc.oem].filter((e) => e.paths.length === 0).length,
    }),
    [doc],
  );

  function mutate(kind: 'apps' | 'oem', index: number, patch: Partial<Entry>) {
    setDoc((d) => {
      const next = { ...d, [kind]: [...d[kind]] };
      next[kind][index] = { ...next[kind][index], ...patch };
      return next;
    });
  }

  function addRow(kind: 'apps' | 'oem') {
    setDoc((d) => ({
      ...d,
      [kind]: [
        ...d[kind],
        kind === 'apps'
          ? { pkg: '', label: '', paths: [], role: 'trash' as Role, fidelity: 'full' as Fidelity }
          : { brand: 'any', label: '', paths: [], role: 'trash' as Role, fidelity: 'full' as Fidelity },
      ],
    }));
  }

  function removeRow(kind: 'apps' | 'oem', index: number) {
    setDoc((d) => ({ ...d, [kind]: d[kind].filter((_, i) => i !== index) }));
  }

  async function publish() {
    setBusy(true);
    setMessage(null);
    try {
      // The version in the document is bumped here, and the PACK version is
      // decided by the server from the live index. Two different numbers on
      // purpose: this one is the registry's own, readable on the device, and
      // that one is the immutable object path.
      const document = { ...doc, version: doc.version + 1, generatedAt: new Date().toISOString() };
      const res = await fetch('/api/publish/content', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packId: 'trashmap', document }),
      });
      const body = (await res.json()) as { error?: string; version?: number };
      if (!res.ok) {
        setMessage({ tone: 'bad', text: body.error ?? `HTTP ${res.status}` });
      } else {
        setDoc(document);
        setMessage({
          tone: 'ok',
          text: `Published pack v${body.version}. Devices pick it up on next launch.`,
        });
      }
    } catch (e) {
      setMessage({ tone: 'bad', text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  const blocked = unreachable !== null;

  return (
    <div className="space-y-4">
      {blocked && (
        <p className="rounded-[14px] border border-site-plan/40 bg-site-plan/10 px-4 py-3 text-[12.5px] text-site-ink">
          {unreachable}. Publishing is disabled: editing from an empty document and saving would
          replace the live registry rather than update it.
        </p>
      )}

      <div className="flex flex-wrap items-center gap-4 text-[12.5px] text-site-ink-3">
        <span>
          Live pack <strong className="text-site-ink">v{liveVersion || 0}</strong>
        </span>
        <span>
          Registry <strong className="text-site-ink">v{doc.version}</strong>
        </span>
        <span>{counts.apps} apps</span>
        <span>{counts.oem} brands</span>
        <span>{counts.paths} paths</span>
        <span>{counts.status} status sources</span>
        {counts.empty > 0 && <span className="text-site-plan">{counts.empty} with no path</span>}
        {counts.unstated > 0 && (
          <span className="text-site-plan">{counts.unstated} without confidence</span>
        )}
      </div>

      <Section
        title="Apps"
        note="One row per package. Status sources are saved, not restored"
        idLabel="Package"
        rows={doc.apps}
        idOf={(e) => e.pkg ?? ''}
        onId={(i, v) => mutate('apps', i, { pkg: v })}
        onChange={(i, patch) => mutate('apps', i, patch)}
        onRemove={(i) => removeRow('apps', i)}
        onAdd={() => addRow('apps')}
        placeholder="com.transsion.filemanager"
      />

      <Section
        title="Manufacturers"
        note="Brand 'any' applies everywhere. Matched against Build.MANUFACTURER"
        idLabel="Brand"
        rows={doc.oem}
        idOf={(e) => e.brand ?? ''}
        onId={(i, v) => mutate('oem', i, { brand: v })}
        onChange={(i, patch) => mutate('oem', i, patch)}
        onRemove={(i) => removeRow('oem', i)}
        onAdd={() => addRow('oem')}
        placeholder="tecno"
      />

      <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
        <header className="flex items-center gap-2.5 px-[18px] py-3.5">
          <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">
            Thumbnail cache
          </h2>
          <span className="text-[11.5px] text-site-ink-3">Preview quality only, always</span>
        </header>
        <div className="border-t border-site-line p-3">
          <PathBox
            value={doc.thumbnails.paths}
            onChange={(paths) => setDoc((d) => ({ ...d, thumbnails: { ...d.thumbnails, paths } }))}
          />
        </div>
      </section>

      <div className="flex items-center gap-3">
        <button
          type="button"
          disabled={busy || blocked}
          onClick={publish}
          className="rounded-lg border border-site-accent bg-site-accent px-4 py-2 text-xs font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-45"
        >
          {busy ? 'Publishing' : 'Sign and publish'}
        </button>
        {message && (
          <span className={`text-[12.5px] ${message.tone === 'ok' ? 'text-site-ok' : 'text-site-plan'}`}>
            {message.text}
          </span>
        )}
      </div>

      <p className="text-[11.5px] leading-relaxed text-site-ink-3">
        Every path is a candidate. The scanner probes each one and reports only what exists and
        holds files, so a wrong guess costs one stat call and nothing else. That is what makes it
        safe to publish paths for hardware nobody here owns.
      </p>
    </div>
  );
}

// ── a table of rules ────────────────────────────────────────────────────────

function Section({
  title,
  note,
  idLabel,
  rows,
  idOf,
  onId,
  onChange,
  onRemove,
  onAdd,
  placeholder,
}: {
  title: string;
  note: string;
  idLabel: string;
  rows: Entry[];
  idOf: (entry: Entry) => string;
  onId: (index: number, value: string) => void;
  onChange: (index: number, patch: Partial<Entry>) => void;
  onRemove: (index: number) => void;
  onAdd: () => void;
  placeholder: string;
}) {
  return (
    <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
      <header className="flex flex-wrap items-center gap-2.5 px-[18px] py-3.5">
        <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">
          {title}
        </h2>
        <span className="text-[11.5px] text-site-ink-3">{note}</span>
        <button type="button" onClick={onAdd} className={`${btn} ml-auto`}>
          Add row
        </button>
      </header>

      <div className="overflow-x-auto border-t border-site-line">
        <table className="w-full min-w-[1040px] border-collapse">
          <thead>
            <tr>
              <Th w="196px">{idLabel}</Th>
              <Th w="136px">Label</Th>
              <Th>Candidate paths, one per line</Th>
              <Th w="94px">Role</Th>
              <Th w="98px">Fidelity</Th>
              <Th w="112px">Confidence</Th>
              <Th w="70px">Days</Th>
              <Th w="34px"> </Th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr>
                <td colSpan={8} className="px-[18px] py-7 text-[12.5px] text-site-ink-3">
                  Nothing here yet.
                </td>
              </tr>
            )}
            {rows.map((entry, i) => (
              <tr key={i} className="border-b border-site-line last:border-b-0">
                <td className="px-2 py-1.5 align-top">
                  <input
                    value={idOf(entry)}
                    onChange={(e) => onId(i, e.target.value)}
                    className={`${cell} font-mono text-[11.5px]`}
                    placeholder={placeholder}
                  />
                </td>
                <td className="px-2 py-1.5 align-top">
                  <input
                    value={entry.label}
                    onChange={(e) => onChange(i, { label: e.target.value })}
                    className={cell}
                    placeholder="Tecno Files"
                  />
                </td>
                <td className="px-2 py-1.5 align-top">
                  <PathBox value={entry.paths} onChange={(paths) => onChange(i, { paths })} />
                </td>
                <td className="px-2 py-1.5 align-top">
                  <select
                    value={entry.role ?? 'trash'}
                    onChange={(e) => onChange(i, { role: e.target.value as Role })}
                    className={cell}
                  >
                    <option value="trash">trash</option>
                    <option value="status">status</option>
                    <option value="cache">cache</option>
                  </select>
                </td>
                <td className="px-2 py-1.5 align-top">
                  <select
                    value={entry.fidelity ?? 'full'}
                    onChange={(e) => onChange(i, { fidelity: e.target.value as Fidelity })}
                    className={cell}
                  >
                    <option value="full">full</option>
                    <option value="preview">preview</option>
                    <option value="none">none</option>
                  </select>
                </td>
                <td className="px-2 py-1.5 align-top">
                  <select
                    value={entry.confidence ?? ''}
                    onChange={(e) =>
                      onChange(i, {
                        confidence:
                          e.target.value === '' ? undefined : (e.target.value as Confidence),
                      })
                    }
                    className={`${cell} ${entry.confidence === undefined ? 'text-site-ink-3' : ''}`}
                  >
                    <option value="">unstated</option>
                    <option value="verified">verified</option>
                    <option value="reported">reported</option>
                  </select>
                </td>
                <td className="px-2 py-1.5 align-top">
                  <input
                    value={entry.retentionDays ?? ''}
                    onChange={(e) => {
                      const n = Number(e.target.value);
                      onChange(i, { retentionDays: Number.isFinite(n) && n > 0 ? n : undefined });
                    }}
                    className={`${cell} font-mono text-[11.5px]`}
                    placeholder="30"
                  />
                </td>
                <td className="px-2 py-1.5 align-top">
                  <button
                    type="button"
                    onClick={() => onRemove(i)}
                    className="pt-1.5 text-[11px] font-semibold text-site-plan hover:underline"
                  >
                    x
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function PathBox({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  return (
    <textarea
      rows={Math.max(1, value.length)}
      value={value.join('\n')}
      onChange={(e) =>
        onChange(
          e.target.value
            .split('\n')
            .map((s) => s.trim())
            // Blank lines are dropped on the way out rather than on the way in,
            // so pressing Enter to start a new path does not delete the caret's
            // own line.
            .filter((s) => s.length > 0),
        )
      }
      className={`${cell} resize-y font-mono text-[11.5px] leading-relaxed`}
      placeholder="Android/data/com.example/files/.trash"
    />
  );
}

function Th({ children, w }: { children: React.ReactNode; w?: string }) {
  return (
    <th
      style={w ? { width: w } : undefined}
      className="border-b border-site-line px-2.5 py-2.5 text-left text-[9.5px] font-bold uppercase tracking-[0.11em] text-site-ink-3"
    >
      {children}
    </th>
  );
}

const cell =
  'w-full rounded-lg border border-transparent bg-transparent px-2 py-1.5 text-[12.5px] text-site-ink outline-none hover:border-site-line focus:border-site-accent focus:bg-site-page';

const btn =
  'rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45';

/** Tolerant of anything, because the live document may predate a field. */
function normalise(raw: unknown): TrashMap {
  if (typeof raw !== 'object' || raw === null) return EMPTY;
  const d = raw as Partial<TrashMap>;
  return {
    ...EMPTY,
    ...d,
    apps: Array.isArray(d.apps) ? d.apps.map(fixEntry) : [],
    oem: Array.isArray(d.oem) ? d.oem.map(fixEntry) : [],
    thumbnails: {
      paths: Array.isArray(d.thumbnails?.paths) ? d.thumbnails.paths : [],
      fidelity: d.thumbnails?.fidelity ?? 'preview',
      role: d.thumbnails?.role ?? 'cache',
    },
    id: 'trashmap',
    version: typeof d.version === 'number' ? d.version : 1,
  };
}

function fixEntry(e: Entry): Entry {
  return {
    ...e,
    label: e.label ?? '',
    paths: Array.isArray(e.paths) ? e.paths : [],
    role: (e.role ?? 'trash') as Role,
    fidelity: (e.fidelity ?? 'full') as Fidelity,
  };
}
