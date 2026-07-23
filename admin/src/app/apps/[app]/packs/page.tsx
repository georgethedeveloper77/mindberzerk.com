import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { indexIsSigned, readLiveIndex } from '@/lib/catalogue';
import { isAppId, appName } from '@/lib/registry';
import { KNOWN_PACK_TYPES } from '@/lib/sign';
import { Shell } from '@/app/components/shell';
import {
  Banner,
  Button,
  Card,
  Chip,
  Empty,
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
} from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C5 — the catalogue for one app.
 *
 * ## The route moved
 *
 * This was `/`, hardcoded to g-launcher. `APPS` has always had two entries and
 * G Recovery is next, so the app is now a path segment and the page reads it.
 * `params` is a PROMISE in this version of Next; destructuring it directly is
 * the mistake that produces "params should be awaited" at runtime rather than
 * at build.
 *
 * ## One table, not two layouts
 *
 * The previous version rendered cards below `md` and a table above it, which is
 * two copies of every field and two places to forget one. The table wrapper
 * scrolls horizontally instead, so a phone scrolls the row rather than the page
 * and the pack id — the one column you actually need — stays pinned at the left
 * where it is readable.
 *
 * ## The filter costs no JavaScript
 *
 * Type filtering is a set of links that set a search param, read on the server.
 * A client-side filter would mean shipping the whole pack list to the browser to
 * hide four rows of it.
 */
export default async function PacksPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ type?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  // A bad segment is a 404, not an empty page. Without this, `/apps/nope/packs`
  // would reach R2 with an attacker-supplied prefix.
  if (!isAppId(app)) notFound();

  const { type } = await searchParams;
  const live = await readLiveIndex(app);
  const signed = live.exists ? await indexIsSigned(app) : false;

  const filtered =
    type && (KNOWN_PACK_TYPES as readonly string[]).includes(type)
      ? live.packs.filter((p) => p.packType === type)
      : live.packs;

  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);
  const paid = live.packs.filter((p) => p.sku).length;

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Publishing is blocked rather
          than overwriting it. Fix the object in the bucket before republishing.
        </Banner>
      )}
      {live.exists && !signed && (
        <Banner tone="bad">
          index.json is published without index.sig. Every device refuses it and
          keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      )}

      <PageHead
        title={`${appName(app)} packs`}
        meta={`${live.packs.length} live · updated ${when(live.generatedAt)}`}
        actions={
          <Button href={`/apps/${app}/publish`} variant="primary">
            Publish
          </Button>
        }
      />

      <Grid cols={4}>
        <Stat label="Packs" value={live.packs.length} />
        <Stat label="Size" value={bytes(size)} />
        <Stat label="Paid" value={paid} sub={`${live.packs.length - paid} free`} />
        <Stat
          label="Index"
          value={signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
          tone={signed ? 'ok' : live.exists ? 'bad' : 'plain'}
        />
      </Grid>

      <div className="mt-3 sm:mt-4">
        <Card
          title="Catalogue"
          flush
          right={
            <div className="flex gap-1">
              <FilterLink app={app} active={!type}>
                All
              </FilterLink>
              {KNOWN_PACK_TYPES.map((t) => (
                <FilterLink key={t} app={app} type={t} active={type === t}>
                  {t}
                </FilterLink>
              ))}
            </div>
          }
        >
          {filtered.length === 0 ? (
            <div className="p-4">
              <Empty action={<Button href={`/apps/${app}/publish`}>Publish a pack</Button>}>
                {live.packs.length === 0
                  ? 'Nothing published yet.'
                  : `No ${type} packs.`}
              </Empty>
            </div>
          ) : (
            <Table
              head={
                <>
                  <Th>Pack</Th>
                  <Th>Type</Th>
                  <Th num>Ver</Th>
                  <Th num>Min app</Th>
                  <Th num>Size</Th>
                  <Th>Price</Th>
                  <Th>Path</Th>
                </>
              }
            >
              {filtered.map((p) => (
                <Tr key={p.packId}>
                  <Td>
                    {/* The title is the affordance, not a trailing "view" cell:
                        the thing you want to open is the thing you point at. */}
                    <Link
                      href={`/apps/${app}/packs/${p.packId}`}
                      className="block hover:text-accent"
                    >
                      {p.title}
                    </Link>
                    <span className="block font-mono text-micro text-ink-3">{p.packId}</span>
                  </Td>
                  <Td>
                    <Chip>{p.packType}</Chip>
                  </Td>
                  {/* Pack versions are monotonic INTEGERS, not semver. The
                      device refuses anything that does not increase, so the
                      number is the whole contract. */}
                  <Td num>{p.version}</Td>
                  <Td num dim>
                    {p.minAppVersion}
                  </Td>
                  <Td num>{bytes(p.sizeBytes)}</Td>
                  <Td>
                    {p.sku ? <Chip tone="warn">{p.sku}</Chip> : <Chip tone="ok">free</Chip>}
                  </Td>
                  <Td mono dim>
                    {p.path}
                  </Td>
                </Tr>
              ))}
            </Table>
          )}
        </Card>
      </div>

      <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-[1.6fr_1fr]">
        <Card title="Bundles" flush>
          {live.entitlements.length === 0 ? (
            <div className="p-4">
              <Empty>No bundles. Every paid pack is sold on its own SKU.</Empty>
            </div>
          ) : (
            <Table
              head={
                <>
                  <Th>SKU</Th>
                  <Th>Title</Th>
                  <Th num>Grants</Th>
                </>
              }
            >
              {live.entitlements.map((e) => (
                <Tr key={e.sku}>
                  <Td mono>{e.sku}</Td>
                  <Td>{e.title}</Td>
                  <Td num>{e.grants.includes('*') ? 'everything' : e.grants.length}</Td>
                </Tr>
              ))}
            </Table>
          )}
        </Card>

        <Card title="Index">
          <KV k="generatedAt" v={live.generatedAt || '—'} />
          <KV k="Key id" v={live.keyId} />
          <KV k="Signature" v={signed ? 'present' : 'missing'} />
          <KV k="Prefix" v={`${app}/`} />
        </Card>
      </div>
    </Shell>
  );
}

function FilterLink({
  app,
  type,
  active,
  children,
}: {
  app: string;
  type?: string;
  active: boolean;
  children: React.ReactNode;
}) {
  return (
    <a
      href={type ? `/apps/${app}/packs?type=${type}` : `/apps/${app}/packs`}
      className={`rounded-md px-1.5 py-0.5 font-mono text-micro transition ${
        active ? 'bg-surface-3 text-ink' : 'text-ink-3 hover:text-ink-2'
      }`}
    >
      {children}
    </a>
  );
}
