'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { PLAYGROUND_URL, windowTarget, allowPermission, permissionPrompt } = require('../src/policy.cjs');

test('tool windows and site blob exports stay in the workspace', () => {
  for (const url of [
    PLAYGROUND_URL, 'about:blank', PLAYGROUND_URL + '__runtime/42/src/database/window.html',
    'blob:' + PLAYGROUND_URL + '0f707b78'
  ]) assert.equal(windowTarget(url), 'internal', url);
});

test('other HTTP origins open externally including different ports and schemes', () => {
  for (const url of [
    'https://github.com/joomengine', 'http://playground.joomengine.org/',
    'https://playground.joomengine.org:444/', 'https://playground.joomengine.org.example.com/'
  ]) assert.equal(windowTarget(url), 'external', url);
});

test('local files, arbitrary protocols, unowned blobs and credentials stay out of window routing', () => {
  for (const url of [
    'file:///tmp/index.html', 'data:text/plain,example', 'javascript:void(0)',
    'blob:https://example.org/id', 'blob:null/id', 'https://user@playground.joomengine.org/',
    'custom:hello', 'invalid', ''
  ]) assert.equal(windowTarget(url), 'blocked', url);
});

test('workspace storage, fullscreen and clipboard writes are limited to the Playground origin', () => {
  for (const permission of ['persistent-storage', 'fullscreen', 'clipboard-sanitized-write']) {
    assert.equal(allowPermission(permission, PLAYGROUND_URL + '__site/42/instance/'), true);
    assert.equal(allowPermission(permission, 'https://example.org/'), false);
    assert.equal(allowPermission(permission, 'about:srcdoc'), false);
  }
  for (const permission of ['media', 'clipboard-read', 'openExternal', 'fileSystem']) {
    assert.equal(allowPermission(permission, PLAYGROUND_URL), false);
  }
});

test('optional local connections and clipboard reads require a native user decision', () => {
  assert.ok(permissionPrompt('clipboard-read', PLAYGROUND_URL, PLAYGROUND_URL));
  for (const permission of ['local-network', 'loopback-network', 'local-network-access']) {
    assert.ok(permissionPrompt(permission, 'about:srcdoc', PLAYGROUND_URL));
    assert.equal(allowPermission(permission, PLAYGROUND_URL), false);
    assert.equal(permissionPrompt(permission, 'https://example.org', PLAYGROUND_URL), undefined);
    assert.equal(permissionPrompt(permission, 'about:srcdoc', 'https://example.org'), undefined);
  }
  assert.equal(permissionPrompt('clipboard-read', 'about:srcdoc', PLAYGROUND_URL), undefined);
  assert.equal(permissionPrompt('media', PLAYGROUND_URL, PLAYGROUND_URL), undefined);
});
