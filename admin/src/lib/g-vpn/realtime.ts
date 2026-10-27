import 'server-only';

/**
 * G VPN right now, from the GA4 Realtime API: who is in the app by
 * country and city, which server countries they are connecting to, and the
 * last 30 minutes minute by minute.
 *
 * Realtime, not the BigQuery export: the export lands once a day, and a
 * live map of yesterday is not a live map. GA4 keeps realtime for the last
 * 30 minutes only, so that is the longest window here.
 *
 * Same property and service account as the Overview's audience figures:
 * GA4_PROPERTY_G_VPN, the numeric id, with the panel's account as a Viewer.
 * The arcs need the app's `server_country` event parameter registered as an
 * event-scoped custom dimension in GA4 (Admin, Custom definitions).
 */

export interface RealtimeData {
  minutes: number;
  people: number;
  byCountry: { code: string; users: number }[];
  byCity: { city: string; code: string; users: number }[];
  /** Connections from a country to a server country. */
  routes: { from: string; to: string; count: number }[];
  /** Why the arcs are missing, when they are. */
  routesNote: string | null;
  protocols: { name: string; count: number }[];
  /** Oldest minute first, `minutes` long. */
  timeline: { people: number[]; connects: number[]; failed: number[] };
}

export type Realtime = { ok: true; data: RealtimeData } | { ok: false; reason: string };

function property(): string | null {
  const raw = (process.env.GA4_PROPERTY_G_VPN ?? '').trim();
  return raw ? raw.replace(/^properties\//, '') : null;
}

type Row = { dimensionValues?: { value?: string | null }[] | null; metricValues?: { value?: string | null }[] | null };

const dim = (r: Row, i: number) => r.dimensionValues?.[i]?.value ?? '';
const num = (r: Row, i = 0) => Number(r.metricValues?.[i]?.value ?? 0);

/** Never throws: a missing setting or permission is a named reason. */
export async function readRealtime(minutes = 30): Promise<Realtime> {
  const id = property();
  if (!id) return { ok: false, reason: 'GA4_PROPERTY_G_VPN is not set. It is the numeric property id from GA4 admin.' };
  if (/^G-/i.test(id)) return { ok: false, reason: 'GA4_PROPERTY_G_VPN holds a measurement id; the API needs the numeric property id.' };

  let api: import('@google-analytics/data').BetaAnalyticsDataClient;
  try {
    const mod = await import('@google-analytics/data');
    api = new mod.BetaAnalyticsDataClient();
  } catch {
    return { ok: false, reason: 'The GA4 client is not installed. Run `npm i @google-analytics/data`.' };
  }

  const prop = `properties/${id}`;
  const span = Math.min(Math.max(minutes, 1), 30);
  const minuteRanges = [{ name: 'window', startMinutesAgo: span - 1, endMinutesAgo: 0 }];
  const connects = { filter: { fieldName: 'eventName', stringFilter: { value: 'vpn_connect' } } };

  try {
    const [places, cities, perMinute, events, protocols] = await Promise.all([
      api.runRealtimeReport({ property: prop, minuteRanges, dimensions: [{ name: 'countryId' }], metrics: [{ name: 'activeUsers' }], limit: 250 }),
      api.runRealtimeReport({
        property: prop,
        minuteRanges,
        dimensions: [{ name: 'city' }, { name: 'countryId' }],
        metrics: [{ name: 'activeUsers' }],
        limit: 100,
      }),
      api.runRealtimeReport({ property: prop, minuteRanges, dimensions: [{ name: 'minutesAgo' }], metrics: [{ name: 'activeUsers' }] }),
      api.runRealtimeReport({
        property: prop,
        minuteRanges,
        dimensions: [{ name: 'minutesAgo' }, { name: 'eventName' }],
        metrics: [{ name: 'eventCount' }],
        dimensionFilter: {
          filter: { fieldName: 'eventName', inListFilter: { values: ['vpn_connect', 'vpn_connect_failed'] } },
        },
        limit: 200,
      }),
      api
        .runRealtimeReport({
          property: prop,
          minuteRanges,
          dimensions: [{ name: 'customEvent:protocol' }],
          metrics: [{ name: 'eventCount' }],
          dimensionFilter: connects,
        })
        .catch(() => [null] as const),
    ]);

    // Routes need the custom dimension; without it the map still works.
    let routes: RealtimeData['routes'] = [];
    let routesNote: string | null = null;
    try {
      const [r] = await api.runRealtimeReport({
        property: prop,
        minuteRanges,
        dimensions: [{ name: 'countryId' }, { name: 'customEvent:server_country' }],
        metrics: [{ name: 'eventCount' }],
        dimensionFilter: connects,
        limit: 300,
      });
      routes = (r.rows ?? [])
        .map((row) => ({ from: dim(row, 0), to: dim(row, 1).toUpperCase(), count: num(row) }))
        .filter((x) => /^[A-Z]{2}$/.test(x.from) && /^[A-Z]{2}$/.test(x.to));
    } catch {
      routesNote = 'Register server_country as an event-scoped custom dimension in GA4 to draw connection arcs.';
    }

    const series = (rows: Row[] | null | undefined, pick: (r: Row) => number | null) => {
      const out = new Array<number>(span).fill(0);
      for (const r of rows ?? []) {
        const ago = Number(dim(r, 0));
        const v = pick(r);
        if (Number.isFinite(ago) && ago < span && v != null) out[span - 1 - ago] += v;
      }
      return out;
    };

    const eventRows = events[0].rows ?? [];
    return {
      ok: true,
      data: {
        minutes: span,
        people: Number(places[0].totals?.[0]?.metricValues?.[0]?.value ?? 0) || (places[0].rows ?? []).reduce((n, r) => n + num(r), 0),
        byCountry: (places[0].rows ?? [])
          .map((r) => ({ code: dim(r, 0), users: num(r) }))
          .filter((x) => /^[A-Z]{2}$/.test(x.code))
          .sort((a, b) => b.users - a.users),
        byCity: (cities[0].rows ?? [])
          .map((r) => ({ city: dim(r, 0), code: dim(r, 1), users: num(r) }))
          .filter((x) => x.city && x.city !== '(not set)')
          .sort((a, b) => b.users - a.users),
        routes,
        routesNote,
        protocols: (protocols[0]?.rows ?? [])
          .map((r) => ({ name: dim(r, 0), count: num(r) }))
          .filter((x) => x.name && x.name !== '(not set)')
          .sort((a, b) => b.count - a.count),
        timeline: {
          people: series(perMinute[0].rows, (r) => num(r)),
          connects: series(eventRows, (r) => (dim(r, 1) === 'vpn_connect' ? num(r) : null)),
          failed: series(eventRows, (r) => (dim(r, 1) === 'vpn_connect_failed' ? num(r) : null)),
        },
      },
    };
  } catch (e) {
    const msg = (e as Error).message;
    if (/PERMISSION_DENIED|403/i.test(msg)) {
      return { ok: false, reason: 'The service account cannot read the G VPN property. Add it as a Viewer in GA4 admin, Property access management.' };
    }
    if (/NOT_FOUND|404/i.test(msg)) return { ok: false, reason: `No GA4 property ${id}. Check GA4_PROPERTY_G_VPN.` };
    return { ok: false, reason: msg };
  }
}
