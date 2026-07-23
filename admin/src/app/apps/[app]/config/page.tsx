import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { KNOWN_KEYS, readRemoteConfig, type RcState } from '@/lib/remote-config';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { ConfigForm } from '@/app/components/config-form';
import { Banner, Card, Chip, KV, PageHead, Table, Td, Th, Tr } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C11 — Remote Config.
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
 * the shared-template caveat because all five apps share one Remote Config.
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

  return (
    <Shell app={app} subtitle={`${app} / remote config`}>
      {error && (
        <Banner tone="warn">
          Remote Config is not readable. Set GCP_PROJECT and grant the service
          account the Remote Config Admin role, then reload. See C11-SETUP. ({error})
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} config`}
        meta={
          state?.versionNumber
            ? `template v${state.versionNumber}`
            : undefined
        }
      />

      {state && (
        <>
          {mine.length === 0 ? (
            <Card title="No managed keys for this app">
              <p className="text-data leading-relaxed text-ink-2">
                {app} reads no Remote Config value yet. Keys appear here once the
                app grows a reader for one and it is added to the allowlist in{' '}
                <code className="font-mono text-micro">lib/remote-config.ts</code>.
              </p>
            </Card>
          ) : (
            <ConfigForm app={app} etag={state.etag} keys={mine} />
          )}

          <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-[1fr_1fr]">
            <Card title="Template" >
              <KV k="Version" v={state.versionNumber ?? '—'} />
              <KV k="Last edited by" v={state.updatedBy ?? '—'} />
              <KV
                k="At"
                v={state.updateTime ? state.updateTime.slice(0, 19).replace('T', ' ') : '—'}
              />
              <KV k="Shared across" v="all 5 apps in the project" />
            </Card>

            <Card
              title="Other keys in the template"
              flush
              right={<Chip>{state.foreign.length}</Chip>}
            >
              {state.foreign.length === 0 ? (
                <p className="p-4 text-data text-ink-3">
                  None. This panel manages every key in the template.
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
                        {f.value ?? '—'}
                      </Td>
                    </Tr>
                  ))}
                </Table>
              )}
            </Card>
          </div>
        </>
      )}
    </Shell>
  );
}
