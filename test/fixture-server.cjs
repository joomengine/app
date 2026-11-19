'use strict';

const https = require('node:https');
const path = require('node:path');
const { readFileSync, writeFileSync } = require('node:fs');
const { createHash, X509Certificate } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { once } = require('node:events');

const domain = 'playground.joomengine.org';

async function serveFixture(directory) {
  const keyPath = path.join(directory, 'fixture.key');
  const certPath = path.join(directory, 'fixture.crt');
  // LibreSSL on macOS and OpenSSL on Windows/Linux accept the same config.
  const configPath = path.join(directory, 'openssl.cnf');
  writeFileSync(configPath, [
    '[req]', 'prompt=no', 'distinguished_name=subject', 'x509_extensions=extensions',
    '[subject]', 'CN=' + domain, '[extensions]', 'subjectAltName=DNS:' + domain
  ].join('\n') + '\n');
  execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
    '-config', configPath,
    '-keyout', keyPath, '-out', certPath], { stdio: ['ignore', 'ignore', 'pipe'] });
  const cert = readFileSync(certPath);
  const publicKey = new X509Certificate(cert).publicKey.export({ type: 'spki', format: 'der' });
  const pin = createHash('sha256').update(publicKey).digest('base64');
  const files = new Map(['index.html', 'action.html', 'service-worker.mjs', 'worker.mjs'].map(name =>
    [name, readFileSync(path.join(__dirname, 'fixture', name))]));
  const server = https.createServer({ cert, key: readFileSync(keyPath) }, (req, res) => {
    const name = req.url === '/' ? 'index.html' : req.url.slice(1);
    if (req.headers.host !== domain || !files.has(name)) {
      res.writeHead(404).end();
      return;
    }
    res.setHeader('Content-Type', name.endsWith('.html') ? 'text/html' : 'text/javascript');
    res.setHeader('Cache-Control', 'no-store');
    res.end(files.get(name));
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return {
    args: [
      '--no-proxy-server',
      '--host-resolver-rules=MAP ' + domain + ' 127.0.0.1:' + server.address().port + ', MAP * ~NOTFOUND, EXCLUDE localhost',
      '--ignore-certificate-errors-spki-list=' + pin
    ],
    close() { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); }
  };
}
module.exports = { serveFixture };
