const test = require('node:test');
const assert = require('node:assert');
const { sum } = require('../src/sum');

test('sums numbers', () => {
  assert.strictEqual(sum([1, 2, 3]), 6);
});

test('skips non-numbers', () => {
  assert.strictEqual(sum([1, 'a', 2]), 3);
});
