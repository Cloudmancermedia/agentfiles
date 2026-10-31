const http = require('http');
const { config } = require('./config');
const { log } = require('./log');

function start() {
  const server = http.createServer((req, res) => res.end('ok'));
  server.listen(config.port, () => log('info', `listening on ${config.port}`));
  return server;
}

module.exports = { start };
