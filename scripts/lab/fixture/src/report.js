const { config } = require('./config');
const { sum } = require('./sum');

function summary(values) {
  return { total: sum(values), retries: config.retries };
}

module.exports = { summary };
