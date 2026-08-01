import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/core/catalogue';
import { hasSignature, readManifest, readPackJson } from '@/lib/core/pack-content';
import { appName, isAppId } from '@/lib/core/registry';
import { absolutePaths, parseTheme, toCss } from '@/lib/g-launcher/theme-resolve';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { Shell } from '@/app/components/shell';
import { UnpublishButton } from '@/app/components/unpublish-button';
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
} from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C5 - what is actually inside a published pack.
 *
 * ## Why this exists before the builder
 *
 * The theme builder is blocked: a bundled theme and a downloaded one cannot
 * share a file format until every asset path is relative to the pack root. This
 * page is the half that is not blocked, and it is the half worth having first -
 * it reads a pack back out of the bucket and reports what the launcher's parser
 * WILL DO with it, including every fallback it takes silently.
 *
 * `ThemeSpec.fromJson` never throws. A misspelled key, an unknown shell, an
 * `iconScale` of 3.0 and a perfect file all produce a working theme, which means
 * the only way to know a field landed is to check. That is this page.
 *
 * ## Everything here is a read
 *
 * Objects under a versioned path are immutable, so there is nothing to
 * invalidate and no way for this page to disagree with a device.
 */
export default async function PackPage({
  params,
}: {
  params: Promise<{ app: string; packId: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app, packId } = await params;
  if (!isAppId(app)) notFound();

  const live = await readLiveIndex(app);
  const pack = live.packs.find((p) => p.packId === packId);
  if (!pack) notFound();

  const [manifest, signed] = await Promise.all([
    readManifest(app, pack.path),
    hasSignature(app, pack.path),
  ]);

  // Themes carry theme.json; the icon families carry pack.json. Reading the
  // wrong one is a 404 against R2, which returns null, so this is safe either
  // way and the page just shows the file list.
  const isTheme = pack.packType === 'theme';
  const file = await readPackJson(app, pack.path, isTheme ? 'theme.json' : 'pack.json');

  const parsed = isTheme && file?.data ? parseTheme(file.data) : null;
  const theme = parsed && !('error' in parsed) ? parsed : null;

  const manifestPaths = new Set(manifest?.files.map((f) => f.path) ?? []);
  const missing = theme ? theme.assets.filter((a) => !manifestPaths.has(a)) : [];
  const absolute = theme ? absolutePaths(theme.assets) : [];

  const errors = theme?.notes.filter((n) => n.level === 'error') ?? [];
  const degraded = theme?.notes.filter((n) => n.level === 'degraded') ?? [];
  const defaults = theme?.notes.filter((n) => n.level === 'default') ?? [];
  const lints = theme?.notes.filter((n) => n.level === 'lint') ?? [];

  return (
    <Shell app={app} subtitle={`${app} / ${pack.path}`}>
      <Breadcrumb
        items={[
          { label: appName(app), href: `/apps/${app}/packs` },
          { label: 'Packs', href: `/apps/${app}/packs` },
          { label: pack.packId },
        ]}
      />

      {!manifest && (
        <Banner tone="bad">
          No manifest.json at this path. The index advertises the pack, so every
          device that reads it will try to install and find nothing. Republish.
        </Banner>
      )}
      {manifest && !signed && (
        <Banner tone="bad">
          manifest.json is present without manifest.sig. Verification fails as
          MissingSignature and the pack is refused. Republish to regenerate both.
        </Banner>
      )}
      {parsed && 'error' in parsed && (
        <Banner tone="bad">theme.json did not parse: {parsed.error}</Banner>
      )}
      {missing.length > 0 && (
        <Banner tone="bad">
          {missing.length === 1 ? 'An asset is' : `${missing.length} assets are`}{' '}
          referenced by theme.json and not in the manifest, so the file is not in
          the pack: {missing.join(', ')}
        </Banner>
      )}
      {absolute.length > 0 && (
        <Banner tone="warn">
          {absolute.length} asset {absolute.length === 1 ? 'path is' : 'paths are'}{' '}
          absolute. Those resolve through the Flutter asset bundle when the theme
          is bundled and against nothing once it is downloaded.
        </Banner>
      )}

      <PageHead
        title={pack.title}
        meta={`${pack.packId} · v${pack.version}`}
        actions={
          <>
            <Button href={`/apps/${app}/packs`}>Back to packs</Button>
            <UnpublishButton app={app} packId={pack.packId} />
          </>
        }
      />

      <Grid cols={4}>
        <Stat label="Version" value={pack.version} sub={`min app ${pack.minAppVersion}`} />
        <Stat label="Files" value={manifest?.files.length ?? '-'} sub={bytes(pack.sizeBytes)} />
        <Stat
          label="Signature"
          value={signed ? 'valid' : 'missing'}
          tone={signed ? 'ok' : 'bad'}
          sub={manifest?.keyId}
        />
        <Stat
          label="Parser notes"
          value={degraded.length + defaults.length + lints.length}
          tone={degraded.length ? 'warn' : 'plain'}
          sub={`${degraded.length} degraded`}
        />
      </Grid>

      {theme && (
        <>
          <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-[1fr_1fr]">
            <Card title="Resolved">
              <KV k="Shell" v={theme.shell} />
              <KV k="Chrome" v={theme.chromeFamily} />
              <KV k="Tier" v={theme.tier} />
              {/* theme.json's `version` is a DISPLAY string like "24.04". The
                  pack version above is the monotonic integer the device
                  compares. Two different things with one name. */}
              <KV k="Distro version" v={theme.version || '-'} />
              <KV k="Dock" v={`${theme.layout.dock}${theme.layout.topBar ? ' + top bar' : ''}`} />
              <KV k="Grid" v={`${theme.layout.cols} x ${theme.layout.rows}`} />
              <KV k="Icon scale" v={theme.layout.iconScale.toFixed(2)} />
              <KV k="Fonts" v={`${theme.typography.display ?? '-'} / ${theme.typography.mono ?? '-'}`} />
              <KV k="Wallpapers" v={theme.wallpapers.length} />
              <KV k="Desklets" v={`${theme.desklets.starter.length} placed, ${theme.desklets.offers.length} offered`} />
            </Card>

            <div className="grid gap-3">
              <Card title="Palette">
                <div className="flex flex-wrap gap-2">
                  {Object.entries(theme.palette).map(([key, value]) => (
                    <div key={key} className="w-[calc(33.333%-0.34rem)]">
                      <div
                        className="h-9 rounded-md border border-line"
                        style={{ background: toCss(value) }}
                      />
                      <div className="mt-1 text-micro text-ink-3">{key}</div>
                      <div className="font-mono text-micro text-ink-2">{value}</div>
                    </div>
                  ))}
                </div>
              </Card>

              <Card title="Icon recipe">
                <KV k="Treatment" v={theme.icons.treatment} />
                <KV k="Corner radius" v={theme.icons.cornerRadius} />
                <KV k="Foreground scale" v={theme.icons.foregroundScale} />
                <KV
                  k="Plate"
                  v={
                    theme.icons.backgroundColor
                      ? theme.icons.backgroundGradientEnd
                        ? `${theme.icons.backgroundColor} to ${theme.icons.backgroundGradientEnd} at ${theme.icons.gradientAngle ?? 0}°`
                        : theme.icons.backgroundColor
                      : "the app's own"
                  }
                />
                <KV k="Hero pack" v={theme.icons.heroPack ?? '-'} />
                <KV k="Brand pack" v={theme.icons.brandPack ?? '-'} />
                <KV k="Brand treatment" v={theme.icons.brandTreatment ?? '-'} />
                <KV k="Monochrome tint" v={theme.icons.monochromeTint ?? '-'} />
              </Card>
            </div>
          </div>

          {theme.boot && (
            <div className="mt-3 sm:mt-4">
              <Card
                title="Boot log"
                right={
                  <Chip>
                    {theme.boot.lines.length} lines · tail {theme.boot.tailMs}ms
                  </Chip>
                }
              >
                {/* Rendered on the theme's own bottom colour, because that is
                    what the canvas uses on device: the log is tinted per distro
                    without a separate field for it. */}
                <div
                  className="max-h-64 overflow-y-auto rounded-md border border-line p-2.5 font-mono text-micro leading-relaxed"
                  style={{ background: toCss(theme.palette.bgBottom) }}
                >
                  {theme.boot.lines.map((l, i) => (
                    <div key={i} className={bootClass(l.kind)}>
                      {l.kind === 'blank' ? '\u00A0' : null}
                      {l.kind === 'ok' && <span className="text-ok">[ OK ] </span>}
                      {l.kind === 'warn' && <span className="text-warn">[ .. ] </span>}
                      {l.kind === 'fail' && <span className="text-bad">[FAIL] </span>}
                      {l.kind === 'grubSelected' && <span className="text-accent">&gt; </span>}
                      {l.text}
                    </div>
                  ))}
                </div>
              </Card>
            </div>
          )}

          {theme.notes.length > 0 && (
            <div className="mt-3 sm:mt-4">
              <Card
                title="What the parser did"
                flush
                right={
                  <>
                    {degraded.length > 0 && <Chip tone="warn">{degraded.length} degraded</Chip>}
                    {lints.length > 0 && <Chip tone="info">{lints.length} lint</Chip>}
                    {defaults.length > 0 && <Chip>{defaults.length} default</Chip>}
                  </>
                }
              >
                <Table
                  head={
                    <>
                      <Th>Level</Th>
                      <Th>Field</Th>
                      <Th>What happens</Th>
                    </>
                  }
                >
                  {[...errors, ...degraded, ...lints, ...defaults].map((n, i) => (
                    <Tr key={`${n.path}-${i}`}>
                      <Td>
                        <Chip
                          tone={
                            n.level === 'error'
                              ? 'bad'
                              : n.level === 'degraded'
                                ? 'warn'
                                : n.level === 'lint'
                                  ? 'info'
                                  : 'plain'
                          }
                        >
                          {n.level}
                        </Chip>
                      </Td>
                      <Td mono>{n.path}</Td>
                      <Td dim>{n.message}</Td>
                    </Tr>
                  ))}
                </Table>
              </Card>
            </div>
          )}
        </>
      )}

      <div className="mt-3 sm:mt-4">
        <Card
          title="Files"
          flush
          right={<Chip>{manifest?.files.length ?? 0} in manifest</Chip>}
        >
          {!manifest ? (
            <p className="p-4 text-data text-ink-3">No manifest to list.</p>
          ) : (
            <Table
              head={
                <>
                  <Th>Path</Th>
                  <Th num>Size</Th>
                  <Th>sha256</Th>
                </>
              }
            >
              {manifest.files.map((f) => (
                <Tr key={f.path}>
                  <Td mono>{f.path}</Td>
                  <Td num>{bytes(f.size)}</Td>
                  <Td mono dim>
                    {f.sha256.slice(0, 12)}
                  </Td>
                </Tr>
              ))}
            </Table>
          )}
        </Card>
      </div>

      {file?.raw && (
        <div className="mt-3 sm:mt-4">
          <Card title={isTheme ? 'theme.json' : 'pack.json'} flush>
            {/* The bytes as uploaded. Never re-stringified: the signature covers
                exactly these, so pretty-printing here would show a file that
                does not match what was signed. */}
            <pre className="max-h-96 overflow-auto p-3 font-mono text-micro leading-relaxed text-ink-2 sm:p-4">
              {file.raw}
            </pre>
          </Card>
        </div>
      )}
    </Shell>
  );
}

function bootClass(kind: string): string {
  switch (kind) {
    case 'dim':
      return 'text-ink-3';
    case 'grub':
      return 'text-ink-2';
    case 'grubSelected':
      return 'text-ink';
    case 'fail':
      return 'text-bad';
    default:
      return 'text-ink-2';
  }
}
