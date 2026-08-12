import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import {
  AppSlab,
  Cond,
  Ribbon,
  SlabCell,
  SoftButton,
  SoftPanel,
} from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * WHAT IS BETWEEN THIS APP AND THE STORE.
 *
 * ─── A CHECKLIST, NOT A FORM ─────────────────────────────────────────────────
 *
 * None of these fields are edited here. Play owns every one of them, and a
 * panel that pretended otherwise would be a second source of truth for a
 * listing that already has one.
 *
 * What this panel can own is which are outstanding and WHY each matters, which
 * otherwise lives in a chat log and is lost the moment the tab is closed.
 *
 * ─── EVERY LINE STATES A CONSEQUENCE ─────────────────────────────────────────
 *
 * "Replace the icon" is a chore. "It is shared with nine competitors on the one
 * shelf where nobody can tell them apart yet" is a reason to do it this week.
 * The second is what gets written down, because the first is already obvious
 * and still has not happened.
 *
 * ─── HAND MAINTAINED, AND HONEST ABOUT IT ────────────────────────────────────
 *
 * The Play Developer API is not enabled on this project, so nothing here is
 * read back from Console. Said on the page rather than implied by a tick,
 * because a checklist that looks live and is not is worse than one that admits
 * it.
 */
export default async function ListingPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  if (app !== 'g-recovery') notFound();

  const meta = appMeta(app);
  const open = ITEMS.filter((i) => !i.done);
  const blocking = open.filter((i) => i.blocking);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Store listing"
        meta="maintained by hand, not read back from Play"
        actions={
          <SoftButton href="https://play.google.com/console" external>
            Play Console
          </SoftButton>
        }
        metrics={
          <>
            <SlabCell label="Outstanding" value={open.length} of={`of ${ITEMS.length}`} />
            <SlabCell
              label="Blocking"
              value={blocking.length}
              note={blocking.length > 0 ? 'a release is refused' : undefined}
            />
            <SlabCell
              label="Track"
              value="none"
              note="nothing uploaded yet"
              measured={false}
            />
            <SlabCell
              label="Read from Play"
              value="no"
              note="Developer API not enabled"
              measured={false}
            />
          </>
        }
      >
        <Ribbon>
          {blocking.length > 0 ? (
            <Cond tone="bad">{blocking.length} would be rejected at review</Cond>
          ) : (
            <Cond tone="ok">Nothing would be rejected at review</Cond>
          )}
          <Cond tone="ok">Ads declaration removed</Cond>
        </Ribbon>
      </AppSlab>

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          Play owns all of these. Nothing is edited here and nothing is read
          back, because the Developer API is not enabled on this project, so
          every tick below is set by hand. It is a list of reasons rather than a
          list of tasks: the tasks were already obvious and have still not been
          done.
        </p>
      </div>

      <SoftPanel
        title="Before it can ship"
        note={`${open.length} outstanding`}
        flush
      >
        <ul>
          {ITEMS.map((item) => (
            <li
              key={item.title}
              className="flex gap-3 border-t border-site-line px-[18px] py-3.5 first:border-t-0"
            >
              <span
                aria-hidden
                className={`mt-0.5 grid size-[18px] flex-none place-items-center rounded-[6px] border text-[11px] font-bold ${
                  item.done
                    ? 'border-site-ok bg-site-ok text-white'
                    : item.blocking
                      ? 'border-site-bad text-site-bad'
                      : 'border-site-plan text-site-plan'
                }`}
              >
                {item.done ? '\u2713' : '\u2715'}
              </span>

              <div className="min-w-0 flex-1">
                <p className="text-[13.5px] font-semibold text-site-ink">
                  {item.title}
                </p>
                <p className="mt-1 text-[12px] leading-relaxed text-site-ink-3">
                  {item.why}
                </p>
              </div>

              <span
                className={`h-fit flex-none rounded-md border px-1.5 py-px font-mono text-[9.5px] tracking-[0.08em] ${
                  item.done
                    ? 'border-site-ok/30 bg-site-ok-soft text-site-ok'
                    : item.blocking
                      ? 'border-site-bad/30 bg-site-bad-soft text-site-bad'
                      : 'border-site-plan/30 bg-site-peach text-site-plan'
                }`}
              >
                {item.done ? 'DONE' : item.blocking ? 'BLOCKING' : 'OPEN'}
              </span>
            </li>
          ))}
        </ul>
      </SoftPanel>

      <p className="text-[12px] leading-relaxed text-site-ink-3">
        Blocking means a submission is refused rather than merely weakened. The
        rest cost reach: an app that looks like every other recovery app on the
        shelf gets the installs of every other recovery app on the shelf.
      </p>
    </StudioShell>
  );
}

interface Item {
  title: string;
  why: string;
  done: boolean;
  /** True where a release is refused rather than merely weakened. */
  blocking: boolean;
}

const ITEMS: Item[] = [
  {
    title: 'Remove the ads declaration',
    why:
      'The listing said Contains ads. There is no ad library in the binary, ' +
      'not even a disabled one, and the Privacy page says so in as many words.',
    done: true,
    blocking: false,
  },
  {
    title: 'Replace the icon',
    why:
      'A stock bin, shared with nine other recovery apps, on the one shelf ' +
      'where nobody can tell them apart yet. The app has a logo mark and an ' +
      'accent and neither is on the store.',
    done: false,
    blocking: false,
  },
  {
    title: 'Retake the screenshots',
    why:
      'They show an app with no files in it. There is now a hero with a real ' +
      'count, a mosaic with thumbnails, a before and after compression viewer ' +
      'and a home server page, and none of them appear.',
    done: false,
    blocking: false,
  },
  {
    title: 'Declare MANAGE_EXTERNAL_STORAGE',
    why:
      'Play requires a written justification and a demo video for All Files ' +
      'Access. Without it the release is rejected rather than delayed, and ' +
      'the permission is what makes recovery work at all.',
    done: false,
    blocking: true,
  },
  {
    title: 'Declare QUERY_ALL_PACKAGES',
    why:
      'Used as a widener over usage stats rather than a dependency: without ' +
      'it the Apps list covers only apps the user has actually opened.',
    done: false,
    blocking: true,
  },
  {
    title: 'Data safety',
    why:
      'Nothing leaves the device. No analytics identifiers, no advertising ' +
      'id, no third party sharing. This is the section the ads declaration ' +
      'would have contradicted.',
    done: true,
    blocking: false,
  },
];
