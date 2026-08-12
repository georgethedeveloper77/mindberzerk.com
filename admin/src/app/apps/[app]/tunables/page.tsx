import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import {
  AppSlab,
  Cond,
  Ribbon,
  SlabButton,
  SlabCell,
  SoftPanel,
} from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import {
  READ_BY_APP,
  TUNABLES,
  defaultTunables,
} from '@/lib/g-recovery/content-packs';
import { readPublishedContent } from '@/lib/g-recovery/content-read';

export const dynamic = 'force-dynamic';

/**
 * THE NUMBERS THE APP COMPILES TODAY.
 *
 * ─── WHY THIS SCREEN EXISTS ──────────────────────────────────────────────────
 *
 * Six thresholds decide what the app OFFERS: which clips are worth re-encoding,
 * which files are large enough to bother with, where the line between soft and
 * sharp falls. None of them can destroy anything, and all of them currently
 * need a Play release to change.
 *
 * Two are already known wrong. The video bitrate floor refuses screen
 * recordings, which are flat content and compress well at a low bitrate. The
 * image size floor disagreed with itself across two call sites for a day, so a
 * card reported a clip and the list it opened showed nothing.
 *
 * ─── AND WHY THE REASONING IS ON THE PAGE ────────────────────────────────────
 *
 * Every help line here is currently a comment in Kotlin. That is the wrong
 * place for it: the person who needs to know what a number guards is the person
 * about to change it, and they are here rather than in VideoCompressor.
 *
 * ─── READ ONLY UNTIL THE APP READS IT ────────────────────────────────────────
 *
 * No shipped build asks for this pack, so publishing would change nothing on
 * any device. The screen says so and the publish action is absent rather than
 * present and inert: a button that does nothing teaches people the panel is
 * broken.
 */
