const { config } = require('./config');

const LEVELS = ['debug', 'info', 'warn', 'error'];

function log(level, message) {
  if (LEVELS.indexOf(level) < LEVELS.indexOf(config.logLevel)) return;
  console.log(`[${level}] ${message}`);
}

module.exports = { log };
