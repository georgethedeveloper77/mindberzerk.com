import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  parseVpnGate, rank, quality, grade, readEndpoint, capPerCountry, MAX_PER_COUNTRY,
  fromOneConnect, withCredentials, applyOverrides, cleanOverrides,
} from './rank.js';

const cfg = (proto, port, ip) => Buffer.from(`client\ndev tun\nproto ${proto}\nremote ${ip} ${port}\n`).toString('base64');
const row = (host, ip, speed, ping, cc, sessions, proto = 'udp', port = 1195) =>
  [host, ip, 100, ping, speed, 'Country ' + cc, cc, sessions, 5 * 86_400_000, 10, 10, '2weeks', 'Op', '', cfg(proto, port, ip)].join(',');
const csv = (rows) =>
  ['*vpn_servers', '#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,OpenVPN_ConfigData_Base64', ...rows, '*'].join('\r\n');
const decode = (b64) => Buffer.from(b64, 'base64').toString();

test('parses rows and skips header and markers', () => {
  const rows = parseVpnGate(csv([row('a', '1.1.1.1', 150e6, 20, 'jp', 10)]));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].countryCode, 'JP');
  assert.equal(rows[0].speedMbps, 150);
});

test('reads protocol and port from the config', () => {
  assert.deepEqual(readEndpoint('proto tcp\nremote 1.2.3.4 443\n'), { proto: 'tcp', port: 443 });
  assert.deepEqual(readEndpoint('dev tun\n'), { proto: null, port: null });
});

test('fast, idle servers outrank slow, crowded ones', () => {
  const fast = quality({ speedMbps: 200, pingMs: 10, sessions: 5, uptimeDays: 10 });
  const slow = quality({ speedMbps: 5, pingMs: 250, sessions: 140, uptimeDays: 0.5 });
  assert.ok(fast > 90 && grade(fast) === 'fast');
  assert.ok(slow < 30 && grade(slow) === 'slow');
});

test('ranks, de-duplicates and caps per country', async () => {
  const rows = [];
  for (let i = 0; i < 12; i++) rows.push(row(`jp${i}`, `10.0.0.${i}`, (i + 1) * 10e6, 20, 'JP', 5));
  rows.push(row('jp-dup', '10.0.0.11', 120e6, 20, 'JP', 5));         // same ip/proto/port as jp11
  rows.push(row('kr', '10.1.0.1', 50e6, 30, 'KR', 5));
  const out = capPerCountry(await rank(parseVpnGate(csv(rows)), decode));
  assert.equal(out.filter((s) => s.countryCode === 'JP').length, MAX_PER_COUNTRY);
  assert.ok(out.some((s) => s.countryCode === 'KR'));
  assert.ok(out[0].quality >= out[out.length - 1].quality);
  assert.equal(new Set(out.map((s) => s.id)).size, out.length);
  assert.match(out[0].id, /^[0-9a-f]{12}$/);
});

test('OneConnect: plain and base64 configs, credentials inlined, unreadable skipped', async () => {
  const plain = 'client\nproto udp\nremote 5.6.7.8 1194\nauth-user-pass\n';
  const { rows, skipped } = fromOneConnect([
    { id: '1', serverName: 'Germany', flag_url: 'https://x/flags/de.png', ovpnConfiguration: plain, vpnUserName: 'u', vpnPassword: 'p' },
    { id: '2', serverName: 'Japan', flag_url: 'https://x/jp.svg', ovpnConfiguration: Buffer.from('remote 9.9.9.9 443\nproto tcp\n').toString('base64') },
    { id: '3', serverName: 'Odd', flag_url: '', ovpnConfiguration: 'ENCRYPTED-BLOB' },
  ]);
  assert.equal(rows.length, 2);
  assert.equal(skipped, 1);
  assert.equal(rows[0].countryCode, 'DE');
  assert.match(rows[0].config, /<auth-user-pass>\nu\np\n<\/auth-user-pass>/);
  assert.doesNotMatch(rows[0].config, /^auth-user-pass$/m);
  const ranked = await rank(rows);
  assert.ok(ranked.every((s) => s.source === 'oneconnect' && s.grade === 'good'));
});

