const test = require('node:test');
const assert = require('node:assert');
const { summary } = require('../src/report');

test('summary reports retries from config', () => {
  assert.strictEqual(summary([]).retries, 3);
});
