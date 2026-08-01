import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { ConfigForm } from '@/app/components/config-form';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SoftPanel } from '@/components/studio/ui';
import { KNOWN_KEYS, readRemoteConfig, type RcState } from '@/lib/core/remote-config';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * CONFIG - Remote Config, scoped to what the launcher actually reads.
 *
 * ## Why this screen is small, and why that is correct
 *
 * The launcher reads ONE Remote Config value, `cdn_base_url`. `minAppVersion`
 * is per-pack in the signed index, not a global key, and the feature gates from
 * an early mock are per-theme device prefs with no RC key behind them. A panel
 * showing toggles for those would report changes that never reach a device.
 *
 * So this manages exactly the allowlisted keys, shows any other key in the
 * template as read-only (someone may have added one in the console), and
 * carries the shared-template caveat because every app shares one Remote
 * Config.
 *
 * ## The form pattern: editor left, consequence right
 *
 * The right panel is the TEMPLATE the edit lands in: its version, who touched
 * it last and when, and that it is shared. That is the consequence worth seeing
 * while typing, because the failure mode here is not a bad value, it is a good
 * value written over someone else's edit. The ETag refuses that; this panel is
 * where you notice the template moved before it refuses.
 */
export default async function ConfigPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  let state: RcState | null = null;
  let error: string | null = null;
  try {
    state = await readRemoteConfig();
  } catch (e) {
    // "Config not wired" is a normal state on a fresh deploy, so it renders as
    // a sentence rather than a 500.
    error = (e as Error).message;
  }

  // The keys this app owns. `cdn_base_url` is g-launcher's; another app opening
  // this screen sees its own (none yet) rather than someone else's.
  const mine = (state?.managed ?? []).filter(
    (m) => KNOWN_KEYS.find((k) => k.key === m.key)?.app === app,
  );
  // Keys this panel manages for OTHER apps in the shared template. The caveat
  // "one template, all apps" is abstract until you can see whose key is whose.
  const theirs = (state?.managed ?? []).filter(
    (m) => KNOWN_KEYS.find((k) => k.key === m.key)?.app !== app,
  );

  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      {error && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          Remote Config is not readable, so nothing below reflects the live template and nothing
          can be published. Set GCP_PROJECT and grant the service account the Firebase Remote
          Config Admin role, then reload. {error}
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Config"
        meta={state?.versionNumber ? `template v${state.versionNumber}` : 'template not read'}
      />

      {state && (
        <>
          <div className="grid items-start gap-4 lg:grid-cols-[1fr_306px]">
            <div className="min-w-0">
              {mine.length === 0 ? (
                <div className="rounded-[18px] border border-site-line bg-site-card px-[18px] py-10 text-center shadow-site-soft">
                  <p className="mx-auto max-w-[52ch] text-[13px] leading-relaxed text-site-ink-3">
                    {appName(app)} reads no Remote Config value yet. A key appears here once the
                    app grows a reader for one and it is added to the allowlist in
                    lib/core/remote-config.ts.
                  </p>
                </div>
              ) : (
                <ConfigForm app={app} etag={state.etag} keys={mine} />
              )}
            </div>

            <aside className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4">
              <header className="flex items-center gap-3 px-[18px] py-4">
                <span className="grid size-[30px] place-items-center rounded-[9px] bg-site-info-soft text-site-info">
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" aria-hidden>
                    <path d="M8 1.8l5.5 3v6.4L8 14.2 2.5 11.2V4.8L8 1.8z" />
                    <path d="M2.5 4.8L8 7.8l5.5-3M8 7.8v6.4" />
                  </svg>
                </span>
                <h2 className="font-site-display text-[15px] font-bold text-site-ink">Template</h2>
              </header>
              <div className="px-[18px] pb-[18px]">
                <KVRow k="version" v={<span className="font-mono">{state.versionNumber ?? '-'}</span>} />
                <KVRow k="last edited by" v={<span className="font-mono">{state.updatedBy ?? '-'}</span>} />
                <KVRow
                  k="at"
                  v={
                    <span className="font-mono">
                      {state.updateTime ? state.updateTime.slice(0, 19).replace('T', ' ') : '-'}
                    </span>
                  }
                />
                <KVRow k="managed keys" v={state.managed.length} />
                <KVRow k="other keys" v={state.foreign.length} />

                <p className="mt-3 text-[11px] leading-relaxed text-site-ink-3">
                  One template serves every app in the Firebase project, so a publish here rewrites
                  the whole document. The ETag makes that a compare and swap: if someone edits it in
                  the console meanwhile, the write is refused rather than overwriting them.
                </p>

                {theirs.length > 0 && (
                  <div className="mt-3 border-t border-site-line pt-3">
                    <div className="mb-1.5 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
                      Other apps in this template
                    </div>
                    {theirs.map((t) => (
                      <div key={t.key} className="truncate font-mono text-[11px] text-site-ink-2">
                        {t.key}{' '}
                        <span className="text-site-ink-3">
                          {KNOWN_KEYS.find((k) => k.key === t.key)?.app}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </aside>
          </div>

          <SoftPanel
            title="Other keys in the template"
            note="added in the console, carried across untouched"
            right={<span className="font-mono text-[11.5px] text-site-ink-3">{state.foreign.length}</span>}
            flush
          >
            {state.foreign.length === 0 ? (
              <p className="px-[18px] py-6 text-center text-[12.5px] text-site-ink-3">
                None. Every key in the template is one this panel manages.
              </p>
            ) : (
              state.foreign.map((f) => (
                <div
                  key={f.key}
                  className="flex items-center gap-3 border-t border-site-line px-[18px] py-2.5 first:border-t-0"
                >
                  <span className="w-[220px] shrink-0 truncate font-mono text-[12px] text-site-ink">
                    {f.key}
                  </span>
                  <span className="min-w-0 flex-1 truncate font-mono text-[11.5px] text-site-ink-3">
                    {f.value ?? '-'}
                  </span>
                </div>
              ))
            )}
          </SoftPanel>

          <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
            A publish rewrites the whole template and carries these across untouched, so a key
            nobody in this panel knows about is still a key this panel is responsible for not
            losing.
          </p>
        </>
      )}
    </StudioShell>
  );
}
