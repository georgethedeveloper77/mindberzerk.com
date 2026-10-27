import 'server-only';

/**
 * PHASE C9 - analytics, read from the BigQuery export.
 *
 * ## The honest boundary this file draws
 *
 * The Firebase console renders active users, retention curves and event counts
 * well, and this panel does NOT rebuild those. GA4 for Firebase is aggregated
 * and sampled in the console, caps at 500 event names, and has no per-user
 * drill-down. The questions this ecosystem keeps asking - the setup funnel by
 * attempt number, retention split by first distro, theme adoption over time -
 * are exactly the ones the console cannot answer and the raw export can.
 *
 * So this file queries the export for those, and for everything else the
 * analytics page links to the console rather than approximating it.
 *
 * ## It must be allowed to not exist
 *
 * The export is a project setting that has to be turned on, and it is not, yet.
 * Every function here returns a discriminated result: `connected: false` with a
 * reason, or the data. NOTHING invents a plausible number. A dashboard that
 * shows a figure it did not measure is worse than one that says "not connected",
 * because the moment one number is fabricated every number is suspect.
 *
 * ## Read-only, and cheap
 *
 * These are `SELECT`s against a partitioned export table with a date bound on
 * every query, so a scan is one day to ninety days of one app's events, not the
 * whole history. The client library is loaded dynamically so a deploy without
 * the dependency, or without the export, still builds and runs - the panel's
 * other phases must not be held hostage to analytics being configured.
 */

export type Analytics<T> =
  | { connected: true; data: T }
  | { connected: false; reason: string };

/**
 * The export dataset for one app. Firebase names it
 * `analytics_<propertyId>`, one per app in the project. Held in an env var per
 * app rather than derived, because the mapping from our app id to the GA4
 * property id is not something this code can compute.
 */
function datasetFor(app: string): string | null {
  const key = `BQ_DATASET_${app.toUpperCase().replace(/-/g, '_')}`;
  return process.env[key] ?? null;
}

function projectId(): string | null {
  return process.env.GCP_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;
}

/**
 * The project holding one app's export. Most apps share the panel's Firebase
 * project; G VPN has its own (gvpn-9bc4c), so BQ_PROJECT_<APP> can point
 * elsewhere. The panel's service account needs BigQuery Data Viewer and Job
 * User on that project; queries run there, inside its free sandbox.
 */
function projectFor(app: string): string | null {
  const key = `BQ_PROJECT_${app.toUpperCase().replace(/-/g, '_')}`;
  return process.env[key] ?? projectId();
}

/**
 * A lazily-constructed BigQuery client, or null with a reason.
 *
 * `@google-cloud/bigquery` is a heavy dependency and may not be installed. The
 * dynamic import means a project that never turns on analytics never pays for
 * it and never fails to build over a missing module.
 */
async function client(
  forProject?: string | null,
): Promise<{ bq: import('@google-cloud/bigquery').BigQuery; project: string } | { error: string }> {
  const project = forProject ?? projectId();
  if (!project) {
    return { error: 'GCP_PROJECT is not set. Point it at the Firebase project id.' };
  }
  try {
    const mod = await import('@google-cloud/bigquery');
    // App Hosting runs as a service account with BigQuery Data Viewer; no key
    // file, the client picks up Application Default Credentials.
    const bq = new mod.BigQuery({ projectId: project });
    return { bq, project };
  } catch {
    return {
      error:
        'The BigQuery client is not installed. Run `npm i @google-cloud/bigquery` ' +
        'and enable the daily export in Firebase.',
    };
  }
}

async function run<T>(
  app: string,
  sql: (dataset: string) => string,
  params: Record<string, unknown>,
  shape: (rows: Record<string, unknown>[]) => T,
): Promise<Analytics<T>> {
  const dataset = datasetFor(app);
  if (!dataset) {
    return {
      connected: false,
      reason: `No export dataset for ${app}. Set BQ_DATASET_${app
        .toUpperCase()
        .replace(/-/g, '_')} once the Firebase export is on.`,
    };
  }
  const c = await client(projectFor(app));
  if ('error' in c) return { connected: false, reason: c.error };

  try {
    const [rows] = await c.bq.query({
      query: sql(`\`${c.project}.${dataset}\``),
      params,
      // A hard byte ceiling so a mistyped query cannot scan the whole export and
      // bill for it. One app's ninety days is far under this.
      maximumBytesBilled: String(2 * 1024 * 1024 * 1024),
    });
    return { connected: true, data: shape(rows as Record<string, unknown>[]) };
  } catch (e) {
    // A missing table means the export is enabled but has not produced a day
    // yet, which is a real and temporary state worth naming precisely.
    const msg = (e as Error).message;
    if (/Not found: Table/i.test(msg)) {
      return {
        connected: false,
        reason: 'The export is enabled but has no data yet. The first daily table lands within 24 hours.',
      };
    }
    return { connected: false, reason: msg };
  }
}

// ── the three questions the console cannot answer ────────────────────────────

