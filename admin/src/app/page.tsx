import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { indexIsSigned, readLiveIndex } from '@/lib/catalogue';
import { Shell } from './components/shell';

export const dynamic = 'force-dynamic';

/**
 * PHASE C4 — the packs view.
 *
 * A SERVER COMPONENT, and `requireAdmin()` runs before anything renders. The
 * proxy only checked that a cookie exists; this is where it is verified.
 *
 * CARDS ON MOBILE, TABLE ON DESKTOP. Not two components — the same data, laid
 * out twice, because a five-column table on a 390px screen either scrolls
 * sideways (nobody finds the last column) or truncates (the pack id, which is
 * the one thing you need to read). Below `md` each pack is a card; above it,
 * the table earns its density back.
 */
export default async function PacksPage() {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return <NotAllowed />;
    throw e;
  }

  const app = 'g-launcher' as const;
  const live = await readLiveIndex(app);
  const signed = await indexIsSigned(app);

  return (
    <Shell subtitle={`cdn.mindberzerk.com / ${app}`}>
      {live.exists && !signed && (
        <Banner tone="bad">
          index.json is published without index.sig. Every device refuses it and
          keeps the catalogue it already had. Republish to regenerate both.
        </Banner>
      )}
      {live.corrupt && (
        <Banner tone="bad">
          index.json exists but does not parse. Publishing is blocked rather than
          overwriting it, because a bad merge would drop every pack from the
          store.
        </Banner>
      )}

      <div className="flex items-baseline justify-between">
        <h1 className="text-lg font-semibold tracking-tight">Packs</h1>
        <span className="text-sm text-neutral-500">{live.packs.length}</span>
      </div>

      {live.packs.length === 0 ? (
        <p className="mt-6 text-sm text-neutral-500">Nothing published yet.</p>
      ) : (
        <>
          {/* Mobile */}
          <ul className="mt-4 space-y-2 md:hidden">
            {live.packs.map((p) => (
              <li
                key={p.packId}
                className="rounded-xl border border-neutral-900 bg-neutral-900/40 p-3"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-medium">{p.title}</div>
                    <div className="truncate font-mono text-[11px] text-neutral-500">
                      {p.packId}
                    </div>
                  </div>
                  <span className="shrink-0 rounded-md bg-neutral-800 px-2 py-0.5 font-mono text-[11px] text-neutral-300">
                    v{p.version}
                  </span>
                </div>
                <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 font-mono text-[11px] text-neutral-500">
                  <span>{p.packType}</span>
                  <span>min app {p.minAppVersion}</span>
                  <span>{(p.sizeBytes / 1024).toFixed(0)} KB</span>
                  <span className={p.sku ? 'text-amber-400' : 'text-emerald-500'}>
                    {p.sku ?? 'free'}
                  </span>
                </div>
              </li>
            ))}
          </ul>

          {/* Desktop */}
          <table className="mt-4 hidden w-full text-sm md:table">
            <thead className="text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="pb-2 font-medium">Pack</th>
                <th className="pb-2 font-medium">Type</th>
                <th className="pb-2 font-medium">Ver</th>
                <th className="pb-2 font-medium">Min app</th>
                <th className="pb-2 font-medium">Price</th>
              </tr>
            </thead>
            <tbody className="text-neutral-300">
              {live.packs.map((p) => (
                <tr key={p.packId} className="border-t border-neutral-900">
                  <td className="py-2.5">
                    <div>{p.title}</div>
                    <div className="font-mono text-xs text-neutral-500">{p.packId}</div>
                  </td>
                  <td className="py-2.5 text-neutral-400">{p.packType}</td>
                  <td className="py-2.5 font-mono">{p.version}</td>
                  <td className="py-2.5 font-mono text-neutral-400">{p.minAppVersion}</td>
                  <td className={`py-2.5 font-mono text-xs ${p.sku ? 'text-amber-400' : 'text-emerald-500'}`}>
                    {p.sku ?? 'free'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      <p className="mt-4 font-mono text-[11px] leading-relaxed text-neutral-600">
        generatedAt {live.generatedAt || '—'}
        <br />
        key {live.keyId} · {live.entitlements.length} bundle
        {live.entitlements.length === 1 ? '' : 's'}
      </p>
    </Shell>
  );
}

function Banner({ children, tone }: { children: React.ReactNode; tone: 'bad' }) {
  return (
    <p
      className={`mb-5 rounded-xl border px-3 py-2.5 text-sm leading-relaxed ${
        tone === 'bad'
          ? 'border-red-900/60 bg-red-950/40 text-red-300'
          : 'border-neutral-800 bg-neutral-900 text-neutral-300'
      }`}
    >
      {children}
    </p>
  );
}

function NotAllowed() {
  return (
    <main className="flex min-h-[100dvh] items-center justify-center p-6">
      <div className="max-w-sm text-sm leading-relaxed text-neutral-400">
        <p className="text-neutral-100">Not authorised.</p>
        <p className="mt-2">
          Your Google sign-in worked; your Firebase UID is not on the allowlist.
          Add it to the <code className="font-mono">admin-uids</code> secret and
          redeploy.
        </p>
      </div>
    </main>
  );
}
