const { config } = require('./config');

// Calls fn until it succeeds, up to config.retries attempts in total.
async function retry(fn) {
  let lastError;
  for (let attempt = 0; attempt <= config.retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      await new Promise((r) => setTimeout(r, config.retryDelayMs));
    }
  }
  throw lastError;
}

module.exports = { retry };
