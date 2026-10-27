/**
 * SSTP hostnames from VPN Gate's server list page.
 *
 * The CSV API (api/iphone) has no SSTP column, but the HTML list at
 * https://www.vpngate.net/en/ prints one per server that takes MS-SSTP:
 *
 *   ...<span style='font-size: 10pt;'>219.100.37.93</span>...
 *   ...SSTP Hostname :<br /><b><span ...>public-vpn-135.opengw.net</span></b>...
 *
 * Volunteers behind NAT add a port ("vpn484185679.opengw.net:1917"); the
 * rest listen on 443. Rows are matched to CSV servers by IP address.
 *
 * Pure functions, no I/O except fetchSstpHosts, so the parser is tested
 * against a saved copy of the page (sstp.test.js).
 */

const LIST_URL = 'https://www.vpngate.net/en/';

/** Each server row, from its first <td> to the closing </tr>. */
function rows(html) {
  return html.split(/<tr\b[^>]*>/i).filter((r) => /vg_table_row_\d/.test(r));
}

/**
 * IP address -> { host, port } for every server that lists an SSTP host.
 * Works with the page as served (single quotes, <br />) and as saved by a
 * browser (double quotes, <br>).
 */
export function parseSstpHosts(html) {
  const out = new Map();
  for (const row of rows(html)) {
    const sstp = row.match(/SSTP Hostname\s*:\s*<br\s*\/?>\s*<b>\s*<span[^>]*>\s*([^<\s]+)\s*<\/span>/i);
    if (!sstp) continue;
    // The second cell: hostname, then the IP on its own line.
    const ip = row.match(/<br\s*\/?>\s*<span[^>]*font-size:\s*10pt[^>]*>\s*(\d{1,3}(?:\.\d{1,3}){3})\s*<\/span>/i);
    if (!ip) continue;
    const [host, rawPort] = sstp[1].split(':');
    const port = rawPort ? Number(rawPort) : 443;
    if (!/^[a-z0-9.-]+$/i.test(host) || !Number.isInteger(port) || port < 1 || port > 65535) continue;
    out.set(ip[1], { host: host.toLowerCase(), port });
  }
  return out;
}

/**
 * Adds sstpHost and sstpPort to each server whose IP the page lists.
 * Servers it does not list are returned unchanged (OpenVPN only).
 */
export function attachSstp(servers, hosts, ipField = 'ip') {
  return servers.map((s) => {
    const hit = hosts.get(s[ipField]);
    return hit ? { ...s, sstpHost: hit.host, sstpPort: hit.port } : s;
  });
}

/**
 * Fetches and parses the list page. Never throws: a failed fetch yields an
 * empty map, so a refresh still publishes its OpenVPN servers.
 */
export async function fetchSstpHosts({ timeoutMs = 15000 } = {}) {
  try {
    const res = await fetch(LIST_URL, {
      headers: { 'user-agent': 'Mozilla/5.0 (compatible; G-VPN server list)', 'accept-language': 'en' },
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) return new Map();
    return parseSstpHosts(await res.text());
  } catch {
    return new Map();
  }
}
