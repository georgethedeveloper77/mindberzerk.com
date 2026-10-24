/**
 * gvpn-whoami: answers "what does the internet see when this device
 * connects?" for G VPN's "Am I protected?" check.
 *
 * Everything comes from Cloudflare's own request metadata (request.cf), so
 * there is no third-party IP database and no API key. Nothing is stored:
 * no KV, no logs (observability is off in wrangler.toml), no analytics.
 */
export default {
  async fetch(request) {
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
      },
    });
  },
};
