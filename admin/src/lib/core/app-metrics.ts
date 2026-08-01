import 'server-only';

/**
 * INSTALLS AND ACTIVE USERS, per app.
 *
 * ## Three systems, and none of them is the one you would guess
 *
 * The Google Play Developer API does NOT serve install counts. It serves
 * listings, products, releases and reviews. The Play Developer Reporting API
 * serves vitals: crash rate, ANR rate, slow starts. Neither answers "how many
 * people installed this".
 *
 * Installs live in the monthly statistics reports Play writes to a Cloud
 * Storage bucket owned by the developer account, as CSV, and that is the only
 * programmatic source. So:
 *
 *   installs      -> gs://pubsite_prod_rev_<id>/stats/installs/...csv
 *   active users  -> GA4 Data API, the property Firebase created for the app
 *   revenue       -> not here, ever. Play's financial reports are the system of
 *                    record and a second answer to a revenue question is worse
 *                    than no answer.
 *
 * ## Two traps in that CSV, both of which look like a parser bug
 *
 *  1. IT IS UTF-16LE, not UTF-8. Decoded as UTF-8 it yields a header row of
 *     nulls and every subsequent parse silently produces zeroes.
 *  2. The columns move. Play has added and reordered them over the years, so
 *     this reads BY HEADER NAME and reports a missing column rather than
 *     trusting an index that was correct when it was written.
 *
 * ## And one that looks like a configuration mistake
 *
 * Service account access to that bucket has been reported failing with 403 even
 * when the account holds "View app information and download bulk reports" at
 * the account level. If that is what is happening, the reason below says so by
 * name rather than leaving you re-granting a permission you already granted.
 *
 * ## Nothing is invented
 *
 * Same discriminated result as `analytics.ts` and `site-traffic.ts`. Not
 * connected is a state that renders honestly; a fabricated install count would
 * make every other figure on the page suspect.
 */

export type Measured<T> = { ok: true; data: T } | { ok: false; reason: string };

// ── installs ────────────────────────────────────────────────────────────────

export interface InstallPoint {
  /** YYYY-MM-DD. */
  date: string;
  installs: number;
  uninstalls: number;
}

export interface InstallSummary {
  /** Daily user installs, oldest first, across the window read. */
  series: InstallPoint[];
  installs: number;
  uninstalls: number;
  /** Net for the window. Can be negative, and that is worth seeing. */
  net: number;
  /** Play's own running total on the last day read, when the column exists. */
  totalUserInstalls: number | null;
  /** Devices with the app installed, on the last day read. */
  activeDeviceInstalls: number | null;
  /** The last date the report covered. Play updates overnight. */
  through: string | null;
}

