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
 * ## The value shows what reads it, and what it currently IS
 *
 * `readBy` sits under each field because the danger with Remote Config is
 * editing a key whose effect you have half-forgotten. `cdn_base_url` repoints
 * every device's downloads. The live value sits beside the field for the same
 * reason: an input pre-filled with the current value looks identical whether
 * you have changed it or not, and "what is live right now" is the thing you
 * want while typing a replacement.
 *
 * ## THE VALIDATION IS MIRRORED, NOT MOVED
 *
 * `remote-config.ts` owns `validate` and is `server-only`, so this file cannot
 * import it: doing so would drag the token-minting code into the browser
 * bundle. Without a local copy the form publishes an invalid value and finds
 * out from the server, after the round trip, which for `cdn_base_url` means
 * discovering a typo one step from repointing every device.
 *
 * So the rule is duplicated here, deliberately and with the same standing as
 * `skus.ts` beside `sign.ts`: this copy is a courtesy that fails fast, the
 * server copy is the gate, and the comment on each is what keeps them together.
 */

const LOCAL_RULES: Record<string, (v: string) => string | null> = {
  // Mirrors KNOWN_KEYS['cdn_base_url'].validate in lib/remote-config.ts, which
  // in turn mirrors CdnConfig.baseUrl on device: anything not plainly https in
  // 12 to 200 characters is ignored by the launcher, which silently falls back
  // to its default and reports nothing.
  cdn_base_url: (v) => {
    if (!v.startsWith('https://')) return 'Must start with https:// or the device ignores it.';
    if (v.length < 12 || v.length > 200) return 'Must be 12 to 200 characters.';
    return null;
  },
};

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
  const invalid = value.trim() === '' ? null : (LOCAL_RULES[item.key]?.(value) ?? null);

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

  const tone = { ok: 'text-site-ok', bad: 'text-site-plan', warn: 'text-site-plan' };

  return (
    <section className="rounded-[18px] border border-site-line bg-site-card p-4 shadow-site-soft">
      <div className="flex items-baseline justify-between gap-2">
        <label className="font-mono text-[13px] font-semibold text-site-ink">{item.key}</label>
        {dirty ? (
          <span className="text-[11.5px] font-semibold text-site-plan">unsaved</span>
        ) : (
          <span className="font-mono text-[11px] text-site-ink-3">{app}</span>
        )}
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-2">
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          className={`min-w-0 flex-1 rounded-lg border bg-site-sunk px-3 py-2 font-mono text-[13px] text-site-ink focus:outline-none ${
            invalid ? 'border-site-plan' : 'border-site-line focus:border-site-accent'
          }`}
        />
        <button
          onClick={save}
          disabled={!dirty || busy || !!invalid}
          className="rounded-lg bg-site-accent px-3 py-2 text-[13px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
        >
          {busy ? 'Publishing' : 'Publish'}
        </button>
      </div>

      {invalid && <p className="mt-1.5 text-[11.5px] leading-relaxed text-site-plan">{invalid}</p>}

      {/* WHAT IS LIVE, beside what you are typing. Without it a pre-filled
          input and an edited one look the same. */}
      <div className="mt-2 flex items-baseline justify-between gap-3 border-t border-site-line pt-2">
        <span className="text-[11px] text-site-ink-3">live now</span>
        <span className="truncate text-right font-mono text-[11px] text-site-ink-2">
          {item.value ?? 'not set'}
        </span>
      </div>

      <p className="mt-1.5 text-[11px] leading-relaxed text-site-ink-3">
        Read by {item.readBy}. Devices fetch on their own schedule, typically
        within twelve hours or on a cold start, so a change here is not
        immediate anywhere.
      </p>

      {msg && <p className={`mt-2 text-micro leading-relaxed ${tone[msg.tone]}`}>{msg.text}</p>}
    </section>
  );
}
