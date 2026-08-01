import 'server-only';

/**
 * SITE TRAFFIC, read from the GA4 Data API.
 *
 * ## Why this is not `analytics.ts`
 *
 * That file answers questions about the LAUNCHER from the BigQuery export:
 * funnels, retention by distro, package frequency. Those need raw per-event
 * rows, so they need the export, which is a project switch that is still off.
 *
 * This answers a much smaller question about the WEBSITE: how many people came,
 * and from where. The Data API serves exactly that, aggregated, with no export
 * to enable and no daily table to wait for. Different question, different
 * source, same honesty rules.
 *
 * ## The measurement id is NOT what this needs
 *
 * `G-8RHHEN2X07` identifies the web data stream that the site SENDS to, and it
 * belongs in NEXT_PUBLIC_GA_MEASUREMENT_ID on the site. The Data API reads with
 * a numeric PROPERTY id, a different number found in GA4 admin under Property
 * details. Setting the measurement id here produces a confusing permission
 * error rather than a helpful one, so the check below names the difference.
 *
 * ## Nothing is invented, ever
 *
 * Same discriminated result as `analytics.ts`, for the same reason: the moment
 * one figure on a dashboard is fabricated, every figure is suspect. Not
 * connected is a state worth rendering honestly.
 */

export type Traffic<T> =
  | { connected: true; data: T }
  | { connected: false; reason: string };

export interface TrafficSummary {
  /** Active users in the window. */
  visitors: number;
  /** The same figure for the window before it, for a comparison. */
  previous: number;
  /** Daily active users, oldest first, for the sparkline. */
  series: { date: string; users: number }[];
  /** Session source, largest first. Capped, because a legend is not a table. */
  sources: { source: string; users: number }[];
}

function propertyId(): string | null {
  const raw = (process.env.GA4_PROPERTY_ID ?? '').trim();
  if (!raw) return null;
  return raw.replace(/^properties\//, '');
}

/**
 * The client, or a reason. Dynamic import so a deploy without the dependency
 * still builds: analytics being unconfigured must never block a publish.
 */
async function client(): Promise<
  { api: import('@google-analytics/data').BetaAnalyticsDataClient } | { error: string }
> {
  try {
    const mod = await import('@google-analytics/data');
    // App Hosting runs as a service account; add it as a Viewer on the GA4
    // property and Application Default Credentials do the rest. No key file.
    return { api: new mod.BetaAnalyticsDataClient() };
  } catch {
    return {
      error:
        'The GA4 client is not installed. Run `npm i @google-analytics/data`, then ' +
        'set GA4_PROPERTY_ID and add the App Hosting service account as a Viewer ' +
        'on the property.',
    };
  }
}

/** Whole days, so a comparison window is never half a day short. */
function windowFor(days: number): { start: string; end: string; prevStart: string; prevEnd: string } {
  return {
    start: `${days}daysAgo`,
    end: 'today',
    prevStart: `${days * 2}daysAgo`,
    prevEnd: `${days + 1}daysAgo`,
  };
}

export async function siteTraffic(days = 30): Promise<Traffic<TrafficSummary>> {
  const property = propertyId();
  if (!property) {
    return {
      connected: false,
      reason:
        'GA4_PROPERTY_ID is not set. It is the numeric property id from GA4 admin, ' +
        'not the G- measurement id the site sends with.',
    };
  }
  if (/^G-/i.test(property)) {
    return {
      connected: false,
      reason:
        'GA4_PROPERTY_ID holds a measurement id. The Data API reads with the numeric ' +
        'property id from GA4 admin, Property details.',
    };
  }

  const c = await client();
  if ('error' in c) return { connected: false, reason: c.error };

  const w = windowFor(days);
  const prop = `properties/${property}`;

  try {
    // Three small reports rather than one wide one: a single report cannot mix
    // a date breakdown with a source breakdown without multiplying the rows.
    const [daily] = await c.api.runReport({
      property: prop,
      dateRanges: [{ startDate: w.start, endDate: w.end }],
      dimensions: [{ name: 'date' }],
      metrics: [{ name: 'activeUsers' }],
      orderBys: [{ dimension: { dimensionName: 'date' } }],
    });

    const [previous] = await c.api.runReport({
      property: prop,
      dateRanges: [{ startDate: w.prevStart, endDate: w.prevEnd }],
      metrics: [{ name: 'activeUsers' }],
    });

    const [bySource] = await c.api.runReport({
      property: prop,
      dateRanges: [{ startDate: w.start, endDate: w.end }],
      dimensions: [{ name: 'sessionSource' }],
      metrics: [{ name: 'activeUsers' }],
      orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
      limit: 6,
    });

    const series = (daily.rows ?? []).map((r) => ({
      date: r.dimensionValues?.[0]?.value ?? '',
      users: Number(r.metricValues?.[0]?.value ?? 0),
    }));

    return {
      connected: true,
      data: {
        visitors: series.reduce((n, d) => n + d.users, 0),
        previous: Number(previous.rows?.[0]?.metricValues?.[0]?.value ?? 0),
        series,
        sources: (bySource.rows ?? []).map((r) => ({
          // GA4 writes '(direct)' for no referrer. Rendering that verbatim in a
          // legend looks like a bug, so it is named the way a person would.
          source: (r.dimensionValues?.[0]?.value ?? '').replace(/^\(direct\)$/, 'Direct'),
          users: Number(r.metricValues?.[0]?.value ?? 0),
        })),
      },
    };
  } catch (e) {
    const msg = (e as Error).message;
    if (/PERMISSION_DENIED|403/i.test(msg)) {
      return {
        connected: false,
        reason:
          'The service account cannot read this property. Add it as a Viewer in ' +
          'GA4 admin, Property access management.',
      };
    }
    if (/NOT_FOUND|404/i.test(msg)) {
      return { connected: false, reason: `No GA4 property ${property}. Check the id in GA4 admin.` };
    }
    return { connected: false, reason: msg };
  }
}

/** Percentage change, or null when there is no baseline to compare against. */
export function delta(now: number, before: number): number | null {
  if (!before) return null;
  return Math.round(((now - before) / before) * 1000) / 10;
}
