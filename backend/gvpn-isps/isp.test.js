import { test } from 'node:test';
import assert from 'node:assert/strict';

import { chooseScope, cleanIsp, median, rankProviders, validResult } from './isp.js';

test('cleanIsp strips legal suffixes', () => {
  assert.equal(cleanIsp('Safaricom Limited'), 'Safaricom');
  assert.equal(cleanIsp('Airtel Networks Kenya Ltd.'), 'Airtel Networks Kenya');
  assert.equal(cleanIsp('  Zuku   Fiber  PLC '), 'Zuku Fiber');
  assert.equal(cleanIsp('Comcast Cable Communications, LLC'), 'Comcast Cable Communications');
  assert.equal(cleanIsp(undefined), '');
});

test('validResult rejects impossible numbers', () => {
  assert.deepEqual(validResult({ down: 31.27, up: 9.94, ping: 21.5 }), { down: 31.3, up: 9.9, ping: 21.5 });
  assert.equal(validResult({ down: -1, up: 5, ping: 20 }), null);
  assert.equal(validResult({ down: 50, up: 5 }), null);
  assert.equal(validResult({ down: 'x', up: 5, ping: 20 }), null);
  assert.equal(validResult(null), null);
});

test('median handles odd, even and empty', () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 3, 2]), 2.5);
  assert.equal(median([]), null);
});

test('rankProviders orders by median download and drops thin providers', () => {
  const rows = [
    ...Array.from({ length: 6 }, (_, i) => ({ isp: 'A', down: 20 + i, up: 5, ping: 30 })),
    ...Array.from({ length: 5 }, () => ({ isp: 'B', down: 50, up: 10, ping: 20 })),
    ...Array.from({ length: 2 }, () => ({ isp: 'C', down: 900, up: 900, ping: 1 })),
  ];
  const out = rankProviders(rows);
  assert.deepEqual(out.map((p) => [p.isp, p.rank]), [['B', 1], ['A', 2]]);
  assert.equal(out[1].down, 22.5);
  assert.equal(out[1].tests, 6);
});

test('chooseScope prefers the city, falls back to the country', () => {
  const two = [{ isp: 'A' }, { isp: 'B' }];
  assert.equal(chooseScope(two, two).scope, 'city');
  assert.equal(chooseScope([{ isp: 'A' }], two).scope, 'country');
  assert.equal(chooseScope([], [{ isp: 'A' }]), null);
});
