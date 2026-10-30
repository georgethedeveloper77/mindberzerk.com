'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface ManagedKey {
  key: string;
  value: string | null;
  readBy: string;
  app: string;
  note: string | null;
  /** Pre-filled while the key is unset; published only on a click. */
  suggest: string | null;
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

/** Mirrors storeLink() in lib/core/remote-config.ts. Empty hides the store. */
function storeLink(host?: string): (v: string) => string | null {
  return (v) => {
    if (v === '') return null;
    let url: URL;
    try {
      url = new URL(v);
    } catch {
      return 'Must be a full URL, or empty to hide it.';
    }
    if (url.protocol !== 'https:') return 'Must start with https://.';
    if (host && url.hostname !== host) return `Must be a ${host} link.`;
    return null;
  };
}

const LOCAL_RULES: Record<string, (v: string) => string | null> = {
  // Mirror the G VPN landing keys in KNOWN_KEYS.
  gvpn_play_url: storeLink('play.google.com'),
  gvpn_app_store_url: storeLink('apps.apple.com'),
  gvpn_windows_url: storeLink(),
  gvpn_macos_url: storeLink(),
  gvpn_min_android: (v) =>
    v === '' || /^\d{1,2}(\.\d{1,2})?$/.test(v) ? null : 'A version like 7.0, or empty for the default.',

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
  // Unset keys that have a suggested value: publishable together in one go.
  const pending = keys.filter((k) => k.value === null && k.suggest !== null);
  return (
    <div className="space-y-3">
      {pending.length > 0 && (
        <PublishSuggested etag={etag} keys={pending} onSaved={() => router.refresh()} />
      )}
      {keys.map((k) => (
        <KeyRow key={k.key} app={app} etag={etag} item={k} onSaved={() => router.refresh()} />
      ))}
    </div>
  );
}

/**
 * AUTO-FILL FOR A FRESH TEMPLATE.
 *
 * Each unset key already shows its suggestion in its field; this publishes
 * all of them in one compare-and-swap, so a new app's Config screen is one
 * click from done. Keys someone has set are never included.
 */
function PublishSuggested({
  etag,
  keys,
  onSaved,
}: {
  etag: string;
  keys: ManagedKey[];
  onSaved: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  async function publish() {
    setBusy(true);
    setMsg(null);
    try {
      const values = Object.fromEntries(keys.map((k) => [k.key, k.suggest ?? '']));
      const res = await fetch('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ values, etag }),
      });
      const json = await res.json();
      if (res.ok) {
        setMsg({ tone: 'ok', text: `Published as template v${json.versionNumber}` });
        onSaved();
      } else {
        setMsg({ tone: 'bad', text: json.error ?? 'Publish failed' });
      }
    } catch (e) {
      setMsg({ tone: 'bad', text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="flex flex-wrap items-center justify-between gap-3 rounded-[18px] border border-site-accent/40 bg-site-accent-soft px-4 py-3">
      <p className="text-[12.5px] leading-relaxed text-site-ink-2">
        {keys.length === 1 ? '1 key is' : `${keys.length} keys are`} not set yet. The suggested values are
        filled in below.
      </p>
      <button
        onClick={publish}
        disabled={busy}
        className="rounded-lg bg-site-accent px-3 py-2 text-[13px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
      >
        {busy ? 'Publishing' : 'Publish suggested'}
      </button>
      {msg && (
        <p className={`w-full text-micro ${msg.tone === 'ok' ? 'text-site-ok' : 'text-site-plan'}`}>{msg.text}</p>
      )}
    </section>
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
  // An unset key opens on its suggestion, so publishing it is one click.
  const [value, setValue] = useState(item.value ?? item.suggest ?? '');
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
        {item.value === null && item.suggest !== null && value === item.suggest ? (
          <span className="text-[11.5px] font-semibold text-site-accent">suggested, not published</span>
        ) : dirty ? (
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
        Read by {item.readBy}.{' '}
        {item.note ??
          'Devices fetch on their own schedule, typically within twelve hours or on a cold start, so a change here is not immediate anywhere.'}
      </p>

      {msg && <p className={`mt-2 text-micro leading-relaxed ${tone[msg.tone]}`}>{msg.text}</p>}
    </section>
  );
}