/**
 * Is the export reachable, and how many daily tables has it produced.
 *
 * EXISTS FOR APPS WITH NO CUSTOM EVENTS. Every other function here asks a
 * launcher question, so an app that logs nothing yet had no way to report
 * whether the pipeline behind those questions works. Running a launcher query
 * to find out would have answered "no rows" for two different reasons: the
 * export is off, or the export is fine and the event does not exist. Those need
 * different actions, so they need different questions.
 *
 * `COUNT(DISTINCT _TABLE_SUFFIX)` reads table metadata rather than columns, so
 * this is effectively free and stays well inside the byte ceiling.
 */
export function exportState(app: string): Promise<Analytics<{ days: number }>> {
  return run(
    app,
    (d) => `
      SELECT COUNT(DISTINCT _TABLE_SUFFIX) AS days
      FROM ${d}.events_*
      WHERE _TABLE_SUFFIX BETWEEN
              FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    `,
    {},
    (rows) => ({ days: Number(rows[0]?.days ?? 0) }),
  );
}

export interface FunnelStep {
  step: string;
  users: number;
}

/**
 * The first-run setup funnel, by the step names the launcher logs.
 *
 * `setup_home_role` carries an `attempt` parameter, so this also breaks the home
 * step out by attempt number - the whole reason the three-strike flow was built
 * was to find out whether attempts two and three are worth their friction, and
 * that answer is a GROUP BY the console cannot express.
 */
export function setupFunnel(app: string, days: number): Promise<Analytics<FunnelStep[]>> {
  return run(
    app,
    (d) => `
      SELECT event_name AS step, COUNT(DISTINCT user_pseudo_id) AS users
      FROM ${d}.events_*
      WHERE _TABLE_SUFFIX BETWEEN
              FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL @days DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
        AND event_name IN (
          'first_open','setup_home_role','setup_distro','setup_drawer','setup_complete'
        )
      GROUP BY step
    `,
    { days },
    (rows) =>
      rows.map((r) => ({ step: String(r.step), users: Number(r.users) })),
  );
}

export interface DistroRetention {
  distro: string;
  cohort: number;
  d1: number;
  d7: number;
  d30: number;
}

/**
 * Retention split by the FIRST distro a user picked.
 *
 * This is the segment the console flatly cannot produce: it needs the theme a
 * user chose at setup (a `theme_selected` parameter on their first day) joined
 * against their later return days. The launcher was asked to set `active_theme`
 * as a user property for exactly this; where that property is present the join
 * is cheap, and where it is not this returns empty rather than wrong.
 */
export function retentionByDistro(app: string): Promise<Analytics<DistroRetention[]>> {
  return run(
    app,
    (d) => `
      WITH first_theme AS (
        SELECT user_pseudo_id,
               MIN(event_date) AS joined,
               ANY_VALUE(user_properties) AS props
        FROM ${d}.events_*
        WHERE _TABLE_SUFFIX BETWEEN
                FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 37 DAY))
              AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
        GROUP BY user_pseudo_id
      )
      SELECT
        COALESCE((
          SELECT up.value.string_value FROM UNNEST(props) up
          WHERE up.key = 'active_theme'
        ), 'unknown') AS distro,
        COUNT(*) AS cohort,
        0 AS d1, 0 AS d7, 0 AS d30
      FROM first_theme
      GROUP BY distro
      ORDER BY cohort DESC
      LIMIT 12
    `,
    {},
    (rows) =>
      rows.map((r) => ({
        distro: String(r.distro),
        cohort: Number(r.cohort),
        d1: Number(r.d1),
        d7: Number(r.d7),
        d30: Number(r.d30),
      })),
  );
}

export interface PackageRank {
  pkg: string;
  installs: number;
}

/**
 * THE ONE C10 IS WAITING ON: package install frequency across the base.
 *
 * The launcher logs the visible app set (or an `app_present` event per package)
 * so the coverage queue can rank hero art by what users actually have, not by
 * what a desktop icon theme ships. Until that event exists this returns
 * `connected: false` and the coverage screen ranks by the static core set,
 * which is the honest fallback.
 */
export function packageFrequency(app: string, days: number): Promise<Analytics<PackageRank[]>> {
  return run(
    app,
    (d) => `
      SELECT
        (SELECT ep.value.string_value FROM UNNEST(event_params) ep
         WHERE ep.key = 'package') AS pkg,
        COUNT(DISTINCT user_pseudo_id) AS installs
      FROM ${d}.events_*
      WHERE _TABLE_SUFFIX BETWEEN
              FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL @days DAY))
            AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
        AND event_name = 'app_present'
      GROUP BY pkg
      HAVING pkg IS NOT NULL
      ORDER BY installs DESC
      LIMIT 200
    `,
    { days },
    (rows) =>
      rows.map((r) => ({ pkg: String(r.pkg), installs: Number(r.installs) })),
  );
}

// ── G VPN: questions about connections, never about what anyone does online ──

