/**
 * gvpn-whoami: answers "what does the internet see when this device
 * connects?" for G VPN's "Am I protected?" check.
 *
 * Everything comes from Cloudflare's own request metadata (request.cf), so
 * there is no third-party IP database and no API key. Nothing is stored:
 * no KV, no logs (observability is off in wrangler.toml), no analytics.
 */
/**
 * Browsers allowed to read the answer: the G VPN landing shows a visitor what
 * sites see for them. Only the caller's own request metadata is ever returned,
 * so this widens nothing; the list just keeps other sites from embedding it.
 */
const ALLOWED_ORIGINS = new Set([
  'https://mindberzerk.com',
  'https://www.mindberzerk.com',
  'http://localhost:3000',
]);

/** CORS headers for an allowed Origin, none otherwise (the app sends none). */
function corsHeaders(request) {
  const origin = request.headers.get('Origin');
  if (!origin || !ALLOWED_ORIGINS.has(origin)) return {};
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET',
    'access-control-max-age': '86400',
  };
}

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: { ...corsHeaders(request), vary: 'Origin' } });
    }
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }
    const cf = request.cf ?? {};
    const body = {
      ip: request.headers.get('CF-Connecting-IP'),
      country: cf.country ?? null,
      city: cf.city ?? null,
      region: cf.region ?? null,
      asn: cf.asn ?? null,
      org: cf.asOrganization ?? null,
      colo: cf.colo ?? null,
      // City-level only, from Cloudflare's own geo data. Places the "you are
      // here" pin on the globe without asking for location permission.
      latitude: cf.latitude ? Number(cf.latitude) : null,
      longitude: cf.longitude ? Number(cf.longitude) : null,
    };
    return new Response(JSON.stringify(body), {
      headers: {
        'content-type': 'application/json',
        // Never cached: the answer changes the moment the VPN connects.
        'cache-control': 'no-store',
        vary: 'Origin',
        ...corsHeaders(request),
      },
    });
  },
};
