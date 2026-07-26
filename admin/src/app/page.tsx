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
 * PHASE C5 - the overview, and the entry point.
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
 * `readLiveIndex` reaches R2, so a missing credential or a network blip has to
 * be survivable: the overview is the page you load to find out something is
 * wrong, so it has to work while things are wrong.
 *
 * ## The catch is no longer where that happens, and this page regressed on it
 *
 * `readLiveIndex` used to THROW on a read failure and the try/catch below was
 * the only thing standing between one bad credential and a dead panel. It now
 * returns `unreachable` instead, so every other screen degrades rather than
 * dying - and this page, which had been correctly shouting "could not read the
 * bucket", quietly stopped. The catch never fired again, `error` was always
 * null, and an unreadable bucket started rendering as the `none` chip: the exact
 * same thing a fresh bucket with nothing published shows.
 *
 * So the flag is read explicitly below. The try/catch stays as a backstop for
 * `indexIsSigned` and for anything that starts throwing later.
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
    // `unreachable` rather than null: the read failing is now reported, not
    // thrown, and treating it as success turns "we cannot see the bucket" into
    // "the bucket is empty".
    return { id, live, signed, error: live.unreachable };
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

  // Not "some app failed" but "we learned nothing at all", which is when the
  // aggregate figures stop meaning anything. One app unreachable out of two
  // still gives a real number for the other.
  const blind = unreachable.length === rows.length && rows.length > 0;

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
      {/* `bad`, not `warn`. It was a warning when a failed read took the page
          down anyway and you could not miss it. Now that every screen degrades
          politely, this banner is the only thing distinguishing an empty panel
          from a blind one, and every number below it is a zero it invented. */}
      {unreachable.map((r) => (
        <Banner key={r.id} tone="bad">
          {r.id}: could not read the bucket, so every figure below is a default
          rather than a measurement. {r.error}
        </Banner>
      ))}

      <PageHead
        title="All apps"
        meta={`${MANAGED.length} managed · ${REGISTRY.length} published`}
        actions={<Button href="/apps/g-launcher/publish" variant="primary">Publish</Button>}
      />

      {/* A dash, not a zero, when the bucket did not answer. "0 packs, 0 B,
          never" beside a red banner reads as a real measurement of an empty
          store, and it is the reading that cost an afternoon: the panel looked
          like a fresh install rather than a broken credential. */}
      <Grid cols={4}>
        <Stat
          label="Packs live"
          value={blind ? '\u2014' : packs}
          sub={blind ? 'bucket unreachable' : `${paid} paid`}
          tone={blind ? 'warn' : 'plain'}
        />
        <Stat label="On the CDN" value={blind ? '\u2014' : bytes(size)} />
        <Stat label="Last publish" value={blind ? '\u2014' : when(lastPublish)} />
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
                    {meta.pkg ?? '-'}
                  </Td>
                  <Td num>{r.live?.packs.length ?? '-'}</Td>
                  <Td num>{size ? bytes(size) : '-'}</Td>
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
                  {a.pkg ?? '-'}
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
          <KV k="Key id" v={rows[0]?.live?.keyId ?? process.env.PACK_KEY_ID ?? '-'} />
          <KV
            k="Bundles"
            v={rows.reduce((n, r) => n + (r.live?.entitlements.length ?? 0), 0)}
          />
          <KV k="generatedAt" v={lastPublish || '-'} />
        </Card>
      </div>
    </Shell>
  );
}

