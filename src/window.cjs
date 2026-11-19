'use strict';

const path = require('node:path');
const { app, BrowserWindow, clipboard, dialog, Menu, session, shell } = require('electron');
const { PLAYGROUND_URL, PARTITION, windowTarget, allowPermission } = require('./policy.cjs');

const webPreferences = {
  partition: PARTITION,
  sandbox: true,
  contextIsolation: true,
  nodeIntegration: false,
  webviewTag: false,
  webSecurity: true,
  // Detached tools still depend on the owner window's PHP and MariaDB workers.
  backgroundThrottling: false
};

function openExternal(url) {
  // Callers have already classified this as an HTTP(S) address.
  shell.openExternal(new URL(url).href).catch(error => {
    dialog.showErrorBox('Could not open the link', error.message);
  });
}

function showContextMenu(contents, params) {
  const items = [];
  if (params.isEditable) {
    for (const [role, flag] of [
      ['undo', 'canUndo'], ['redo', 'canRedo'], ['cut', 'canCut'],
      ['copy', 'canCopy'], ['paste', 'canPaste'], ['selectAll', 'canSelectAll']
    ]) {
      items.push({ role, enabled: params.editFlags[flag] });
    }
  } else if (params.selectionText) {
    items.push({ role: 'copy' });
  }
  if (params.linkURL && windowTarget(params.linkURL) !== 'blocked' && params.linkURL !== 'about:blank') {
    if (items.length) items.push({ type: 'separator' });
    items.push({ label: 'Copy Link', click: () => clipboard.writeText(params.linkURL) });
    items.push({ label: 'Save Link As…', click: () => contents.downloadURL(params.linkURL) });
  }
  if (items.length) Menu.buildFromTemplate(items).popup({ window: BrowserWindow.fromWebContents(contents) });
}

function configureContents(contents) {
  contents.setWindowOpenHandler(({ url }) => {
    const target = windowTarget(url);
    if (target === 'internal') {
      // Let Chromium create the window. Replacing it with loadURL() breaks
      // window.opener, postMessage and direct DOM access in Code and Adminer.
      return { action: 'allow', overrideBrowserWindowOptions: { webPreferences } };
    }
    if (target === 'external') openExternal(url);
    return { action: 'deny' };
  });
  function navigate(event) {
    if (!event.isMainFrame) return;
    const target = windowTarget(event.url);
    if (target === 'internal') return;
    event.preventDefault();
    if (target === 'external') openExternal(event.url);
  }
  contents.on('will-navigate', navigate);
  contents.on('will-redirect', navigate);
  contents.on('context-menu', (_event, params) => showContextMenu(contents, params));
  contents.on('will-prevent-unload', event => {
    const window = BrowserWindow.fromWebContents(contents);
    if (!window) return;
    const choice = dialog.showMessageBoxSync(window, {
      type: 'question',
      message: 'Leave this workspace?',
      detail: 'There may be unsaved changes.',
      buttons: ['Stay', 'Leave'],
      defaultId: 0,
      cancelId: 0
    });
    if (choice === 1) event.preventDefault();
  });
}

let workspaceSession;
function prepareSession() {
  if (workspaceSession) return;
  workspaceSession = session.fromPartition(PARTITION);
  workspaceSession.setPermissionCheckHandler((_contents, permission, origin) =>
    allowPermission(permission, origin));
  workspaceSession.setPermissionRequestHandler((_contents, permission, callback, details) =>
    callback(allowPermission(permission, details.requestingUrl)));

  // Install controls before the first navigation, including in nested popups.
  // No request or download interceptor: workers, external resources and the
  // standard save dialog use Chromium's original networking and storage paths.
  app.on('web-contents-created', (_event, contents) => {
    if (contents.getType() === 'window' && contents.session === workspaceSession) configureContents(contents);
  });
}

function createPlaygroundWindow() {
  prepareSession();
  const window = new BrowserWindow({
    title: 'JoomEngine',
    width: 1400,
    height: 900,
    icon: path.join(app.getAppPath(), 'assets', 'joomengine.png'),
    webPreferences
  });
  const showRecovery = () => {
    if (!window.isDestroyed()) void window.loadFile(path.join(__dirname, 'offline.html'));
  };
  window.webContents.on('did-fail-load', (_event, code, _description, url, isMainFrame) => {
    // Controlled service-worker reloads and downloads can cancel a navigation.
    if (isMainFrame && code !== -3 && windowTarget(url) === 'internal') showRecovery();
  });
  window.webContents.on('render-process-gone', (_event, details) => {
    if (details.reason !== 'clean-exit') showRecovery();
  });
  void window.loadURL(PLAYGROUND_URL);
  return window;
}

module.exports = { createPlaygroundWindow };
