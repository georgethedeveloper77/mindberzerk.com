import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SlabCell, SoftPanel, TaskRow } from '@/components/studio/ui';
import { appMeta, appName } from '@/lib/core/registry';
import { readVpnState, type SourceHealth } from '@/lib/g-vpn/servers';

const APP_ID = 'g-vpn';

/** Minutes since an ISO time, or null. */
function ageMinutes(iso: string | null): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isNaN(t) ? null : Math.round((Date.now() - t) / 60000);
}

function ago(mins: number | null): string {
  if (mins == null) return 'never';
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  return `${Math.round(mins / 60)}h ago`;
}

function sourceLine(s: SourceHealth | undefined): { v: string; tone?: 'ok' | 'bad' } {
  if (!s) return { v: 'not read yet' };
  if (s.off) return { v: 'off' };
  if (!s.ok) return { v: s.error ?? 'failed', tone: 'bad' };
  return { v: `${s.count ?? 0} servers${s.skipped ? `, ${s.skipped} unreadable` : ''}`, tone: 'ok' };
}

/**
 * THE G VPN OVERVIEW. Is the Community list healthy, in one screen.
 *
 * The list is the app's content: a stale or empty one is the failure users
 * meet first. So the tasks are about the Worker and its sources, and every
 * figure comes from the Worker's own record of its last refresh. An
 * unreachable Worker renders as a named absence, never as zeros.
 */
export async function VpnOverview() {
  const state = await readVpnState();
  const meta = appMeta(APP_ID);
  const down = state.unreachable != null;
  const age = ageMinutes(state.updatedAt);
  const listed = state.servers.filter((s) => s.listed);
  const hidden = state.servers.filter((s) => s.hidden).length;
  const pinned = state.servers.filter((s) => s.pinned).length;
  const countries = new Set(listed.map((s) => s.countryCode)).size;
  const fast = listed.filter((s) => s.grade === 'fast').length;

  interface Task {
    level: 'bad' | 'warn' | 'ok';
    title: string;
    detail: React.ReactNode;
    href?: string;
    where?: string;
  }
  const tasks: Task[] = [];
  if (down) {
    tasks.push({
      level: 'bad',
      title: 'The server Worker could not be read',
      detail: `${state.unreachable}. Check GVPN_ADMIN_TOKEN matches the Worker's REFRESH_TOKEN.`,
    });
  } else {
    if (age == null || age > 180) {
      tasks.push({
        level: 'bad',
        title: age == null ? 'The list has never been built' : `The list is ${ago(age)} old`,
        detail: 'The cron runs every two hours. Refresh now from Servers, then check the Worker logs.',
        href: `/apps/${APP_ID}/servers`,
        where: 'Servers',
      });
    }
    if (listed.length < 15) {
      tasks.push({
        level: listed.length === 0 ? 'bad' : 'warn',
        title: `Only ${listed.length} servers listed`,
        detail: 'Users see a short list. Check the sources, or unhide servers.',
        href: `/apps/${APP_ID}/sources`,
        where: 'Sources',
      });
    }
    for (const [name, s] of Object.entries(state.sources)) {
      if (s && !s.ok && !s.off) {
        tasks.push({
          level: 'warn',
          title: `${name === 'oneconnect' ? 'OneConnect' : 'VPN Gate'} failed at the last refresh`,
          detail: s.error ?? 'No detail.',
          href: `/apps/${APP_ID}/sources`,
          where: 'Sources',
        });
      }
    }
    if ((state.sources.oneconnect?.skipped ?? 0) > 0) {
      tasks.push({
        level: 'warn',
        title: `${state.sources.oneconnect!.skipped} OneConnect configs unreadable`,
        detail: 'They arrive in a form that is not plain OpenVPN text, so they are left out rather than guessed at.',
        href: `/apps/${APP_ID}/sources`,
        where: 'Sources',
      });
    }
  }
  if (tasks.length === 0) {
    tasks.push({ level: 'ok', title: 'Nothing needs doing', detail: `Last refresh ${ago(age)}, every source answered.` });
  }

  const vpngate = sourceLine(state.sources.vpngate);
  const oneconnect = sourceLine(state.sources.oneconnect);

  return (
    <StudioShell app={APP_ID}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(APP_ID)}
        title="Overview"
        meta={meta?.pkg ?? undefined}
        actions={
          <>
            {meta?.pkg && (
              <SlabButton href={`https://play.google.com/store/apps/details?id=${meta.pkg}`} external>
                Store listing
              </SlabButton>
            )}
            <SlabButton href={`/apps/${APP_ID}/servers`} primary>
              Servers
            </SlabButton>
          </>
        }
        metrics={
          <>
            <SlabCell
              label="Listed"
              value={down ? 'unknown' : listed.length}
              of={down ? undefined : `of ${state.servers.length}`}
              measured={!down}
              note={down ? 'Worker unreachable' : `${countries} countries`}
            />
            <SlabCell label="Fast" value={down ? 'unknown' : fast} measured={!down} note="graded fast" />
            <SlabCell
              label="Overrides"
              value={down ? 'unknown' : pinned + hidden}
              measured={!down}
              note={`${pinned} pinned · ${hidden} hidden`}
            />
            <SlabCell label="Refreshed" value={ago(age)} measured={false} note="cron every 2h" />
          </>
        }
      />

      <SoftPanel title="What needs doing" flush>
        {tasks.map((t, i) => (
          <TaskRow key={i} {...t} />
        ))}
      </SoftPanel>

      <SoftPanel title="Sources" note="at the last refresh">
        <KVRow k="VPN Gate" v={vpngate.v} tone={vpngate.tone} />
        <KVRow k="OneConnect" v={state.oneconnectKey ? oneconnect.v : 'no key set'} tone={state.oneconnectKey ? oneconnect.tone : 'bad'} />
      </SoftPanel>
    </StudioShell>
  );
}
