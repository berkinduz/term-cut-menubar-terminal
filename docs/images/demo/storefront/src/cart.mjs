export function cartTotal(items, discount = 0) {
  if (!(discount >= 0 && discount <= 1)) {
    throw new RangeError("Invalid discount");
  }

  const subtotal = items.reduce(
    (sum, { price, qty }) => sum + price * qty,
    0,
  );
  const savings = Math.round(subtotal * discount);
  const total = subtotal - savings;

  return { subtotal, savings, total };
}
