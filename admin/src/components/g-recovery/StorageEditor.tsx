'use client';

import { useMemo, useState } from 'react';

/**
 * THE STORAGE MAP. One folder per row, everything visible at once.
 *
 * ─── WHY A TABLE AND NOT A CARD PER FOLDER ──────────────────────────────────
 *
 * The first version was a collapsible panel per folder with a block list inside
 * it. That shape asks for paragraphs: a box that grows invites writing until it
 * stops looking empty. The app is built the other way round, so that a person
 * taps an icon or opens a folder instead of reading, and the editor has to make
 * the short answer the easy one.
 *
 * So: seven columns, no expansion, and a character counter that turns red at
 * the limit rather than a textarea that never fills up.
 *
 * ─── SEVENTY CHARACTERS, REFUSED AT PUBLISH ─────────────────────────────────
 *
 * Counted here so it is visible while typing, and enforced in
 * `content-packs.ts` so it is real. A cap the panel warns about and the server
 * accepts is a cap nobody respects after the first time they ignore it.
 *
 * ─── ORDER IS THE TREE ──────────────────────────────────────────────────────
 *
 * Rows keep the order they are written and the path drives the indent, so the
 * list reads as the tree it describes. Sorting alphabetically would put
 * `Android/data/com.whatsapp` next to `Android/data/com.google` and away from
 * `Android`, which is correct and useless.
 */

type Owner = 'system' | 'app' | 'user';
type Recoverable = 'trash' | 'cache' | 'none';

/**
 * MIRRORS `ICONS` in `content-packs.ts`, which is the gate.
 *
 * That file is server-only and this is a client component, so the list is
 * duplicated rather than imported. Same arrangement `skus.ts` has with
 * `sign.ts`: a validator the browser can reach is a convenience, not a rule.
 * The glyphs stand in for whatever the app draws; only the key ships.
 */
const ICONS: { key: string; glyph: string }[] = [
  { key: 'camera', glyph: '\u25A3' },
  { key: 'image', glyph: '\u25A4' },
  { key: 'video', glyph: '\u25B6' },
  { key: 'audio', glyph: '\u266A' },
  { key: 'download', glyph: '\u25BC' },
  { key: 'document', glyph: '\u2261' },
  { key: 'app', glyph: '\u25C8' },
  { key: 'cache', glyph: '\u25CC' },
  { key: 'archive', glyph: '\u25A6' },
  { key: 'folder', glyph: '\u25A1' },
  { key: 'trash', glyph: '\u2327' },
  { key: 'system', glyph: '\u2699' },
];

const SUMMARY_MAX = 70;

interface Node {
  /** Relative to shared storage. Empty means the volume root itself. */
  path: string;
  label: string;
  /** What an acronym stands for. One of the few things worth a second line. */
  expand?: string;
  summary: string;
  icon: string;
  owner?: Owner;
  pkg?: string;
  recoverable: Recoverable;
}

interface StorageMap {
  id: string;
  version: number;
  generatedAt?: string;
  nodes: Node[];
  [k: string]: unknown;
}

const EMPTY: StorageMap = { id: 'storage-map', version: 1, nodes: [] };

/**
 * A starting map, offered once when nothing is published.
 *
 * THESE ARE THE FOLDERS EVERY ANDROID DEVICE HAS, so they are a statement about
 * the platform rather than a guess about anyone's phone. Every line is inside
 * the limit, which is also the point: it is what the limit looks like.
 */
