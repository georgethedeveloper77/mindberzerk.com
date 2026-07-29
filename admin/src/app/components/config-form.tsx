'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface ManagedKey {
  key: string;
  value: string | null;
  readBy: string;
  app: string;
}

/**
 * PHASE C11 - editing managed Remote Config keys.
 *
 * ## One key at a time, with the ETag from the page
 *
 * Each row publishes independently, carrying the template ETag the page read.
 * If the template moved since - someone edited it in the console - the write
 * returns 409 and this shows "reload", rather than silently overwriting their
 * change. That is the whole reason the value is not just a fire-and-forget PUT.
 *
 * ## The value shows what reads it, right there
 *
 * `readBy` sits under each field because the danger with Remote Config is
 * editing a key whose effect you have half-forgotten. `cdn_base_url` repoints
 * every device's downloads; the note saying so is more useful than a tooltip.
 */
export function ConfigForm({
  app,
  etag,
  keys,
}: {
  app: string;
  etag: string;
  keys: ManagedKey[];
}) {
  const router = useRouter();
  return (
    <div className="space-y-3">
      {keys.map((k) => (
        <KeyRow key={k.key} app={app} etag={etag} item={k} onSaved={() => router.refresh()} />
      ))}
    </div>
  );
}

function KeyRow({
  app,
  etag,
  item,
  onSaved,
}: {
  app: string;
  etag: string;
  item: ManagedKey;
  onSaved: () => void;
}) {
  const [value, setValue] = useState(item.value ?? '');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad' | 'warn'; text: string } | null>(null);

  const dirty = value !== (item.value ?? '');

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await fetch('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: item.key, value, etag }),
      });
      const json = await res.json();
      if (res.ok) {
        setMsg({ tone: 'ok', text: `Published as template v${json.versionNumber}` });
        onSaved();
      } else if (json.stale) {
        setMsg({ tone: 'warn', text: json.error });
      } else {
        setMsg({ tone: 'bad', text: json.error ?? 'Publish failed' });
      }
    } catch (e) {
      setMsg({ tone: 'bad', text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  const tone = { ok: 'text-ok', bad: 'text-bad', warn: 'text-warn' };

  return (
    <section className="rounded-card border border-line-soft bg-surface-1 p-3 sm:p-4">
      <div className="flex items-baseline justify-between gap-2">
        <label className="font-mono text-data text-ink">{item.key}</label>
        {dirty && <span className="text-micro text-warn">unsaved</span>}
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-2">
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          className="min-w-0 flex-1 rounded-lg border border-line bg-surface-2 px-3 py-2 font-mono"
        />
        <button
          onClick={save}
          disabled={!dirty || busy}
          className="rounded-lg bg-accent px-3 py-2 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-40"
        >
          {busy ? 'Publishing' : 'Publish'}
        </button>
      </div>

      <p className="mt-1.5 text-micro leading-relaxed text-ink-3">
        Read by {item.readBy}. Devices fetch on their own schedule, typically
        within twelve hours or on a cold start.
      </p>

      {msg && <p className={`mt-2 text-micro ${tone[msg.tone]}`}>{msg.text}</p>}
    </section>
  );
}
