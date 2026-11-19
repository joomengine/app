'use strict';

const net = require('node:net');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const { realpath } = require('node:fs/promises');
const path = require('node:path');
const { setTimeout: delay } = require('node:timers/promises');

async function waitFor(label, probe, timeout = 30000) {
  const deadline = Date.now() + timeout;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const result = await probe();
      if (result) return result;
    } catch (error) { lastError = error; }
    await delay(200);
  }
  throw Error('Timed out waiting for ' + label + (lastError ? ': ' + lastError.message : ''));
}

async function loopbackPort() {
  const server = net.createServer().listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();
  await new Promise(resolve => server.close(resolve));
  return port;
}

// Connect only to the packaged app launched by this test. The inspector and
// certificate override are command-line options on the test process alone.
async function launch(executable, profile, args = []) {
  const port = await loopbackPort();
  const child = spawn(executable, ['--inspect=127.0.0.1:' + port,
    '--user-data-dir=' + profile, '--lang=en-US', ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  function log(chunk) { output = (output + chunk.toString()).slice(-6000); }
  child.stderr.on('data', log);
  child.stdout.on('data', log);
  const exited = once(child, 'exit');
  let socket;
  try {
    const endpoint = await Promise.race([waitFor('the Electron inspector', async () => {
      const response = await fetch('http://127.0.0.1:' + port + '/json/list', { signal: AbortSignal.timeout(1000) });
      const targets = await response.json();
      return targets[0]?.webSocketDebuggerUrl;
    }), exited.then(([code, signal]) => { throw Error('JoomEngine exited before startup (' + (signal || code) + ')'); })]);
    socket = new WebSocket(endpoint);
    await once(socket, 'open', { signal: AbortSignal.timeout(5000) });
    let id = 0;
    async function main(expression) {
      const request = ++id;
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => { cleanup(); reject(Error('Electron evaluation timed out')); }, 25000);
        function cleanup() { clearTimeout(timer); socket.removeEventListener('message', message); }
        function message(event) {
          const reply = JSON.parse(event.data);
          if (reply.id !== request) return;
          cleanup();
          if (reply.error || reply.result?.exceptionDetails) {
            reject(Error(reply.error?.message || reply.result.exceptionDetails.exception?.description || reply.result.exceptionDetails.text));
          } else resolve(reply.result.result.value);
        }
        socket.addEventListener('message', message);
        socket.send(JSON.stringify({ id: request, method: 'Runtime.evaluate',
          params: { expression, awaitPromise: true, returnByValue: true, includeCommandLineAPI: true } }));
      });
    }
    await waitFor('the first native window', () => main(`
      globalThis.smokeElectron = require('electron');
      globalThis.smokeOwner = smokeElectron.BrowserWindow.getAllWindows()[0];
      Boolean(smokeOwner)
    `));
    const sessionDir = await main('smokeOwner.webContents.session.storagePath');
    assert.ok(sessionDir, 'The workspace must use a persistent session');
    // macOS exposes its temp directory through /var -> /private/var.
    const relative = path.relative(await realpath(profile), await realpath(sessionDir));
    assert.ok(relative && !relative.startsWith('..') && !path.isAbsolute(relative),
      'The workspace must use a persistent partition in its private test profile: ' + sessionDir);
    return {
      main,
      renderer(fn, ...params) {
        const script = '(' + fn.toString() + ')(...' + JSON.stringify(params) + ')';
        return main('smokeOwner.webContents.executeJavaScript(' + JSON.stringify(script) + ', true)');
      },
      async captureDownload(destination) {
        await main(`
          globalThis.smokeDownload = null;
          smokeOwner.webContents.session.once('will-download', (_event, item) => {
            item.setSavePath(${JSON.stringify(destination)});
            const filename = item.getFilename();
            item.once('done', (_event, state) => { globalThis.smokeDownload = { state, filename }; });
          }); true
        `);
      },
      async close() {
        try {
          // Electron flushes the persistent browser session during normal quit.
          await main("setTimeout(() => smokeElectron.app.quit(), 50); true");
        } finally {
          socket.close();
          const closed = await Promise.race([exited.then(() => true), delay(5000, false, { ref: false })]);
          if (!closed) {
            child.kill('SIGKILL');
            await exited;
            throw Error('JoomEngine did not exit after app.quit()');
          }
        }
      }
    };
  } catch (error) {
    socket?.close();
    child.kill('SIGKILL');
    throw Error(error.message + '\n' + output, { cause: error });
  }
}

module.exports = { launch, waitFor };