const SEED: Node[] = [
  {
    path: 'DCIM',
    label: 'Camera',
    expand: 'Digital Camera Images',
    summary: 'Where the camera writes.',
    icon: 'camera',
    owner: 'system',
    recoverable: 'trash',
  },
  {
    path: 'DCIM/.thumbnails',
    label: 'Thumbnails',
    summary: 'Small previews the gallery draws instead of the photo.',
    icon: 'cache',
    owner: 'system',
    recoverable: 'cache',
  },
  {
    path: 'Pictures',
    label: 'Pictures',
    summary: 'Images that did not come from the camera.',
    icon: 'image',
    owner: 'system',
    recoverable: 'trash',
  },
  {
    path: 'Movies',
    label: 'Movies',
    summary: 'Video that is not camera footage.',
    icon: 'video',
    owner: 'system',
    recoverable: 'trash',
  },
  {
    path: 'Music',
    label: 'Music',
    summary: 'Audio you added yourself, not what an app streams.',
    icon: 'audio',
    owner: 'system',
    recoverable: 'trash',
  },
  {
    path: 'Download',
    label: 'Downloads',
    summary: 'Anything you saved on purpose.',
    icon: 'download',
    owner: 'user',
    recoverable: 'trash',
  },
  {
    path: 'Documents',
    label: 'Documents',
    summary: 'Files apps filed here rather than in their own folder.',
    icon: 'document',
    owner: 'system',
    recoverable: 'trash',
  },
  {
    path: 'Android/data',
    label: 'App storage',
    summary: 'One folder per app, made by the system, not by you.',
    icon: 'app',
    owner: 'system',
    recoverable: 'none',
  },
  {
    path: 'Android/data/com.whatsapp',
    label: 'WhatsApp',
    summary: 'Everything WhatsApp downloaded. The name is its package.',
    icon: 'app',
    owner: 'app',
    pkg: 'com.whatsapp',
    recoverable: 'trash',
  },
];

export function StorageEditor({
  initial,
  liveVersion,
  unreachable,
}: {
  initial: unknown | null;
  liveVersion: number;
  unreachable: string | null;
}) {
  const [doc, setDoc] = useState<StorageMap>(() => normalise(initial));
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const counts = useMemo(
    () => ({
      nodes: doc.nodes.length,
      gone: doc.nodes.filter((n) => n.recoverable === 'none').length,
      over: doc.nodes.filter((n) => n.summary.length > SUMMARY_MAX).length,
      // Counted separately from `over` because they need different sentences:
      // one is too long, the other is not written yet.
      blank: doc.nodes.filter((n) => n.label.trim() === '' || n.summary.trim() === '').length,
    }),
    [doc],
  );

  function mutate(i: number, patch: Partial<Node>) {
    setDoc((d) => {
      const nodes = [...d.nodes];
      nodes[i] = { ...nodes[i], ...patch };
      return { ...d, nodes };
    });
  }

  function move(i: number, by: number) {
    setDoc((d) => {
      const to = i + by;
      if (to < 0 || to >= d.nodes.length) return d;
      const nodes = [...d.nodes];
      const [row] = nodes.splice(i, 1);
      nodes.splice(to, 0, row);
      return { ...d, nodes };
    });
  }

  async function publish() {
    setBusy(true);
    setMessage(null);
    try {
      const nodes = doc.nodes.map((n) => ({
        path: n.path.trim(),
        label: n.label,
        expand: n.expand?.trim() ? n.expand.trim() : undefined,
        summary: n.summary,
        icon: n.icon,
        owner: n.owner ?? 'system',
        pkg: n.owner === 'app' && n.pkg?.trim() ? n.pkg.trim() : undefined,
        recoverable: n.recoverable,
      }));
      const document = {
        ...doc,
        id: 'storage-map',
        nodes,
        version: doc.version + 1,
        generatedAt: new Date().toISOString(),
      };
      const res = await fetch('/api/publish/content', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packId: 'storage-map', document }),
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
  const canPublish = !busy && !blocked && counts.over === 0 && counts.nodes > 0;

  return (
    <div className="space-y-4">
      {blocked && (
        <p className="rounded-[14px] border border-site-plan/40 bg-site-plan/10 px-4 py-3 text-[12.5px] text-site-ink">
          {unreachable}. Publishing is disabled: editing from an empty document and saving would
          replace the live map rather than update it.
        </p>
      )}

      <div className="flex flex-wrap items-center gap-4 text-[12.5px] text-site-ink-3">
        <span>
          Live pack <strong className="text-site-ink">v{liveVersion || 0}</strong>
        </span>
        <span>
          Map <strong className="text-site-ink">v{doc.version}</strong>
        </span>
        <span>{counts.nodes} folders</span>
        <span>{counts.gone} unrecoverable</span>
        {counts.blank > 0 && <span className="text-site-plan">{counts.blank} unwritten</span>}
        {counts.over > 0 && (
          <span className="text-site-plan">
            {counts.over} over {SUMMARY_MAX}
          </span>
        )}
      </div>

      <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
        <header className="flex flex-wrap items-center gap-2.5 px-[18px] py-3.5">
          <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">
            Folders
          </h2>
          <span className="text-[11.5px] text-site-ink-3">
            In tree order. Paths are relative to shared storage
          </span>
          <div className="ml-auto flex gap-2">
            {doc.nodes.length === 0 && (
              <button type="button" onClick={() => setDoc((d) => ({ ...d, nodes: SEED }))} className={btn}>
                Start from the common folders
              </button>
            )}
            <button
              type="button"
              onClick={() =>
                setDoc((d) => ({
                  ...d,
                  nodes: [
                    ...d.nodes,
                    {
                      path: '',
                      label: '',
                      summary: '',
                      icon: 'folder',
                      owner: 'system' as Owner,
                      recoverable: 'trash' as Recoverable,
                    },
                  ],
                }))
              }
              className={btn}
            >
              Add folder
            </button>
          </div>
        </header>

        <div className="overflow-x-auto border-t border-site-line">
          <table className="w-full min-w-[1020px] border-collapse">
            <thead>
              <tr>
                <Th w="118px">Icon</Th>
                <Th w="188px">Path</Th>
                <Th w="132px">Name</Th>
                <Th w="152px">Stands for</Th>
                <Th>One line</Th>
                <Th w="108px">Owner</Th>
                <Th w="96px">Deleting</Th>
                <Th w="80px"> </Th>
              </tr>
            </thead>
            <tbody>
              {doc.nodes.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-[18px] py-8 text-[12.5px] text-site-ink-3">
                    No folders yet. The starting set covers what every Android device has.
                  </td>
                </tr>
              )}
              {doc.nodes.map((node, i) => (
                <Row
                  key={i}
                  node={node}
                  onChange={(patch) => mutate(i, patch)}
                  onMove={(by) => move(i, by)}
                  onRemove={() => setDoc((d) => ({ ...d, nodes: d.nodes.filter((_, k) => k !== i) }))}
                />
              ))}
            </tbody>
          </table>
        </div>

        <p className="border-t border-site-line px-[18px] py-3 text-[11.5px] leading-relaxed text-site-ink-3">
          {SUMMARY_MAX} characters, hard. Longer will not publish. A folder needs a name, not a
          paragraph: if it needs more, it needs a better name.
        </p>
      </section>

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={!canPublish}
          onClick={publish}
          className="rounded-lg border border-site-accent bg-site-accent px-4 py-2 text-xs font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-45"
        >
          {busy ? 'Publishing' : 'Sign and publish'}
        </button>
        {counts.over > 0 && (
          <span className="text-[12.5px] text-site-plan">
            {counts.over} {counts.over === 1 ? 'row is' : 'rows are'} over the limit
          </span>
        )}
        {message && (
          <span className={`text-[12.5px] ${message.tone === 'ok' ? 'text-site-ok' : 'text-site-plan'}`}>
            {message.text}
          </span>
        )}
      </div>

      <p className="text-[11.5px] leading-relaxed text-site-ink-3">
        Sizes are measured on the device and are never written here. This map supplies the words:
        what a folder is, who put it there, and what deleting from it costs.
      </p>
    </div>
  );
}

