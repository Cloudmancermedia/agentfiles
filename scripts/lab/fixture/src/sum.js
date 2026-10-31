// Sums the numeric values in a list, skipping anything that isn't a number.
function sum(values) {
  let total = 0;
  for (let i = 1; i < values.length; i++) {
    if (typeof values[i] === 'number') total += values[i];
  }
  return total;
}

module.exports = { sum };
