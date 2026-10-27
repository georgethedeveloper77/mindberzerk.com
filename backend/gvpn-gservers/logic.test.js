import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  busyPercent, dayKey, newPhoneBlock, cleanSettings, hasRoom, isIdle, keyFromPath, keyToPath, lastActive, orderRoot, parseHttpResponse,
} from './logic.js';

test('settings: defaults, clamping, and junk ignored', () => {
  const d = cleanSettings(null);
  assert.deepEqual([d.enabled, d.access, d.limit, d.idleDays], [true, 'everyone', 5, 30]);
  assert.deepEqual([d.newPerIpMinute, d.newPerIpDay, d.newPerDay, d.maxPerServer], [5, 20, 500, 1000]);
  const c = cleanSettings({ enabled: false, access: 'pro', limit: 99, idleDays: 1, newPerDay: 0, maxPerServer: 999999 });
  assert.deepEqual([c.enabled, c.access, c.limit, c.idleDays, c.newPerDay, c.maxPerServer], [false, 'pro', 20, 7, 1, 60000]);
  assert.equal(cleanSettings({ access: 'anyone' }).access, 'everyone');
  assert.equal(cleanSettings({ limit: 2.5 }).limit, 5);
});

test('busy percent from load and CPUs', () => {
  assert.equal(busyPercent({ load1: 0.12, cpus: 1 }), 12);
  assert.equal(busyPercent({ load1: 5, cpus: 2 }), 100);
  assert.equal(busyPercent({}), null);
});

test('order root survives renewals', () => {
  assert.equal(orderRoot('GPA.1234-5678-9012-34567..3'), 'GPA.1234-5678-9012-34567');
  assert.equal(orderRoot('GPA.1234-5678-9012-34567'), 'GPA.1234-5678-9012-34567');
  assert.equal(orderRoot(undefined), null);
});

test('device limit counts the other phones only', () => {
  assert.equal(hasRoom(4, 5), true);
  assert.equal(hasRoom(5, 5), false);
});

test('idle: newest of handshake, hello and creation', () => {
  const day = 86_400_000;
  const now = 100 * day;
  assert.equal(lastActive(50 * 86_400, { last_seen: 10 * day, created_at: 5 * day }), 50 * day);
  assert.equal(isIdle(0, { last_seen: 0, created_at: 60 * day }, now, 30), true);
  assert.equal(isIdle(0, { last_seen: 80 * day, created_at: 1 * day }, now, 30), false);
  assert.equal(isIdle(95 * 86_400, null, now, 30), false);
});

test('keys survive URL paths', () => {
  const k = 'ab+/cd'.padEnd(43, 'x') + '=';
  assert.equal(keyFromPath(keyToPath(k)), k);
  assert.ok(!keyToPath(k).includes('/'));
});

test('agent responses: plain and chunked', () => {
  const plain = parseHttpResponse('HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"ok":true}');
  assert.deepEqual(plain, { status: 200, body: '{"ok":true}' });
  const chunked = parseHttpResponse('HTTP/1.1 401 X\r\nTransfer-Encoding: chunked\r\n\r\n5\r\n{"a":\r\n2\r\n1}\r\n0\r\n\r\n');
  assert.deepEqual(chunked, { status: 401, body: '{"a":1}' });
});

test('new-phone limits: server full first, then daily total, then the address', () => {
  const s = cleanSettings(null);
  const ok = { onServer: 10, newToday: 10, fromIpToday: 1, fromIpMinute: 0 };
  assert.equal(newPhoneBlock(ok, s), null);
  assert.equal(newPhoneBlock({ ...ok, onServer: 1000 }, s), 'server_full');
  assert.equal(newPhoneBlock({ ...ok, newToday: 500 }, s), 'busy');
  assert.equal(newPhoneBlock({ ...ok, fromIpToday: 20 }, s), 'busy');
  assert.equal(newPhoneBlock({ ...ok, fromIpMinute: 5 }, s), 'busy');
  assert.equal(dayKey(Date.UTC(2026, 9, 25, 23, 59)), '2026-10-25');
});
