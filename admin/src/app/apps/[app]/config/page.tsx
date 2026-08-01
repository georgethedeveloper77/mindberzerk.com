import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { KNOWN_KEYS, readRemoteConfig, type RcState } from '@/lib/core/remote-config';
import { appName, isAppId } from '@/lib/core/registry';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { ConfigForm } from '@/app/components/config-form';
import { Banner, Card, Chip, Empty, KV, PageHead, Table, Td, Th, Tr } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C11 - Remote Config.
 *
 * ## Why this screen is small, and why that is correct
 *
 * The launcher reads ONE Remote Config value, `cdn_base_url`. `minAppVersion` is
 * per-pack in the signed index, not a global key, and the "feature gates" from
 * the early mock are per-theme device prefs with no RC key behind them. A panel
 * that showed toggles for those would report changes that never reach a device.
 *
 * So this manages exactly the allowlisted keys, shows any other keys in the
 * template as read-only (someone may have added one in the console), and carries
 * the shared-template caveat because all the apps share one Remote Config.
 *
 * ## The form pattern: editor left, consequence right
 *
 * The right panel is the TEMPLATE the edit lands in: its version, who touched
 * it last and when, and the fact that it is shared across every app in the
 * project. That is the consequence worth seeing while typing, because the
 * failure mode of this screen is not a bad value, it is a good value written
 * over someone else's edit. The ETag machinery refuses that, and this panel is
 * where you notice the template moved before it refuses.
 *
 * ## When the token or project is not set
 *
 * Reading Remote Config needs `GCP_PROJECT` and a service account with the admin
 * role. Missing either throws, and this catches it into a clear banner rather
 * than a 500, because "config not wired" is a normal state on a fresh deploy.
 */
export default async function ConfigPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  let state: RcState | null = null;
  let error: string | null = null;
  try {
    state = await readRemoteConfig();
  } catch (e) {
    error = (e as Error).message;
  }

  // The keys this app owns. cdn_base_url is g-launcher's; another app opening
  // this screen sees its own (none yet) rather than someone else's.
  const mine = (state?.managed ?? []).filter(
    (m) => KNOWN_KEYS.find((k) => k.key === m.key)?.app === app,
  );

  // Keys this panel manages for OTHER apps in the shared template. Not editable
  // here, and worth naming: the caveat "one template, all apps" is abstract
  // until you can see whose key is whose.
  const theirs = (state?.managed ?? []).filter(
    (m) => KNOWN_KEYS.find((k) => k.key === m.key)?.app !== app,
  );

  return (
    <Shell app={app} subtitle={`${app} / remote config`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Config' }]}
      />

      {error && (
        <Banner tone="warn">
          Remote Config is not readable, so nothing below reflects the live
          template and nothing can be published. Set GCP_PROJECT and grant the
          service account the Firebase Remote Config Admin role, then reload.{' '}
          {error}
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} config`}
        meta={state?.versionNumber ? `template v${state.versionNumber}` : undefined}
      />

      {state && (
        <>
          <div className="flex flex-col gap-3 lg:flex-row lg:items-start">
            <div className="min-w-0 flex-1">
              {mine.length === 0 ? (
                <Empty>
                  {appName(app)} reads no Remote Config value yet. A key appears
                  here once the app grows a reader for one and it is added to the
                  allowlist in lib/remote-config.ts.
                </Empty>
              ) : (
                <ConfigForm app={app} etag={state.etag} keys={mine} />
              )}
            </div>

            <aside className="w-full shrink-0 rounded-card border border-line-soft bg-surface-1 p-3 lg:sticky lg:top-6 lg:w-64">
              <div className="font-mono text-micro text-ink-3">template</div>
              <div className="mt-2 border-t border-line-soft pt-1">
                <KV k="version" v={state.versionNumber ?? '-'} />
                <KV k="last edited by" v={state.updatedBy ?? '-'} />
                <KV
                  k="at"
                  v={state.updateTime ? state.updateTime.slice(0, 19).replace('T', ' ') : '-'}
                />
                <KV k="managed keys" v={state.managed.length} />
                <KV k="other keys" v={state.foreign.length} />
              </div>

              <p className="mt-2 text-micro leading-relaxed text-ink-3">
                One template serves every app in the Firebase project, so a
                publish here rewrites the whole document. The ETag makes that a
                compare and swap: if someone edits it in the console meanwhile,
                the write is refused rather than overwriting them.
              </p>

              {theirs.length > 0 && (
                <div className="mt-2 border-t border-line-soft pt-2">
                  <div className="font-mono text-micro text-ink-3">other apps in this template</div>
                  {theirs.map((t) => (
                    <div key={t.key} className="mt-1 truncate font-mono text-micro text-ink-2">
                      {t.key}{' '}
                      <span className="text-ink-3">
                        {KNOWN_KEYS.find((k) => k.key === t.key)?.app}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </aside>
          </div>

          <div className="mt-3">
            <Card
              title="Other keys in the template"
              flush
              right={<Chip>{state.foreign.length}</Chip>}
            >
              {state.foreign.length === 0 ? (
                <p className="p-4 text-micro leading-relaxed text-ink-3">
                  None. Every key in the template is one this panel manages.
                </p>
              ) : (
                <Table
                  head={
                    <>
                      <Th>Key</Th>
                      <Th>Value</Th>
                    </>
                  }
                >
                  {state.foreign.map((f) => (
                    <Tr key={f.key}>
                      <Td mono>{f.key}</Td>
                      <Td mono dim>
                        {f.value ?? '-'}
                      </Td>
                    </Tr>
                  ))}
                </Table>
              )}
            </Card>
            <p className="mt-2 text-micro leading-relaxed text-ink-3">
              Added in the Firebase console rather than here. They are shown
              because a publish rewrites the whole template and carries them
              across untouched, so a key nobody in this panel knows about is
              still a key this panel is responsible for not losing.
            </p>
          </div>
        </>
      )}
    </Shell>
  );
}
