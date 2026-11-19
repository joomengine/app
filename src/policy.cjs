'use strict';

const PLAYGROUND_URL = 'https://playground.joomengine.org/';
const PLAYGROUND_ORIGIN = new URL(PLAYGROUND_URL).origin;
const PARTITION = 'persist:joomengine';

function windowTarget(rawURL) {
  if (rawURL === 'about:blank') return 'internal';
  let url;
  try {
    url = new URL(rawURL);
  } catch {
    return 'blocked';
  }
  if (url.username || url.password) return 'blocked';
  if (url.origin === PLAYGROUND_ORIGIN && ['https:', 'blob:'].includes(url.protocol)) {
    return 'internal';
  }
  if (url.protocol === 'https:' || url.protocol === 'http:') return 'external';
  return 'blocked';
}

const workspacePermissions = new Set(['clipboard-sanitized-write', 'fullscreen', 'persistent-storage']);

function isPlaygroundPage(rawURL) {
  try {
    const url = new URL(rawURL);
    return url.origin === PLAYGROUND_ORIGIN && !url.username && !url.password;
  } catch {
    return false;
  }
}

function allowPermission(permission, requestingURL) {
  return workspacePermissions.has(permission) && isPlaygroundPage(requestingURL);
}

function permissionPrompt(permission, requestingURL, ownerURL) {
  if (!isPlaygroundPage(ownerURL)) return;
  if (permission === 'clipboard-read' && isPlaygroundPage(requestingURL)) {
    return 'Allow this workspace to read your clipboard?';
  }
  // The optional local AI provider runs inside Playground's sandboxed srcdoc.
  if (!isPlaygroundPage(requestingURL) && requestingURL !== 'about:srcdoc') return;
  if (permission === 'loopback-network') return 'Allow this workspace to connect to services on this computer?';
  if (permission === 'local-network' || permission === 'local-network-access') {
    return 'Allow this workspace to connect to services on your local network?';
  }
}

module.exports = { PLAYGROUND_URL, PARTITION, windowTarget, allowPermission, permissionPrompt };
