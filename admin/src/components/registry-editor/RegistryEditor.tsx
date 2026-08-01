'use client';

import * as React from 'react';

import { saveRegistry } from '@/app/apps/[app]/registry/actions';
import { blankApp, validateApp, STARTER_APPS, type RegistryApp } from '@/lib/g-launcher/app-registry';

/**
 * THE APP REGISTRY EDITOR: rows on the left, one app in the panel.
 *
 * ─── MOVED OFF THE BUILDER CHROME, THEN ONTO THE SOFT REGISTER ──────────────
 *
 * It first used `BuilderShell` and the `C` inline-style register, which is the
 * theme builder's language, on a screen that is a list of records rather than a
 * design surface. It then carried the console's dark-only tokens, which on the
 * redesigned page rendered as dark inputs on a light card. Both are gone: the
 * page owns the frame, this owns the editing, and every colour here is a
 * `site-` token with a value in both modes.
 *
 * ─── SELECTION IS CLIENT STATE, LIKE BUNDLES AND FOR THE SAME REASON ────────
 *
 * The whole array is one dirty document with a single save at the end, so a
 * link navigation would remount and discard unsaved edits. Rows key off the
 * array index, because a new app has no package until someone types one.
 *
 * The expand-every-row accordion is gone with it: with an inspector there is
 * one open record at a time by construction, which is what the accordion was
 * approximating.
 *
 * ─── [readOnly] IS A SAFETY INTERLOCK, NOT A PREFERENCE ─────────────────────
 *
 * Set when the page could not read the registry. The editor then holds an empty
 * array that is NOT what is stored, and saving it would replace a real registry
 * with nothing. `saveRegistry` refuses that server-side too; this is the half
 * that stops ten minutes of typing being thrown away.
 */
