// Run: node --test sstp.test.js   (from backend/gvpn-servers)
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { test } from 'node:test';

import { attachSstp, parseSstpHosts } from './sstp.js';

const row = (ip, sstp) =>
  `<tr>\n<td class='vg_table_row_1' style='text-align: center;'><img src='../images/flags/JP.png' /><br>Japan</td>` +
  `<td class='vg_table_row_1'><b><span style='font-size: 9pt;'>h.opengw.net</span></b><br><span style='font-size: 10pt;'>${ip}</span><br></td>` +
  (sstp
    ? `<td class='vg_table_row_1'><p><span style='font-size: 8pt;' >SSTP Hostname :<br /><b><span style='color: #006600;' >${sstp}</span></b></span></p></td>`
    : `<td class='vg_table_row_1'></td>`) +
  `</tr>\n`;

test('host on 443 when no port is given', () => {
  const m = parseSstpHosts(row('219.100.37.93', 'public-vpn-135.opengw.net'));
  assert.deepEqual(m.get('219.100.37.93'), { host: 'public-vpn-135.opengw.net', port: 443 });
});

test('explicit port is kept', () => {
  const m = parseSstpHosts(row('1.2.3.4', 'vpn484185679.opengw.net:1917'));
  assert.deepEqual(m.get('1.2.3.4'), { host: 'vpn484185679.opengw.net', port: 1917 });
});

test('rows without SSTP are skipped', () => {
  assert.equal(parseSstpHosts(row('5.6.7.8', null)).size, 0);
});

test('browser-saved markup (double quotes, <br>) parses too', () => {
  const html = row('9.9.9.9', 'a.opengw.net:995').replaceAll("'", '"').replaceAll('<br />', '<br>');
  assert.deepEqual(parseSstpHosts(html).get('9.9.9.9'), { host: 'a.opengw.net', port: 995 });
});

test('attachSstp adds fields only to listed servers', () => {
  const hosts = new Map([['1.1.1.1', { host: 'x.opengw.net', port: 443 }]]);
  const out = attachSstp([{ ip: '1.1.1.1' }, { ip: '2.2.2.2' }], hosts);
  assert.deepEqual(out, [{ ip: '1.1.1.1', sstpHost: 'x.opengw.net', sstpPort: 443 }, { ip: '2.2.2.2' }]);
});

// The real page, when a copy is saved next to this file.
test('saved vpngate.html: most rows carry an SSTP host', { skip: !existsSync('./vpngate.html') }, () => {
  const m = parseSstpHosts(readFileSync('./vpngate.html', 'utf8'));
  assert.ok(m.size > 50, `only ${m.size} SSTP hosts found`);
});
