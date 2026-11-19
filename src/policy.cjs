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

function allowPermission(permission, requestingURL) {
  if (!workspacePermissions.has(permission)) return false;
  try {
    return new URL(requestingURL).origin === PLAYGROUND_ORIGIN;
  } catch {
    return false;
  }
}

module.exports = { PLAYGROUND_URL, PARTITION, windowTarget, allowPermission };