export default async function TunablesPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  if (app !== 'g-recovery') notFound();

  // ─── THREE OUTCOMES, NOT TWO ────────────────────────────────────────────
  //
  // readPublishedContent separates "nothing published" from "the index could
  // not be read", and the difference matters here as much as anywhere:
  // starting an editor from defaults because a token expired, then publishing,
  // is how a whole registry gets replaced by one document.
  const published = await readPublishedContent('tunables');
  const live = published.document as Record<string, number> | null;
  const values = live ?? defaultTunables();
  const readable = READ_BY_APP.has('tunables');
  const meta = appMeta(app);

  const groups = Array.from(new Set(Object.values(TUNABLES).map((t) => t.group)));

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Tunables"
        meta={
          published.version > 0
            ? `registries/tunables, live at v${published.version}`
            : 'not published'
        }
        actions={<SlabButton href={`/apps/${app}/packs`}>CDN objects</SlabButton>}
        metrics={
          <>
            <SlabCell label="Values" value={Object.keys(TUNABLES).length} />
            <SlabCell
              label="Live pack"
              value={published.version > 0 ? `v${published.version}` : 'v0'}
              note={published.version > 0 ? undefined : 'nothing published'}
              measured={published.version > 0}
            />
            <SlabCell
              label="Read by the app"
              value={readable ? 'yes' : 'no'}
              note={readable ? undefined : 'ContentStore does not ask for it'}
              measured={readable}
            />
            <SlabCell
              label="Source"
              value={live ? 'published' : 'compiled'}
              note={live ? undefined : 'values below are the binary defaults'}
              measured={Boolean(live)}
            />
          </>
        }
      >
        <Ribbon>
          {published.unreachable ? (
            <Cond tone="bad">The live index could not be read</Cond>
          ) : readable ? (
            <Cond tone="ok">Publishing reaches devices</Cond>
          ) : (
            <Cond tone="warn">No shipped build reads this pack</Cond>
          )}
          <Cond tone="ok">Nothing here can delete a file</Cond>
        </Ribbon>
      </AppSlab>

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          Six numbers that decide what the app offers, never what it does to a
          file. The worst a wrong value can do is show something not worth
          acting on, or hide something that was. Every one of them needs a Play
          release to change today, and two are already suspect: the video
          bitrate floor refuses screen recordings, and the image size floor
          disagreed with itself across two call sites until it was made shared.
        </p>
      </div>

      {published.unreachable && (
        <p className="rounded-[14px] border border-site-bad/35 bg-site-bad-soft px-4 py-3 text-[12.5px] leading-relaxed text-site-bad">
          The live index could not be read: {published.unreachable}. The values
          below are the compiled defaults rather than what is published, so
          nothing should be published from here until that resolves.
        </p>
      )}

      {!readable && !published.unreachable && (
        <p className="rounded-[14px] border border-site-plan/35 bg-site-peach px-4 py-3 text-[12.5px] leading-relaxed text-site-plan">
          No shipped build reads <code className="font-mono">tunables</code>.
          The app compiles these values, so publishing would change nothing on
          any device. Add the id to{' '}
          <code className="font-mono">ContentStore</code> and read it in{' '}
          <code className="font-mono">VideoCompressor</code> and{' '}
          <code className="font-mono">ImageCompressor</code>, and this page
          starts mattering.
        </p>
      )}

      {groups.map((group) => (
        <SoftPanel key={group} title={group} note={noteFor(group)}>
          <div className="flex flex-col gap-3">
            {Object.entries(TUNABLES)
              .filter(([, spec]) => spec.group === group)
              .map(([key, spec]) => {
                const value = values[key] ?? spec.fallback;
                const span = spec.max - spec.min;
                const at = span === 0 ? 0 : ((value - spec.min) / span) * 100;

                return (
                  <div
                    key={key}
                    className="rounded-[14px] border border-site-line bg-site-page px-4 py-3.5"
                  >
                    <div className="flex items-baseline gap-3">
                      <span className="text-[13.5px] font-semibold text-site-ink">
                        {spec.label}
                      </span>
                      <span className="ml-auto font-mono text-[13px] tabular-nums text-site-ink">
                        {format(key, value)}
                      </span>
                    </div>

                    {/* A track, not an input. This is a reading of a published
                        value; the editor that writes a draft is a separate,
                        client component and does not exist yet. Showing a
                        control that cannot be dragged would be worse than
                        showing a figure. */}
                    <div className="relative mt-3 h-1 rounded-full bg-site-sunk">
                      <div
                        className="absolute inset-y-0 left-0 rounded-full bg-site-accent"
                        style={{ width: `${at}%` }}
                      />
                      <div
                        className="absolute top-1/2 size-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-site-accent"
                        style={{ left: `${at}%` }}
                      />
                    </div>

                    <p className="mt-2.5 text-[12px] leading-relaxed text-site-ink-3">
                      {spec.help}
                    </p>

                    <p className="mt-2 font-mono text-[11px] text-site-ink-3">
                      range {format(key, spec.min)} to {format(key, spec.max)}
                      {value !== spec.fallback && (
                        <> &middot; compiled {format(key, spec.fallback)}</>
                      )}
                    </p>
                  </div>
                );
              })}
          </div>
        </SoftPanel>
      ))}

      <p className="text-[12px] leading-relaxed text-site-ink-3">
        Thresholds decide what is offered. Nothing on this page changes what the
        app does to a file once you have agreed to it, which is why these can
        ship as content while the compression itself cannot.
      </p>
    </StudioShell>
  );
}

/** One line per group, explaining what the group governs. */
function noteFor(group: string): string {
  switch (group) {
    case 'Video':
      return 'Which clips are offered, and how the estimate is made';
    case 'Images':
      return 'Which files are worth showing, and what counts as a saving';
    case 'Compare':
      return 'Where the line between soft and sharp falls';
    default:
      return '';
  }
}

/**
 * A number a person can read.
 *
 * Four million bits per megapixel means nothing at a glance; 4.0 Mbit means
 * something to anybody who has looked at a video file.
 */
function format(key: string, value: number): string {
  if (key === 'compressFloorBytes') {
    return `${(value / (1024 * 1024)).toFixed(value < 1024 * 1024 ? 2 : 0)} MB`;
  }
  if (key === 'videoSampleMillis') return `${Math.round(value / 1000)} s`;
  if (key === 'videoMinBitsPerMegapixel') {
    return `${(value / 1_000_000).toFixed(1)} Mbit`;
  }
  if (key.endsWith('Percent')) return `${value} %`;
  return `${value}`;
}
