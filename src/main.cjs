'use strict';

const { app, Menu, shell } = require('electron');
const { createPlaygroundWindow } = require('./window.cjs');

app.setName('JoomEngine');
if (process.platform === 'win32') app.setAppUserModelId('org.joomengine.app');

let owner;
function showOwner() {
  if (!owner || owner.isDestroyed()) owner = createPlaygroundWindow();
  if (owner.isMinimized()) owner.restore();
  owner.show();
  owner.focus();
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => { if (app.isReady()) showOwner(); });
  app.on('activate', () => { if (app.isReady()) showOwner(); });
  app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
  app.whenReady().then(() => {
    Menu.setApplicationMenu(Menu.buildFromTemplate([
      ...(process.platform === 'darwin' ? [{ role: 'appMenu' }] : []),
      { role: 'fileMenu' },
      { role: 'editMenu' },
      { role: 'viewMenu' },
      { role: 'windowMenu' },
      {
        role: 'help',
        submenu: [
          { label: 'Playground Guide', click: () => shell.openExternal('https://github.com/joomengine/playground#readme') },
          { label: 'Desktop Support', click: () => shell.openExternal('https://github.com/joomengine/app/issues') },
          ...(process.platform === 'darwin' ? [] : [{ type: 'separator' }, { role: 'about' }])
        ]
      }
    ]));
    showOwner();
  });
}
