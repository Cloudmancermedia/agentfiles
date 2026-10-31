const config = {
  port: Number(process.env.PORT) || 8080,
  retries: 3,
  retryDelayMs: 200,
  logLevel: process.env.LOG_LEVEL || 'info',
};

module.exports = { config };
