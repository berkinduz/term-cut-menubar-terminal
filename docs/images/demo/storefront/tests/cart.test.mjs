import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cartTotal } from '../src/cart.mjs';

test('calculates a subtotal in cents', () => {
  assert.equal(cartTotal([{ price: 1299, qty: 2 }]).total, 2598);
});
test('rounds a percentage discount', () => {
  assert.deepEqual(cartTotal([{ price: 1299, qty: 2 }, { price: 399, qty: 1 }], 0.1),
    { subtotal: 2997, savings: 300, total: 2697 });
});
test('handles an empty cart', () => {
  assert.equal(cartTotal([]).total, 0);
});
test('rejects an invalid discount', () => {
  for (const discount of [-0.1, 1.1, NaN]) {
    assert.throws(() => cartTotal([], discount), RangeError);
  }
});