// ── one row ─────────────────────────────────────────────────────────────────

function Row({
  node,
  onChange,
  onMove,
  onRemove,
}: {
  node: Node;
  onChange: (patch: Partial<Node>) => void;
  onMove: (by: number) => void;
  onRemove: () => void;
}) {
  // Depth from the path, so the table reads as the tree it describes without
  // storing a parent pointer nobody would keep in step.
  const depth = node.path.trim() === '' ? 0 : node.path.split('/').length - 1;
  const over = node.summary.length > SUMMARY_MAX;

  return (
    <tr className="border-b border-site-line last:border-b-0">
      <td className="px-2 py-1.5 align-top">
        <div className="flex flex-wrap gap-1">
          {ICONS.map((ic) => (
            <button
              key={ic.key}
              type="button"
              title={ic.key}
              onClick={() => onChange({ icon: ic.key })}
              className={`grid size-[24px] place-items-center rounded-lg border text-[12px] transition ${
                node.icon === ic.key
                  ? 'border-site-accent bg-site-accent-soft text-site-accent-deep'
                  : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
              }`}
            >
              {ic.glyph}
            </button>
          ))}
        </div>
      </td>

      <td className="px-2 py-1.5 align-top">
        <input
          value={node.path}
          onChange={(e) => onChange({ path: e.target.value })}
          style={{ paddingLeft: 8 + depth * 12 }}
          className={`${cell} font-mono text-[11.5px]`}
          placeholder="Android/data/com.whatsapp"
        />
      </td>

      <td className="px-2 py-1.5 align-top">
        <input
          value={node.label}
          onChange={(e) => onChange({ label: e.target.value })}
          className={cell}
          placeholder="Camera"
        />
      </td>

      <td className="px-2 py-1.5 align-top">
        <input
          value={node.expand ?? ''}
          onChange={(e) => onChange({ expand: e.target.value })}
          className={cell}
          placeholder="optional"
        />
      </td>

      <td className="px-2 py-1.5 align-top">
        <input
          value={node.summary}
          onChange={(e) => onChange({ summary: e.target.value })}
          className={`${cell} ${over ? 'border-site-plan' : ''}`}
          placeholder="Where the camera writes."
        />
        <div
          className={`pr-2 pt-0.5 text-right font-mono text-[10px] ${
            over ? 'font-bold text-site-plan' : 'text-site-ink-3'
          }`}
        >
          {node.summary.length} / {SUMMARY_MAX}
        </div>
      </td>

      <td className="px-2 py-1.5 align-top">
        <select
          value={node.owner ?? 'system'}
          onChange={(e) => onChange({ owner: e.target.value as Owner })}
          className={cell}
        >
          <option value="system">system</option>
          <option value="app">an app</option>
          <option value="user">the user</option>
        </select>
        {(node.owner ?? 'system') === 'app' && (
          <input
            value={node.pkg ?? ''}
            onChange={(e) => onChange({ pkg: e.target.value })}
            className={`${cell} mt-1 font-mono text-[11px]`}
            placeholder="com.whatsapp"
          />
        )}
      </td>

      <td className="px-2 py-1.5 align-top">
        <select
          value={node.recoverable}
          onChange={(e) => onChange({ recoverable: e.target.value as Recoverable })}
          className={cell}
        >
          <option value="trash">trash</option>
          <option value="cache">cache</option>
          <option value="none">none</option>
        </select>
      </td>

      <td className="px-2 py-1.5 align-top">
        <div className="flex items-center gap-1.5 pt-1.5">
          <button type="button" onClick={() => onMove(-1)} className={tiny}>
            up
          </button>
          <button type="button" onClick={() => onMove(1)} className={tiny}>
            down
          </button>
          <button
            type="button"
            onClick={onRemove}
            className="text-[11px] font-semibold text-site-plan hover:underline"
          >
            x
          </button>
        </div>
      </td>
    </tr>
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

/**
 * A cell that only looks like an input once you are in it.
 *
 * Twenty visible borders across seven columns turns a table into graph paper,
 * and the thing being read here is the words rather than the boxes around them.
 */
const cell =
  'w-full rounded-lg border border-transparent bg-transparent px-2 py-1.5 text-[12.5px] text-site-ink outline-none hover:border-site-line focus:border-site-accent focus:bg-site-page';

const btn =
  'rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45';

const tiny = 'text-[11px] font-semibold text-site-ink-3 transition hover:text-site-ink';

/** Tolerant of anything, because the live document may predate a field. */
function normalise(raw: unknown): StorageMap {
  if (typeof raw !== 'object' || raw === null) return EMPTY;
  const d = raw as Partial<StorageMap>;
  const keys = ICONS.map((i) => i.key);
  const nodes = Array.isArray(d.nodes)
    ? d.nodes.map((n) => ({
        path: typeof n?.path === 'string' ? n.path : '',
        label: typeof n?.label === 'string' ? n.label : '',
        expand: typeof n?.expand === 'string' ? n.expand : undefined,
        summary: typeof n?.summary === 'string' ? n.summary : '',
        // A document written before icons existed lands on the generic one
        // rather than failing to load, and the blank count in the header is
        // what surfaces the rows that still need attention.
        icon: typeof n?.icon === 'string' && keys.includes(n.icon) ? n.icon : 'folder',
        owner: (n?.owner === 'app' || n?.owner === 'user' ? n.owner : 'system') as Owner,
        pkg: typeof n?.pkg === 'string' ? n.pkg : undefined,
        recoverable: (n?.recoverable === 'cache' || n?.recoverable === 'none'
          ? n.recoverable
          : 'trash') as Recoverable,
      }))
    : [];
  return {
    ...EMPTY,
    ...d,
    id: 'storage-map',
    version: typeof d.version === 'number' ? d.version : 1,
    nodes,
  };
}
