'use strict';

const path = require('node:path');
const assert = require('node:assert/strict');
const { open } = require('node:fs/promises');
const { waitFor } = require('./desktop-driver.cjs');

const deploymentTimeout = 10 * 60 * 1000;

// Exercise the published website and its normal controls in a disposable
// desktop profile. All Joomla and database changes belong to this local site.
async function dashboard(app) {
  await waitFor('the deployed JCB dashboard', () => app.renderer(() => {
    const frame = document.querySelector('#site-frame');
    const error = document.querySelector('#error-view:not([hidden])');
    if (error) throw Error(error.querySelector('#error-message')?.textContent || 'Site could not start');
    return navigator.serviceWorker?.controller && crossOriginIsolated && !frame?.hidden &&
      /component builder dashboard/i.test(frame?.contentDocument?.body?.innerText || '');
  }), deploymentTimeout);
  console.log('JCB dashboard rendered.');
}

async function database(app) {
  await app.renderer(() => document.querySelector('#database-button').click());
  await waitFor('Adminer tables', () => app.renderer(() => {
    const database = document.querySelector('iframe[title="Database"]')?.contentDocument;
    return database?.querySelector('#content')?.textContent.includes('Tables');
  }), 90000);
}

async function queryDatabase(app, marker, second) {
  await app.renderer(() => {
    const db = document.querySelector('iframe[title="Database"]').contentDocument;
    const link = [...db.querySelectorAll('a')].find(element => element.textContent.trim() === 'SQL command');
    if (!link) throw Error('Adminer SQL command link is missing');
    link.click();
  });
  await waitFor('the Adminer SQL editor', () => app.renderer(() =>
    Boolean(document.querySelector('iframe[title="Database"]').contentDocument?.querySelector('pre.sqlarea[contenteditable="true"]'))));
  await app.renderer((marker, second) => {
    const db = document.querySelector('iframe[title="Database"]').contentDocument;
    const editor = db.querySelector('pre.sqlarea[contenteditable="true"]');
    const read = 'SELECT value FROM desktop_smoke;';
    const write = "CREATE TABLE desktop_smoke (value VARCHAR(80)); INSERT INTO desktop_smoke VALUES ('" + marker + "'); ";
    editor.focus();
    db.execCommand('selectAll');
    if (!db.execCommand('insertText', false, second ? read : write + read)) throw Error('Adminer editor rejected input');
  }, marker, second);
  // Jush asynchronously synchronizes the highlighted editor to the textarea
  // that Adminer actually posts. Wait for the typed SQL to reach the form.
  await waitFor('the SQL form value', () => app.renderer(() => {
    const db = document.querySelector('iframe[title="Database"]').contentDocument;
    return db.querySelector('textarea[name="query"]')?.value.includes('SELECT value FROM desktop_smoke;');
  }));
  await app.renderer(() => {
    const db = document.querySelector('iframe[title="Database"]').contentDocument;
    const execute = [...db.querySelectorAll('input[type="submit"],button')].find(button =>
      (button.value || button.textContent).trim() === 'Execute');
    if (!execute) throw Error('Adminer Execute button is missing');
    execute.click();
  });
  await waitFor(second ? 'the saved database row after restart' : 'the new database row', () => app.renderer(marker => {
    const db = document.querySelector('iframe[title="Database"]').contentDocument;
    const error = db?.querySelector('.error');
    if (error) throw Error(error.textContent);
    return [...(db?.querySelectorAll('#content td') || [])].some(cell => cell.textContent.trim() === marker);
  }, marker), 90000);
  console.log(second ? 'Read the saved MariaDB row after restarting JoomEngine.' : 'Saved a row in the running JCB site.');
}

async function detach(app) {
  await app.renderer(() => {
    const button = document.querySelector('[aria-label="Detach database viewer"]');
    if (!button) throw Error('Database detach action is missing');
    button.click();
  });
  await waitFor('the detached Adminer window and its owner', () => app.main(`
    (async () => {
      const child = smokeElectron.BrowserWindow.getAllWindows().find(win => win !== smokeOwner);
      return child && child.webContents.executeJavaScript("Boolean(window.opener && document.querySelector('iframe')?.contentDocument?.querySelector('#content'))");
    })()
  `), 60000);
  await app.main(`
    smokeElectron.BrowserWindow.getAllWindows().find(win => win !== smokeOwner).webContents.executeJavaScript(
      "document.querySelector('[aria-label=\\"Return to owner tab\\"]').click()", true)
  `);
  await waitFor('redocking Adminer', () => app.main('smokeElectron.BrowserWindow.getAllWindows().length === 1'));
  console.log('Detached and redocked Adminer.');
}

async function exportSite(app, directory) {
  const destination = path.join(directory, 'complete-site.zip');
  await app.captureDownload(destination);
  await app.renderer(() => {
    document.querySelector('#download-dialog-button').click();
    const format = document.querySelector('#export-format');
    format.value = 'bundle';
    format.dispatchEvent(new Event('change'));
    document.querySelector('#export-button').click();
  });
  const item = await waitFor('the complete Joomla site download', () => app.main('smokeDownload'), deploymentTimeout);
  assert.equal(item.state, 'completed');
  assert.match(item.filename, /\.zip$/i);
  const file = await open(destination);
  try {
    const { size } = await file.stat();
    assert.ok(size > 1024 * 1024, 'Export must contain Joomla files and the database');
    // The Playground exporter generates a ZIP32 bundle with no archive comment.
    const end = Buffer.alloc(22);
    assert.equal((await file.read(end, 0, end.length, size - end.length)).bytesRead, end.length);
    assert.equal(end.readUInt32LE(0), 0x06054b50, 'Complete ZIP central directory is missing');
    const directorySize = end.readUInt32LE(12);
    const directoryOffset = end.readUInt32LE(16);
    assert.equal(directoryOffset + directorySize, size - end.length);
    const entries = Buffer.alloc(directorySize);
    assert.equal((await file.read(entries, 0, entries.length, directoryOffset)).bytesRead, entries.length);
    const filenames = new Set();
    for (let offset = 0; offset < entries.length;) {
      assert.equal(entries.readUInt32LE(offset), 0x02014b50);
      const nameLength = entries.readUInt16LE(offset + 28);
      const extraLength = entries.readUInt16LE(offset + 30);
      const commentLength = entries.readUInt16LE(offset + 32);
      filenames.add(entries.toString('utf8', offset + 46, offset + 46 + nameLength));
      offset += 46 + nameLength + extraLength + commentLength;
    }
    for (const required of ['site/configuration.php', 'database.sql', 'export.json']) {
      assert.ok(filenames.has(required), 'The downloaded site bundle is missing ' + required);
    }
  } finally { await file.close(); }
  console.log('Downloaded the complete site bundle.');
}

async function liveRun(app, { marker, directory, second }) {
  await dashboard(app);
  await database(app);
  if (!second) await detach(app);
  await queryDatabase(app, marker, second);
  if (!second) await exportSite(app, directory);
  await waitFor('the on-disk Playground checkpoint', () => app.renderer(() => {
    const state = document.querySelector('#save-state')?.textContent || '';
    if (/not yet saved|quota/i.test(state)) throw Error(state);
    return /^saved locally/i.test(state);
  }), deploymentTimeout);
}

module.exports = { liveRun };
