import { adminGate } from '@/app/components/admin-gate';
import { indexIsSigned, readLiveIndex, type LiveIndex } from '@/lib/catalogue';
import { MANAGED, REGISTRY, type AppId } from '@/lib/registry';
import { Shell } from './components/shell';
import {
  Banner,
  Button,
  Card,
  Chip,
  Grid,
  KV,
  PageHead,
  Stat,
  Table,
  Td,
  Th,
  Tr,
  bytes,
  when,
} from './components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C5 — the overview, and the entry point.
 *
 * ## Every number here is read from the bucket
 *
 * There are no installs, no DAU, no revenue. Firebase Analytics is aggregated
 * and sampled in the console and has no per-user drill-down, so anything of that
 * shape has to come from the BigQuery export, which is not wired. A dashboard
 * that shows a plausible number it did not measure is worse than one that shows
 * nothing, because you stop checking the source.
 *
 * What this screen does answer: what is published, is it signed, how big is it,
 * and when did it last change. That is the question you actually open the panel
 * with.
 *
 * ## Reading both apps must not let one break the other
 *
 * `readLiveIndex` reaches R2, so a missing credential or a network blip throws.
 * Each app is read inside its own catch and renders as `unreachable` rather than
 * taking the whole page down — the overview is the page you load to find out
 * something is wrong, so it has to survive things being wrong.
 */

interface AppRow {
  id: AppId;
  live: LiveIndex | null;
  signed: boolean;
  error: string | null;
}

async function readApp(id: AppId): Promise<AppRow> {
  try {
    const live = await readLiveIndex(id);
    // Only ask about the signature when there is an index to sign. A bucket with
    // no index for an app that has not shipped is the normal case, not a fault.
    const signed = live.exists ? await indexIsSigned(id) : false;
    return { id, live, signed, error: null };
  } catch (e) {
    return { id, live: null, signed: false, error: (e as Error).message };
  }
}

export default async function OverviewPage() {
  const gate = await adminGate();
  if (gate) return gate;

  const rows = await Promise.all(MANAGED.map((a) => readApp(a.id as AppId)));

  const packs = rows.reduce((n, r) => n + (r.live?.packs.length ?? 0), 0);
  const size = rows.reduce(
    (n, r) => n + (r.live?.packs.reduce((m, p) => m + p.sizeBytes, 0) ?? 0),
    0,
  );
  const lastPublish = Math.max(0, ...rows.map((r) => r.live?.generatedAt ?? 0));
  const paid = rows.reduce(
    (n, r) => n + (r.live?.packs.filter((p) => p.sku).length ?? 0),
    0,
  );

  const unsigned = rows.filter((r) => r.live?.exists && !r.signed);
  const corrupt = rows.filter((r) => r.live?.corrupt);
  const unreachable = rows.filter((r) => r.error);

  return (
    <Shell>
      {corrupt.map((r) => (
        <Banner key={r.id} tone="bad">
          {r.id}: index.json is present but does not parse. Publishing is blocked
          rather than overwriting it, because a bad merge drops every pack from
          the store.
        </Banner>
      ))}
      {unsigned.map((r) => (
        <Banner key={r.id} tone="bad">
          {r.id}: index.json is published without index.sig. Every device refuses
          it and keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      ))}
      {unreachable.map((r) => (
        <Banner key={r.id} tone="warn">
          {r.id}: could not read the bucket. {r.error}
        </Banner>
      ))}

      <PageHead
        title="All apps"
        meta={`${MANAGED.length} managed · ${REGISTRY.length} published`}
        actions={<Button href="/apps/g-launcher/publish" variant="primary">Publish</Button>}
      />

      <Grid cols={4}>
        <Stat label="Packs live" value={packs} sub={`${paid} paid`} />
        <Stat label="On the CDN" value={bytes(size)} />
        <Stat label="Last publish" value={when(lastPublish)} />
        <Stat
          label="Index signed"
          value={`${rows.filter((r) => r.signed).length}/${rows.filter((r) => r.live?.exists).length || 0}`}
          tone={unsigned.length ? 'bad' : 'ok'}
        />
      </Grid>

      <div className="mt-3 sm:mt-4">
        <Card title="Managed here" flush>
          <Table
            head={
              <>
                <Th>App</Th>
                <Th>Package</Th>
                <Th num>Packs</Th>
                <Th num>Size</Th>
                <Th>Index</Th>
                <Th>Updated</Th>
                <Th />
              </>
            }
          >
            {rows.map((r) => {
              const meta = REGISTRY.find((a) => a.id === r.id)!;
              const size = r.live?.packs.reduce((m, p) => m + p.sizeBytes, 0) ?? 0;
              return (
                <Tr key={r.id}>
                  <Td>
                    <span className="flex items-center gap-2">
                      <span
                        className="grid size-5 shrink-0 place-items-center rounded font-mono text-micro font-bold text-surface-0"
                        style={{ background: meta.tint }}
                      >
                        {meta.mark}
                      </span>
                      {meta.name}
                    </span>
                  </Td>
                  <Td mono dim>
                    {meta.pkg ?? '—'}
                  </Td>
                  <Td num>{r.live?.packs.length ?? '—'}</Td>
                  <Td num>{size ? bytes(size) : '—'}</Td>
                  <Td>
                    {r.error ? (
                      <Chip tone="warn">unreachable</Chip>
                    ) : r.live?.corrupt ? (
                      <Chip tone="bad">corrupt</Chip>
                    ) : !r.live?.exists ? (
                      <Chip>none</Chip>
                    ) : r.signed ? (
                      <Chip tone="ok">signed</Chip>
                    ) : (
                      <Chip tone="bad">unsigned</Chip>
                    )}
                  </Td>
                  <Td mono dim>
                    {when(r.live?.generatedAt ?? 0)}
                  </Td>
                  <Td num>
                    <Button href={`/apps/${r.id}/packs`}>Open</Button>
                  </Td>
                </Tr>
              );
            })}
          </Table>
        </Card>
      </div>

      <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-[1.6fr_1fr]">
        <Card title="Published, administered elsewhere" flush>
          <Table
            head={
              <>
                <Th>App</Th>
                <Th>Package</Th>
                <Th>State</Th>
                <Th>Firebase</Th>
              </>
            }
          >
            {REGISTRY.filter((a) => !a.managed).map((a) => (
              <Tr key={a.id}>
                <Td>{a.name}</Td>
                <Td mono dim>
                  {a.pkg ?? '—'}
                </Td>
                <Td>
                  <Chip tone={a.state === 'live' ? 'ok' : a.state === 'planned' ? 'plain' : 'info'}>
                    {a.state}
                  </Chip>
                </Td>
                <Td mono dim>
                  {a.state === 'external' ? 'own project' : 'mindhunter'}
                </Td>
              </Tr>
            ))}
          </Table>
        </Card>

        <Card title="Signing and delivery">
          <KV k="Bucket" v={process.env.R2_BUCKET ?? 'mindberzerk-cdn'} />
          <KV k="Key id" v={rows[0]?.live?.keyId ?? process.env.PACK_KEY_ID ?? '—'} />
          <KV
            k="Bundles"
            v={rows.reduce((n, r) => n + (r.live?.entitlements.length ?? 0), 0)}
          />
          <KV k="generatedAt" v={lastPublish || '—'} />
        </Card>
      </div>
    </Shell>
  );
}