test('withCredentials appends when the config has no auth-user-pass line', () => {
  assert.match(withCredentials('remote a 1\n', 'x', 'y'), /<auth-user-pass>\nx\ny\n<\/auth-user-pass>\n$/);
  assert.equal(withCredentials('remote a 1\n', '', ''), 'remote a 1\n');
});

test('overrides: boost, regrade, hide, pin first', () => {
  const base = [
    { id: 'aaaaaaaaaaaa', countryCode: 'JP', quality: 80 },
    { id: 'bbbbbbbbbbbb', countryCode: 'KR', quality: 50 },
    { id: 'cccccccccccc', countryCode: 'CN', quality: 90 },
  ];
  const out = applyOverrides(base, {
    pinnedServers: ['bbbbbbbbbbbb'],
    boosts: { bbbbbbbbbbbb: 30 },
    hiddenCountries: ['CN'],
    thresholds: { fast: 75, good: 40 },
  });
  assert.equal(out[0].id, 'bbbbbbbbbbbb');
  assert.equal(out[0].quality, 80);
  assert.equal(out[0].grade, 'fast');
  assert.equal(out.find((s) => s.id === 'cccccccccccc').hidden, true);
});

test('cleanOverrides drops malformed input', () => {
  const o = cleanOverrides({ hiddenServers: ['nope', 'aaaaaaaaaaaa'], boosts: { x: 5, aaaaaaaaaaaa: 99 }, thresholds: { fast: 'x' } });
  assert.deepEqual(o.hiddenServers, ['aaaaaaaaaaaa']);
  assert.deepEqual(o.boosts, { aaaaaaaaaaaa: 50 });
  assert.equal(o.thresholds.fast, 70);
  assert.equal(o.sources.oneconnect, true);
});

test('parseSstpHosts reads host and port per IP, skipping rows without SSTP', async () => {
  const { parseSstpHosts } = await import('./rank.js');
  const html = `
    <table><tr><td><a href="do_openvpn.aspx?fqdn=public-vpn-65.opengw.net&ip=219.100.37.10&tcp=443&udp=1194">OpenVPN</a></td>
      <td>MS-SSTP<br>SSTP Hostname :<br><b><span style='color: #006600;'>public-vpn-65.opengw.net</span></b></td></tr>
    <tr><td><a href="do_openvpn.aspx?fqdn=vpn123.opengw.net&ip=1.2.3.4&tcp=995&udp=0">OpenVPN</a></td>
      <td>SSTP Hostname : <b>vpn123.opengw.net:995</b></td></tr>
    <tr><td><a href="do_openvpn.aspx?fqdn=x.opengw.net&ip=5.6.7.8&tcp=443&udp=1194">OpenVPN</a></td><td>-</td></tr></table>`;
  const m = parseSstpHosts(html);
  assert.equal(m.size, 2);
  assert.deepEqual(m.get('219.100.37.10'), { host: 'public-vpn-65.opengw.net', port: 443 });
  assert.deepEqual(m.get('1.2.3.4'), { host: 'vpn123.opengw.net', port: 995 });
  assert.equal(m.get('5.6.7.8'), undefined);
});

test('protocol switches: SSTP off strips SSTP, OpenVPN off keeps only SSTP servers', async () => {
  const { applyProtocols, cleanOverrides } = await import('./rank.js');
  const servers = [{ id: 'a', sstpHost: 'x.opengw.net', sstpPort: 443 }, { id: 'b' }];
  assert.deepEqual(applyProtocols(servers, { openvpn: true, sstp: true }).map((s) => s.id), ['a', 'b']);
  assert.equal(applyProtocols(servers, { openvpn: true, sstp: false })[0].sstpHost, undefined);
  assert.deepEqual(applyProtocols(servers, { openvpn: false, sstp: true }).map((s) => s.id), ['a']);
  assert.deepEqual(cleanOverrides({ protocols: { openvpn: false, sstp: false } }).protocols, { openvpn: true, sstp: false });
});
