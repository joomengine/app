'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const os = require('node:os');
const { mkdtemp, readFile, rm } = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const { launch, waitFor } = require('./desktop-driver.cjs');
const { serveFixture } = require('./fixture-server.cjs');

async function fixtureRun(app, { marker, second, directory }) {
  await waitFor('the controlling service worker and two shared WASM workers', () => app.renderer(() => {
    if (document.body?.dataset.error) throw Error(document.body.dataset.error);
    return navigator.serviceWorker?.controller && document.body?.dataset.workers === '2';
  }));
  const key = 'joomengine-desktop-smoke';
  if (second) {
    assert.equal(await app.renderer(key => localStorage.getItem(key), key), marker);
    return;
  }
  await app.renderer((key, marker) => { localStorage.setItem(key, marker); }, key, marker);
  await app.renderer(() => {
    window.addEventListener('message', event => {
      if (event.origin === location.origin && event.source === window.tool) document.body.dataset.message = event.data;
    });
    document.querySelector('#detach').click();
  });
  await waitFor('the native tool window, its opener and shared DOM access', () => app.renderer(() =>
    document.body.dataset.message === 'tool-ready' && window.tool.document.querySelector('#tool')?.textContent === 'Detached tool'));
  assert.equal(await app.main('smokeElectron.BrowserWindow.getAllWindows().length'), 2);
  const destination = path.join(directory, 'project.bin');
  await app.captureDownload(destination);
  await app.renderer(() => document.querySelector('#export').click());
  const result = await waitFor('the Blob export', () => app.main('smokeDownload'));
  assert.deepEqual(result, { state: 'completed', filename: 'project.bin' });
  assert.deepEqual(await readFile(destination), Buffer.from([0, 255, 128, 74, 67, 66]));
}

async function run() {
  const [binary, mode] = process.argv.slice(2);
  if (!binary || (mode && mode !== '--live')) throw Error('Usage: node test/smoke.cjs <executable> [--live]');
  const directory = await mkdtemp(path.join(os.tmpdir(), 'joomengine-smoke-'));
  const profile = path.join(directory, 'profile');
  const options = { marker: 'Desktop-' + randomUUID(), directory };
  let server;
  try {
    if (!mode) server = await serveFixture(directory);
    const test = mode ? require('./live-playground.cjs').liveRun : fixtureRun;
    for (const second of [false, true]) {
      const app = await launch(path.resolve(binary), profile, server?.args);
      try {
        await test(app, { ...options, second });
      } finally { await app.close(); }
    }
    console.log(mode ? 'Live JCB dashboard, saved site, detached database window and complete site export passed.'
      : 'Desktop service worker, shared WASM memory, native popup, download and persistent restart passed.');
  } finally {
    await server?.close();
    await rm(directory, { recursive: true, force: true, maxRetries: 8, retryDelay: 250 });
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