export function RegistryEditor({
  app,
  initial,
  readOnly = false,
}: {
  app: string;
  initial: RegistryApp[];
  readOnly?: boolean;
}) {
  const [apps, setApps] = React.useState<RegistryApp[]>(initial);
  const [query, setQuery] = React.useState('');
  const [sel, setSel] = React.useState<number>(initial.length > 0 ? 0 : -1);
  const [saving, setSaving] = React.useState(false);
  const [msg, setMsg] = React.useState<{ tone: 'ok' | 'bad'; text: string } | null>(null);

  const dirty = JSON.stringify(apps) !== JSON.stringify(initial);
  const q = query.trim().toLowerCase();

  const invalid = apps.filter((a) => validateApp(a, apps).length > 0).length;
  const publishers = new Set(apps.map((a) => a.publisher.trim()).filter(Boolean)).size;

  function update(i: number, patch: Partial<RegistryApp>) {
    setApps((prev) => prev.map((a, j) => (j === i ? { ...a, ...patch } : a)));
  }

  function remove(i: number) {
    setApps((prev) => prev.filter((_, j) => j !== i));
    // Clamp rather than clear: deleting the selected row should land on its
    // neighbour, not on an empty panel.
    setSel((s) => (s > i ? s - 1 : Math.min(s, apps.length - 2)));
  }

  function add() {
    setApps((prev) => [blankApp(), ...prev]);
    setSel(0);
  }

  async function save() {
    setSaving(true);
    setMsg(null);
    const res = await saveRegistry(app, apps);
    setSaving(false);
    if (res.ok) setMsg({ tone: 'ok', text: `Saved ${apps.length} apps` });
    else setMsg({ tone: 'bad', text: res.error });
  }

  const matches = (a: RegistryApp) =>
    !q || `${a.pkg} ${a.name} ${a.publisher}`.toLowerCase().includes(q);

  const shown = apps.map((a, i) => ({ a, i })).filter(({ a }) => matches(a));
  const current = sel >= 0 && sel < apps.length ? apps[sel] : null;
  const currentProblems = current ? validateApp(current, apps) : [];

  const blocked = readOnly
    ? 'The registry could not be read'
    : invalid > 0
      ? `${invalid} ${invalid === 1 ? 'app has' : 'apps have'} a problem`
      : null;

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <button
          onClick={save}
          disabled={!dirty || saving || !!blocked}
          className="rounded-[10px] bg-site-accent px-4 py-2 text-[13px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-40"
        >
          {saving ? 'Saving' : dirty ? 'Save registry' : 'No changes'}
        </button>
        {blocked ? (
          <span className="text-[11.5px] font-semibold text-site-plan">{blocked}</span>
        ) : dirty ? (
          <span className="text-[11.5px] text-site-ink-3">unsaved changes</span>
        ) : null}
        <span className="ml-auto font-mono text-[11.5px] text-site-ink-3">
          {apps.length} {apps.length === 1 ? 'app' : 'apps'} · {publishers}{' '}
          {publishers === 1 ? 'publisher' : 'publishers'}
        </span>
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
        <div className="min-w-0 flex-1">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Filter by package, name, or publisher"
              spellCheck={false}
              className="min-w-0 flex-1 rounded-xl border border-site-line bg-site-sunk px-3 py-2 text-[13px] text-site-ink focus:border-site-accent focus:outline-none"
            />
            <button
              onClick={add}
              disabled={readOnly}
              className="shrink-0 rounded-xl border border-site-line bg-site-card px-3 py-2 text-[13px] font-semibold text-site-ink transition hover:border-site-ink-3/45 disabled:opacity-40"
            >
              Add app
            </button>
            {apps.length === 0 && !readOnly && (
              <button
                onClick={() => {
                  setApps(STARTER_APPS.map((a) => ({ ...a })));
                  setSel(0);
                }}
                className="shrink-0 rounded-xl border border-site-accent/35 bg-site-accent-soft px-3 py-2 text-[13px] font-semibold text-site-accent-deep transition"
              >
                Seed common apps
              </button>
            )}
          </div>

          <div className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
            {apps.length === 0 ? (
              <p className="px-3 py-10 text-center text-[13px] leading-relaxed text-site-ink-3">
                {readOnly
                  ? 'Nothing can be listed while the registry is unreadable.'
                  : 'No apps yet. Add one, or seed the common set.'}
              </p>
            ) : shown.length === 0 ? (
              <p className="px-3 py-10 text-center text-[13px] text-site-ink-3">
                Nothing matches that filter.
              </p>
            ) : (
              shown.map(({ a, i }) => {
                const bad = validateApp(a, apps).length > 0;
                return (
                  <button
                    key={i}
                    onClick={() => setSel(i)}
                    className={`flex w-full items-center gap-2.5 border-b border-site-line px-3 py-2.5 text-left transition last:border-b-0 sm:px-4 ${
                      bad ? 'border-l-2 border-l-site-plan' : ''
                    } ${sel === i ? 'bg-site-accent-soft' : 'hover:bg-site-sunk'}`}
                  >
                    <span className="min-w-0 flex-1">
                      <span
                        className={`block truncate text-[13.5px] font-semibold ${
                          sel === i ? 'text-site-ink' : 'text-site-ink-2'
                        }`}
                      >
                        {a.name || 'unnamed'}
                      </span>
                      <span className="block truncate font-mono text-[11.5px] text-site-ink-3">
                        {a.pkg || 'no package'}
                      </span>
                    </span>
                    <span className="shrink-0 truncate text-[11.5px] text-site-ink-3">
                      {a.publisher || '-'}
                    </span>
                  </button>
                );
              })
            )}
          </div>

          {msg && (
            <p
              className={`mt-3 rounded-[14px] px-4 py-3 text-[13px] leading-relaxed ${
                msg.tone === 'ok' ? 'bg-site-ok-soft text-site-ok' : 'bg-site-plan-soft text-site-plan'
              }`}
            >
              {msg.text}
            </p>
          )}

          <p className="mt-3 px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
            The publisher field is the one that answers same-publisher questions
            in data rather than in code. Stored unsigned, the same way site
            content is; it never reaches a device through the pack pipeline.
          </p>
        </div>

        {current && (
          <aside className="w-full shrink-0 overflow-hidden rounded-[18px] border border-site-line bg-site-card p-4 shadow-site-soft lg:sticky lg:top-4 lg:w-[306px]">
            <div className="font-mono text-[11.5px] text-site-ink-3">editing</div>

            <div className="mt-2 space-y-2">
              <Field
                label="package"
                value={current.pkg}
                placeholder="com.example"
                mono
                invalid={currentProblems.some((p) => p.startsWith('package'))}
                onChange={(v) => update(sel, { pkg: v.trim() })}
              />
              <Field
                label="name"
                value={current.name}
                placeholder="Example"
                onChange={(v) => update(sel, { name: v })}
              />
              <Field
                label="publisher"
                value={current.publisher}
                placeholder="Who ships it"
                onChange={(v) => update(sel, { publisher: v })}
              />
              <Field
                label="play url"
                value={current.playUrl}
                placeholder="https://play.google.com/store/apps/details?id="
                mono
                invalid={currentProblems.some((p) => p.startsWith('Play URL'))}
                onChange={(v) => update(sel, { playUrl: v })}
              />
              <Field
                label="app store url"
                value={current.appStoreUrl}
                placeholder="https://apps.apple.com/app/id"
                mono
                invalid={currentProblems.some((p) => p.startsWith('App Store'))}
                onChange={(v) => update(sel, { appStoreUrl: v })}
              />
              <Field
                label="about"
                value={current.about}
                placeholder="One line"
                onChange={(v) => update(sel, { about: v })}
              />
            </div>

            {currentProblems.length > 0 && (
              <ul className="mt-3 space-y-2 border-t border-site-line pt-3">
                {currentProblems.map((p) => (
                  <li key={p} className="rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11.5px] leading-relaxed text-site-plan">
                    {p}
                  </li>
                ))}
              </ul>
            )}

            <div className="mt-3 border-t border-site-line pt-3">
              <button
                onClick={() => remove(sel)}
                disabled={readOnly}
                className="text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan disabled:opacity-40"
              >
                Delete app
              </button>
            </div>
          </aside>
        )}
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  placeholder,
  mono,
  invalid,
  onChange,
}: {
  label: string;
  value: string;
  placeholder?: string;
  mono?: boolean;
  invalid?: boolean;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label className="block text-[11.5px] text-site-ink-3">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        className={`mt-1 w-full rounded-xl border bg-site-sunk px-3 py-2 text-[13px] text-site-ink focus:outline-none ${
          invalid ? 'border-site-plan' : 'border-site-line focus:border-site-accent'
        } ${mono ? 'font-mono' : ''}`}
      />
    </div>
  );
}