function bucketId(): string | null {
  const raw = (process.env.PLAY_REPORTS_BUCKET ?? '').trim();
  if (!raw) return null;
  // Accept a full gs:// URI, because that is what the Copy button gives you.
  return raw.replace(/^gs:\/\//, '').split('/')[0];
}

function monthKey(d: Date): string {
  return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

/**
 * Parse one overview CSV.
 *
 * Returns null when the header does not carry the columns we need, which is a
 * different failure from an empty file and is reported as such.
 */
function parseInstalls(csv: string): {
  points: InstallPoint[];
  total: number | null;
  active: number | null;
} | null {
  const lines = csv
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length < 2) return { points: [], total: null, active: null };

  // Strip a BOM if the decoder left one, then split on commas. These reports
  // have no quoted commas in the columns read here.
  const header = lines[0].replace(/^\uFEFF/, '').split(',');
  const at = (name: string) => header.findIndex((h) => h.trim().toLowerCase() === name);

  const iDate = at('date');
  const iInstalls = at('daily user installs');
  const iUninstalls = at('daily user uninstalls');
  if (iDate < 0 || iInstalls < 0) return null;

  const iTotal = at('total user installs');
  const iActive = at('active device installs');

  const points: InstallPoint[] = [];
  let total: number | null = null;
  let active: number | null = null;

  for (const line of lines.slice(1)) {
    const cells = line.split(',');
    const date = (cells[iDate] ?? '').trim();
    if (!date) continue;
    points.push({
      date,
      installs: Number(cells[iInstalls] ?? 0) || 0,
      uninstalls: iUninstalls >= 0 ? Number(cells[iUninstalls] ?? 0) || 0 : 0,
    });
    if (iTotal >= 0) total = Number(cells[iTotal] ?? 0) || total;
    if (iActive >= 0) active = Number(cells[iActive] ?? 0) || active;
  }

  return { points, total, active };
}

/**
 * Installs for one package, over the current month and the one before it.
 *
 * TWO MONTHS, not one, because on the second of the month a single-month read
 * shows one data point and looks broken. The caller can window it further.
 */
export async function appInstalls(pkg: string | null): Promise<Measured<InstallSummary>> {
  if (!pkg) {
    return { ok: false, reason: 'This app has no package, so Play has no reports for it.' };
  }
  const bucket = bucketId();
  if (!bucket) {
    return {
      ok: false,
      reason:
        'PLAY_REPORTS_BUCKET is not set. Copy the Cloud Storage URI from Play Console, ' +
        'Download reports, Statistics. It looks like pubsite_prod_rev_0123456789.',
    };
  }

  let Storage: typeof import('@google-cloud/storage').Storage;
  try {
    ({ Storage } = await import('@google-cloud/storage'));
  } catch {
    return {
      ok: false,
      reason: 'The Cloud Storage client is not installed. Run `npm i @google-cloud/storage`.',
    };
  }

  const now = new Date();
  const previous = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const months = [monthKey(previous), monthKey(now)];

  const storage = new Storage();
  const points: InstallPoint[] = [];
  let total: number | null = null;
  let active: number | null = null;
  let read = 0;
  let lastError = '';

  for (const month of months) {
    const path = `stats/installs/installs_${pkg}_${month}_overview.csv`;
    try {
      const [buf] = await storage.bucket(bucket).file(path).download();
      // UTF-16LE. Decoding as UTF-8 yields a header of nulls and a silent zero
      // for every figure, which is the failure that looks like "no installs".
      const parsed = parseInstalls(buf.toString('utf16le'));
      if (parsed === null) {
        return {
          ok: false,
          reason: `${path} does not carry a Date or Daily User Installs column. Play may have changed the report format.`,
        };
      }
      points.push(...parsed.points);
      if (parsed.total !== null) total = parsed.total;
      if (parsed.active !== null) active = parsed.active;
      read += 1;
    } catch (e) {
      const msg = (e as Error).message ?? '';
      // A missing month is normal: a new app, or the first day of a month
      // before Play has written the file.
      if (/No such object|404/i.test(msg)) continue;
      lastError = msg;
    }
  }

  if (read === 0) {
    if (/403|permission|forbidden/i.test(lastError)) {
      return {
        ok: false,
        reason:
          'Play refused the reports bucket with 403. Grant the service account "View app ' +
          'information and download bulk reports" at ACCOUNT level, not per app. Note that ' +
          'service account access to these buckets has been reported failing even when that ' +
          'is granted, in which case the reports have to be fetched with a user credential.',
      };
    }
    if (lastError) return { ok: false, reason: lastError };
    return {
      ok: false,
      reason: `No install reports for ${pkg} yet. Play writes the first one overnight after the app has installs.`,
    };
  }

  points.sort((a, b) => a.date.localeCompare(b.date));
  const installs = points.reduce((n, p) => n + p.installs, 0);
  const uninstalls = points.reduce((n, p) => n + p.uninstalls, 0);

  return {
    ok: true,
    data: {
      series: points,
      installs,
      uninstalls,
      net: installs - uninstalls,
      totalUserInstalls: total,
      activeDeviceInstalls: active,
      through: points.length ? points[points.length - 1].date : null,
    },
  };
}

// ── active users ────────────────────────────────────────────────────────────

export interface AudienceSummary {
  activeUsers: number;
  newUsers: number;
  /** Previous equal-length window, for a comparison. */
  previousActive: number;
  /** Daily active users, oldest first. */
  series: { date: string; users: number }[];
}

/**
 * The GA4 property for one app.
 *
 * Per app, because Firebase creates one property per app and there is no way to
 * derive the numeric id from our app id. `GA4_PROPERTY_G_LAUNCHER`, and so on.
 * The site's own property is a separate variable read by `site-traffic.ts`.
 */
function propertyFor(app: string): string | null {
  const key = `GA4_PROPERTY_${app.toUpperCase().replace(/-/g, '_')}`;
  const raw = (process.env[key] ?? '').trim();
  return raw ? raw.replace(/^properties\//, '') : null;
}

export async function appAudience(app: string, days = 30): Promise<Measured<AudienceSummary>> {
  const property = propertyFor(app);
  if (!property) {
    const key = `GA4_PROPERTY_${app.toUpperCase().replace(/-/g, '_')}`;
    return {
      ok: false,
      reason: `${key} is not set. It is the numeric property id from GA4 admin, not the G- measurement id the app sends with.`,
    };
  }
  if (/^G-/i.test(property)) {
    return {
      ok: false,
      reason: 'That is a measurement id. The Data API reads with the numeric property id from GA4 admin, Property details.',
    };
  }

  let api: import('@google-analytics/data').BetaAnalyticsDataClient;
  try {
    const mod = await import('@google-analytics/data');
    api = new mod.BetaAnalyticsDataClient();
  } catch {
    return { ok: false, reason: 'The GA4 client is not installed. Run `npm i @google-analytics/data`.' };
  }

  const prop = `properties/${property}`;
  try {
    const [daily] = await api.runReport({
      property: prop,
      dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
      dimensions: [{ name: 'date' }],
      metrics: [{ name: 'activeUsers' }, { name: 'newUsers' }],
      orderBys: [{ dimension: { dimensionName: 'date' } }],
    });

    const [prior] = await api.runReport({
      property: prop,
      dateRanges: [{ startDate: `${days * 2}daysAgo`, endDate: `${days + 1}daysAgo` }],
      metrics: [{ name: 'activeUsers' }],
    });

    const rows = daily.rows ?? [];
    const series = rows.map((r) => ({
      date: r.dimensionValues?.[0]?.value ?? '',
      users: Number(r.metricValues?.[0]?.value ?? 0),
    }));

    return {
      ok: true,
      data: {
        // GA4's activeUsers is not additive across days, so a 30-day total is
        // NOT the sum of the daily rows. The unqualified total comes from the
        // same report's own aggregate when present, and falls back to the peak
        // day rather than a sum that would overstate it.
        activeUsers:
          Number(daily.totals?.[0]?.metricValues?.[0]?.value ?? 0) ||
          series.reduce((m, d) => Math.max(m, d.users), 0),
        newUsers: Number(daily.totals?.[0]?.metricValues?.[1]?.value ?? 0),
        previousActive: Number(prior.rows?.[0]?.metricValues?.[0]?.value ?? 0),
        series,
      },
    };
  } catch (e) {
    const msg = (e as Error).message;
    if (/PERMISSION_DENIED|403/i.test(msg)) {
      return {
        ok: false,
        reason: 'The service account cannot read this property. Add it as a Viewer in GA4 admin, Property access management.',
      };
    }
    if (/NOT_FOUND|404/i.test(msg)) {
      return { ok: false, reason: `No GA4 property ${property}. Check the id in GA4 admin.` };
    }
    return { ok: false, reason: msg };
  }
}

/** Percentage change, or null when there is no baseline to compare against. */
export function change(now: number, before: number): number | null {
  if (!before) return null;
  return Math.round(((now - before) / before) * 1000) / 10;
}
