import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SlabCell, SoftPanel } from '@/components/studio/ui';
import { UnpublishButton } from '@/app/components/unpublish-button';
import { bytes } from '@/app/components/ui';
import { readLiveIndex } from '@/lib/core/catalogue';
import { hasSignature, readManifest, readPackJson } from '@/lib/core/pack-content';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { absolutePaths, parseTheme, toCss } from '@/lib/g-launcher/theme-resolve';

export const dynamic = 'force-dynamic';

/**
 * PHASE C5 - what is actually inside a published pack.
 *
 * ## Why this page is worth having
 *
 * `ThemeSpec.fromJson` NEVER THROWS. A misspelled key, an unknown shell, an
 * `iconScale` of 3.0 and a perfect file all produce a working theme, so the
 * only way to know a field landed is to check. That is this page: it reads a
 * pack back out of the bucket and reports what the launcher's parser WILL DO
 * with it, including every fallback it takes silently.
 *
 * ## Everything here is a read
 *
 * Objects under a versioned path are immutable, so there is nothing to
 * invalidate and no way for this page to disagree with a device.
 *
 * ## The four figures moved into the slab
 *
 * Version, files, signature and parser notes were stat cards under the header.
 * They are the header now, matching every other per-app screen, and the
 * signature reads `missing` in the alarm colour rather than as a neutral word,
 * because an unsigned pack is refused by every device that reads it.
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

  const meta = appMeta(app);
  const bad = 'rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan';

  return (
    <StudioShell app={app}>
      {!manifest && (
        <p className={bad}>
          No manifest.json at this path. The index advertises the pack, so every device that reads
          it will try to install and find nothing. Republish.
        </p>
      )}
      {manifest && !signed && (
        <p className={bad}>
          manifest.json is present without manifest.sig. Verification fails as MissingSignature and
          the pack is refused. Republish to regenerate both.
        </p>
      )}
      {parsed && 'error' in parsed && <p className={bad}>theme.json did not parse: {parsed.error}</p>}
      {missing.length > 0 && (
        <p className={bad}>
          {missing.length === 1 ? 'An asset is' : `${missing.length} assets are`} referenced by
          theme.json and not in the manifest, so the file is not in the pack: {missing.join(', ')}
        </p>
      )}
      {absolute.length > 0 && (
        <p className={bad}>
          {absolute.length} asset {absolute.length === 1 ? 'path is' : 'paths are'} absolute. Those
          resolve through the Flutter asset bundle when the theme is bundled and against nothing
          once it is downloaded.
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={`${appName(app)} / CDN objects`}
        title={pack.title || pack.packId}
        meta={
          <span className="font-mono">
            {app}/{pack.path}
          </span>
        }
        actions={
          <>
            <SlabButton href={`/apps/${app}/packs?sel=${pack.packId}`}>Back to objects</SlabButton>
            <div className="[&_button]:!border-white/20 [&_button]:!bg-white/10 [&_button]:!text-[#f4f0fb]">
              <UnpublishButton app={app} packId={pack.packId} />
            </div>
          </>
        }
        metrics={
          <>
            <SlabCell
              label="Version"
              value={pack.version}
              note={`min app ${pack.minAppVersion}`}
            />
            <SlabCell
              label="Files"
              value={manifest?.files.length ?? 'unknown'}
              measured={!!manifest}
              note={bytes(pack.sizeBytes)}
            />
            <SlabCell
              label="Signature"
              value={signed ? 'valid' : 'missing'}
              measured={false}
              note={manifest?.keyId ?? 'no manifest'}
            />
            <SlabCell
              label="Parser notes"
              value={degraded.length + defaults.length + lints.length}
              note={`${degraded.length} degraded`}
            />
          </>
        }
      />

      {theme && (
        <>
          <div className="grid gap-4 lg:grid-cols-2">
            <SoftPanel title="Resolved" note="what the launcher's parser produced">
              <KVRow k="shell" v={<span className="font-mono">{theme.shell}</span>} />
              <KVRow k="chrome" v={<span className="font-mono">{theme.chromeFamily}</span>} />
              <KVRow k="tier" v={<span className="font-mono">{theme.tier}</span>} />
              {/* theme.json's `version` is a DISPLAY string like "24.04". The
                  pack version in the slab is the monotonic integer the device
                  compares. Two different things with one name. */}
              <KVRow k="distro version" v={<span className="font-mono">{theme.version || '-'}</span>} />
              <KVRow
                k="dock"
                v={
                  <span className="font-mono">
                    {theme.layout.dock}
                    {theme.layout.topBar ? ' + top bar' : ''}
                  </span>
                }
              />
              <KVRow
                k="grid"
                v={<span className="font-mono">{`${theme.layout.cols} x ${theme.layout.rows}`}</span>}
              />
              <KVRow k="icon scale" v={<span className="font-mono">{theme.layout.iconScale.toFixed(2)}</span>} />
              <KVRow
                k="fonts"
                v={
                  <span className="font-mono">
                    {theme.typography.display ?? '-'} / {theme.typography.mono ?? '-'}
                  </span>
                }
              />
              <KVRow k="wallpapers" v={theme.wallpapers.length} />
              <KVRow
                k="desklets"
                v={`${theme.desklets.starter.length} placed, ${theme.desklets.offers.length} offered`}
              />
            </SoftPanel>

            <div className="flex flex-col gap-4">
              <SoftPanel title="Palette">
                <div className="grid grid-cols-3 gap-2.5">
                  {Object.entries(theme.palette).map(([key, value]) => (
                    <div key={key}>
                      <div
                        className="h-11 rounded-lg border border-site-line"
                        style={{ background: toCss(value) }}
                      />
                      <div className="mt-1.5 text-[11px] text-site-ink-3">{key}</div>
                      <div className="truncate font-mono text-[10.5px] text-site-ink-2">{value}</div>
                    </div>
                  ))}
                </div>
              </SoftPanel>

              <SoftPanel title="Icon recipe">
                <KVRow k="treatment" v={<span className="font-mono">{theme.icons.treatment}</span>} />
                <KVRow k="corner radius" v={<span className="font-mono">{theme.icons.cornerRadius}</span>} />
                <KVRow k="foreground scale" v={<span className="font-mono">{theme.icons.foregroundScale}</span>} />
                <KVRow
                  k="plate"
                  v={
                    <span className="font-mono">
                      {theme.icons.backgroundColor
                        ? theme.icons.backgroundGradientEnd
                          ? `${theme.icons.backgroundColor} to ${theme.icons.backgroundGradientEnd} at ${theme.icons.gradientAngle ?? 0} deg`
                          : theme.icons.backgroundColor
                        : "the app's own"}
                    </span>
                  }
                />
                <KVRow k="hero pack" v={<span className="font-mono">{theme.icons.heroPack ?? '-'}</span>} />
                <KVRow k="brand pack" v={<span className="font-mono">{theme.icons.brandPack ?? '-'}</span>} />
                <KVRow k="brand treatment" v={<span className="font-mono">{theme.icons.brandTreatment ?? '-'}</span>} />
                <KVRow k="monochrome tint" v={<span className="font-mono">{theme.icons.monochromeTint ?? '-'}</span>} />
              </SoftPanel>
            </div>
          </div>

          {theme.boot && (
            <SoftPanel
              title="Boot log"
              right={
                <span className="font-mono text-[11.5px] text-site-ink-3">
                  {theme.boot.lines.length} lines, tail {theme.boot.tailMs}ms
                </span>
              }
            >
              {/* Rendered on the theme's own bottom colour, because that is what
                  the canvas uses on device: the log is tinted per distro without
                  a separate field for it. The text colours below are LITERALS
                  for the same reason, since they sit on that colour rather than
                  on the panel. */}
              <div
                className="max-h-72 overflow-y-auto rounded-xl border border-site-line p-3 font-mono text-[11.5px] leading-relaxed"
                style={{ background: toCss(theme.palette.bgBottom) }}
              >
                {theme.boot.lines.map((l, i) => (
                  <div key={i} style={{ color: bootColour(l.kind) }}>
                    {l.kind === 'blank' ? '\u00A0' : null}
                    {l.kind === 'ok' && <span style={{ color: '#5ee0a8' }}>[ OK ] </span>}
                    {l.kind === 'warn' && <span style={{ color: '#ffb27a' }}>[ .. ] </span>}
                    {l.kind === 'fail' && <span style={{ color: '#ff8b83' }}>[FAIL] </span>}
                    {l.kind === 'grubSelected' && <span style={{ color: '#c3b2ff' }}>&gt; </span>}
                    {l.text}
                  </div>
                ))}
              </div>
            </SoftPanel>
          )}

          {theme.notes.length > 0 && (
            <SoftPanel
              title="What the parser did"
              note="every fallback it took, including the silent ones"
              right={
                <span className="font-mono text-[11.5px] text-site-ink-3">
                  {degraded.length} degraded, {lints.length} lint, {defaults.length} default
                </span>
              }
              flush
            >
              {[...errors, ...degraded, ...lints, ...defaults].map((n, i) => (
                <div
                  key={`${n.path}-${i}`}
                  className="flex flex-wrap items-baseline gap-x-3 gap-y-1 border-t border-site-line px-[18px] py-2.5 first:border-t-0"
                >
                  <span
                    className={`w-[68px] shrink-0 rounded-full px-2 py-[2.5px] text-center text-[9.5px] font-bold uppercase tracking-[0.05em] ${
                      n.level === 'error' || n.level === 'degraded'
                        ? 'bg-site-plan-soft text-site-plan'
                        : n.level === 'lint'
                          ? 'bg-site-info-soft text-site-info'
                          : 'bg-site-sunk text-site-ink-3'
                    }`}
                  >
                    {n.level}
                  </span>
                  <span className="w-[180px] shrink-0 truncate font-mono text-[11.5px] text-site-ink">
                    {n.path}
                  </span>
                  <span className="min-w-[200px] flex-1 text-[12px] leading-relaxed text-site-ink-3">
                    {n.message}
                  </span>
                </div>
              ))}
            </SoftPanel>
          )}
        </>
      )}

      <SoftPanel
        title="Files"
        note="every byte the signature covers"
        right={
          <span className="font-mono text-[11.5px] text-site-ink-3">
            {manifest?.files.length ?? 0} in manifest
          </span>
        }
        flush
      >
        {!manifest ? (
          <p className="px-[18px] py-8 text-center text-[13px] text-site-ink-3">
            No manifest to list.
          </p>
        ) : (
          manifest.files.map((f) => (
            <div
              key={f.path}
              className="flex items-center gap-3 border-t border-site-line px-[18px] py-2 first:border-t-0"
            >
              <span className="min-w-0 flex-1 truncate font-mono text-[11.5px] text-site-ink">
                {f.path}
              </span>
              <span className="w-[70px] shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">
                {bytes(f.size)}
              </span>
              <span className="w-[100px] shrink-0 truncate text-right font-mono text-[11px] text-site-ink-3">
                {f.sha256.slice(0, 12)}
              </span>
            </div>
          ))
        )}
      </SoftPanel>

      {file?.raw && (
        <SoftPanel title={isTheme ? 'theme.json' : 'pack.json'} note="the bytes as uploaded" flush>
          {/* NEVER RE-STRINGIFIED: the signature covers exactly these bytes, so
              pretty-printing here would show a file that does not match what was
              signed. */}
          <pre className="max-h-96 overflow-auto px-[18px] py-3.5 font-mono text-[11.5px] leading-relaxed text-site-ink-2">
            {file.raw}
          </pre>
        </SoftPanel>
      )}
    </StudioShell>
  );
}

/**
 * Boot-log line colours.
 *
 * LITERALS, not tokens, and deliberately: these sit on the theme's own
 * `bgBottom` rather than on a panel surface, so a token that flips with the
 * panel's light and dark mode would be the wrong colour half the time.
 */
function bootColour(kind: string): string {
  switch (kind) {
    case 'dim':
      return 'rgba(255,255,255,0.42)';
    case 'grubSelected':
      return '#ffffff';
    case 'fail':
      return '#ff8b83';
    default:
      return 'rgba(255,255,255,0.78)';
  }
}