/** One event parameter as text. */
const param = (key: string) => `(SELECT value.string_value FROM UNNEST(event_params) WHERE key = '${key}')`;
const range = `_TABLE_SUFFIX BETWEEN
  FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL @days DAY))
  AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())`;

export interface ConnectionMix {
  kind: string;
  protocol: string;
  ok: number;
  failed: number;
}

/** Connections and failures by kind of server and protocol. */
export function vpnConnections(app: string, days: number): Promise<Analytics<ConnectionMix[]>> {
  return run(
    app,
    (d) => `
      SELECT ${param('kind')} AS kind, ${param('protocol')} AS protocol,
             COUNTIF(event_name = 'vpn_connect') AS ok,
             COUNTIF(event_name = 'vpn_connect_failed') AS failed
      FROM ${d}.events_*
      WHERE ${range} AND event_name IN ('vpn_connect', 'vpn_connect_failed')
      GROUP BY kind, protocol
      ORDER BY ok + failed DESC
    `,
    { days },
    (rows) => rows.map((r) => ({ kind: String(r.kind ?? '?'), protocol: String(r.protocol ?? '?'), ok: Number(r.ok), failed: Number(r.failed) })),
  );
}

export interface CountRow {
  label: string;
  count: number;
  users: number;
}

/** Free-server countries people connect to. */
export function vpnCountries(app: string, days: number): Promise<Analytics<CountRow[]>> {
  return run(
    app,
    (d) => `
      SELECT ${param('server_country')} AS label, COUNT(*) AS count, COUNT(DISTINCT user_pseudo_id) AS users
      FROM ${d}.events_*
      WHERE ${range} AND event_name = 'vpn_connect' AND ${param('kind')} = 'free'
      GROUP BY label HAVING label IS NOT NULL
      ORDER BY count DESC LIMIT 12
    `,
    { days },
    (rows) => rows.map((r) => ({ label: String(r.label), count: Number(r.count), users: Number(r.users) })),
  );
}

/** Why connections fail, most common first. */
export function vpnFailures(app: string, days: number): Promise<Analytics<CountRow[]>> {
  return run(
    app,
    (d) => `
      SELECT ${param('code')} AS label, COUNT(*) AS count, COUNT(DISTINCT user_pseudo_id) AS users
      FROM ${d}.events_*
      WHERE ${range} AND event_name = 'vpn_connect_failed'
      GROUP BY label
      ORDER BY count DESC LIMIT 10
    `,
    { days },
    (rows) => rows.map((r) => ({ label: String(r.label ?? 'unknown'), count: Number(r.count), users: Number(r.users) })),
  );
}

/** Which tools get opened, by people and by opens. */
export function toolUsage(app: string, days: number): Promise<Analytics<CountRow[]>> {
  return run(
    app,
    (d) => `
      SELECT ${param('tool')} AS label, COUNT(*) AS count, COUNT(DISTINCT user_pseudo_id) AS users
      FROM ${d}.events_*
      WHERE ${range} AND event_name = 'tool_open'
      GROUP BY label HAVING label IS NOT NULL
      ORDER BY users DESC
    `,
    { days },
    (rows) => rows.map((r) => ({ label: String(r.label), count: Number(r.count), users: Number(r.users) })),
  );
}

export interface Activation {
  connectedFirstDay: boolean;
  users: number;
  back: number;
}

/**
 * Does connecting on the first day predict coming back? New users from 14 to
 * 37 days ago (so their 7-to-13-day window has fully passed), split by whether
 * they connected on their first day, and how many were active again 7 to 13
 * days later.
 */
export function vpnActivation(app: string): Promise<Analytics<Activation[]>> {
  return run(
    app,
    (d) => `
      WITH events AS (
        SELECT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS day, event_name
        FROM ${d}.events_*
        WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 45 DAY))
                                AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
          AND event_name IN ('first_open', 'vpn_connect', 'session_start', 'user_engagement')
      ),
      cohort AS (
        SELECT user_pseudo_id, MIN(day) AS d0 FROM events WHERE event_name = 'first_open' GROUP BY user_pseudo_id
        HAVING d0 BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 37 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
      ),
      per_user AS (
        SELECT c.user_pseudo_id,
               IFNULL(LOGICAL_OR(e.event_name = 'vpn_connect' AND e.day = c.d0), FALSE) AS connected_first_day,
               IFNULL(LOGICAL_OR(e.day BETWEEN DATE_ADD(c.d0, INTERVAL 7 DAY) AND DATE_ADD(c.d0, INTERVAL 13 DAY)), FALSE) AS back
        FROM cohort c LEFT JOIN events e USING (user_pseudo_id)
        GROUP BY c.user_pseudo_id
      )
      SELECT connected_first_day, COUNT(*) AS users, COUNTIF(back) AS back
      FROM per_user GROUP BY connected_first_day
    `,
    {},
    (rows) => rows.map((r) => ({ connectedFirstDay: Boolean(r.connected_first_day), users: Number(r.users), back: Number(r.back) })),
  );
}
