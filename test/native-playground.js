// The native QA target injects this script into the owner only. The installed
// application always loads the hosted Playground with its normal web settings.
(async () => {
  if (window !== window.top || window.opener || location.origin !== 'https://playground.joomengine.org') return;
  const config = __JOOMENGINE_QA_CONFIGURATION__;
  const signal = (command, detail) => {
    document.title = 'JE-QA/' + config.id + '/' + command + '/' + String(detail).replace(/[\r\n]/g, ' ').slice(0, 1400);
  };
  const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
  const element = id => document.getElementById(id);
  function dashboardState() {
    const frame = element('site-frame');
    const state = {
      controller: Boolean(navigator.serviceWorker?.controller), isolated: Boolean(globalThis.crossOriginIsolated),
      policy: new URL(location.href).searchParams.get('__je_coep')?.split(':').pop(),
      frame: Boolean(frame), hidden: frame?.hidden
    };
    if (!frame) return state;
    try {
      const doc = frame.contentDocument;
      const url = new URL(frame.contentWindow.location.href);
      state.route = url.pathname.replace(/(__site\/)[^/]+\/[^/]+/g, '$1…') + (url.searchParams.has('option') ? '?option=' + url.searchParams.get('option') : '');
      state.document = doc?.readyState;
      state.title = doc?.title?.slice(0, 100);
      state.headings = [...(doc?.querySelectorAll('h1,h2') || [])].slice(0, 5).map(node => node.textContent.trim().slice(0, 70));
      state.login = Boolean(doc?.querySelector('form#login-form input[name="passwd"],input[autocomplete="current-password"]'));
      state.jcbLinks = doc?.querySelectorAll('a[href*="option=com_componentbuilder"][href*="view="]').length || 0;
      state.body = doc?.body?.innerText?.trim().replace(/\s+/g, ' ').slice(0, 140);
    } catch (error) { state.frameError = error.name; }
    return state;
  }
  const dashboardLabel = 'the deployed JCB dashboard';
  const controlledLabel = 'a controlled Playground document';
  function diagnostics() {
    const activity = [...document.querySelectorAll('#activity-log li')].slice(-5)
      .map(item => item.textContent.trim().slice(0, 105));
    return JSON.stringify({ ...dashboardState(), details: element('error-diagnostics')?.textContent?.trim().slice(0, 240), activity });
  }
  async function until(label, check, milliseconds = 90000) {
    const deadline = Date.now() + milliseconds;
    let error = '';
    let nextReport = Date.now() + 30000;
    while (Date.now() < deadline) {
      try { if (check()) return; } catch (exception) { error = exception.message; }
      const failed = document.querySelector('#error-view:not([hidden]) #error-message')?.textContent?.trim();
      if (failed) throw Error('Playground reported: ' + failed.slice(0, 260) + ' ' + diagnostics());
      if (Date.now() >= nextReport) {
        const message = element('loading-message')?.textContent?.trim() || element('save-state')?.textContent?.trim() || '';
        signal('progress', 'Waiting for ' + label + '. ' + message.slice(0, 160) +
          (label === dashboardLabel || label === controlledLabel ? ' ' + diagnostics() : ''));
        nextReport = Date.now() + 30000;
      }
      await delay(200);
    }
    const feedback = [element('error-message'), element('header-feedback'), element('save-state')]
      .map(node => node?.textContent?.trim().slice(0, 200)).filter(Boolean).join(' / ');
    throw Error(label + ' timed out. ' + [error, feedback].filter(Boolean).join(' / ') +
      (label === dashboardLabel || label === controlledLabel ? ' ' + diagnostics() : ''));
  }
  const dbFrame = () => document.querySelector('iframe[title="Database"]');
  async function fetchRepositoryCatalog() {
    // Use the same hosted HTTP transport as PHP cURL and extension downloads.
    // Checking a pinned file digest excludes an HTML error page or shell copy.
    const { networkFetch } = await import(new URL('/src/network-transport.mjs', location.origin).href);
    const remote = 'https://raw.githubusercontent.com/joomengine/playground/1dd95451f8a0c3fda51802f8cbf0a1e72d0fb079/versions.json';
    const response = await networkFetch(remote, { credentials: 'omit' });
    if (!response.ok) throw Error('Outside repository returned HTTP ' + response.status);
    const bytes = await response.arrayBuffer();
    const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
      byte => byte.toString(16).padStart(2, '0')).join('');
    if (digest !== 'a22bc89465ff102fc5523572caf0615da7e11983e9b59b62e7fb8b1fea84f0db') {
      throw Error('The external GitHub repository download did not match the public catalog.');
    }
    signal('progress', 'Fetched and verified the external GitHub repository catalog through Playground.');
  }
  async function openDatabase() {
    await until('DB action', () => element('database-button')?.disabled === false);
    if (element('database-button').getAttribute('aria-expanded') !== 'true') element('database-button').click();
    // Playground rejects detaching before its database open operation resolves.
    await until('loaded Adminer tables', () => {
      const frame = dbFrame();
      return frame && !frame.hidden && !element('database-button').disabled &&
        frame.contentDocument?.readyState === 'complete' && frame.contentDocument.querySelector('#content');
    });
  }
  async function detach() {
    let tool;
    const nativeOpen = window.open;
    // Retain the opened WindowProxy so the test can observe the actual native
    // popup, opener and redock controls. Chromium/WebKit create the window.
    window.open = function (...args) {
      tool = nativeOpen.apply(this, args);
      return tool;
    };
    try {
      const button = document.querySelector('[aria-label="Detach database viewer"]');
      if (!button) throw Error('Missing Adminer detach button');
      button.click();
      await until('detached native Adminer window', () =>
        tool && !tool.closed && tool.opener === window &&
        tool.document.querySelector('iframe')?.contentDocument?.querySelector('#content'));
      tool.document.querySelector('[aria-label="Return to owner tab"]').click();
      await until('redocked Adminer', () => tool.closed && dbFrame()?.contentDocument?.querySelector('#content'));
    } finally { window.open = nativeOpen; }
    signal('progress', 'Detached and redocked the real Adminer window.');
  }
  async function query(write) {
    const db = dbFrame().contentDocument;
    const link = [...db.querySelectorAll('a')].find(anchor => anchor.textContent.trim() === 'SQL command');
    if (!link) throw Error('Missing Adminer SQL command link');
    link.click();
    const form = () => dbFrame()?.contentDocument?.querySelector('textarea[name="query"]')?.form;
    await until('Adminer SQL form', form);
    const editor = form();
    const frame = dbFrame().contentWindow;
    const body = new URLSearchParams(new frame.FormData(editor));
    const read = 'SELECT value FROM desktop_smoke;';
    body.set('query', (write ? "CREATE TABLE desktop_smoke (value VARCHAR(80)); INSERT INTO desktop_smoke VALUES ('" + config.id + "'); " : '') + read);
    const response = await frame.fetch(editor.action, { method: 'POST', body });
    const answer = new DOMParser().parseFromString(await response.text(), 'text/html');
    if (!response.ok || ![...answer.querySelectorAll('#content td')].some(cell => cell.textContent.trim() === config.id)) {
      const diagnostic = [...answer.querySelectorAll('#content .error, #content .message')].slice(0, 3)
        .map(node => node.textContent.trim().slice(0, 180)).join(' / ');
      throw Error('Adminer did not return the saved row (HTTP ' + response.status + '). ' + diagnostic);
    }
  }

  try {
    signal('progress', 'Loading the hosted Playground.');
    if (config.write) {
      await until(controlledLabel, () => navigator.serviceWorker?.controller && Boolean(globalThis.crossOriginIsolated));
      await fetchRepositoryCatalog();
    }
    await until(dashboardLabel, () => {
      const state = dashboardState();
      if (!state.controller || !state.isolated || !state.frame || state.hidden || state.login || state.document !== 'complete') return false;
      // A component route by itself does not prove Joomla rendered anything.
      // Accept its rendered dashboard heading or several actual workspace links.
      return state.headings.some(text => /component builder dashboard/i.test(text)) ||
        (state.route.endsWith('?option=com_componentbuilder') && state.jcbLinks >= 2 && Boolean(state.body));
    }, 480000);
    signal('progress', 'JCB dashboard rendered with service-worker control and shared-memory isolation.');
    await openDatabase();
    if (config.write) await detach();
    await query(config.write);
    signal('progress', config.write ? 'Saved the marker row in MariaDB.' : 'Recovered the marker row in MariaDB.');
    await until('the Playground checkpoint', () => /^saved locally/i.test(element('save-state')?.textContent || ''), 240000);
    if (config.write) {
      await until('Download action', () => element('download-dialog-button')?.disabled === false);
      element('download-dialog-button').click();
      await until('complete site export dialog', () => element('download-dialog')?.open && !element('export-button').disabled);
      element('export-format').value = 'bundle';
      element('export-format').dispatchEvent(new Event('change'));
      element('export-button').click();
      signal('progress', 'Requested complete Joomla ZIP from Playground.');
      // The export reads PHP files and MariaDB and then cleans up its worker
      // state. Give Playground its full normal checkpoint before native Quit.
      await until('export completion and its on-disk checkpoint', () => !element('export-button').disabled &&
        /^saved locally/i.test(element('save-state')?.textContent || ''), 240000);
    } else {
      const key = 'joomengine-native-qa-reload-' + config.id;
      const previous = sessionStorage.getItem(key);
      if (!previous) {
        sessionStorage.setItem(key, String(performance.timeOrigin));
        signal('reload', 'Activate native View > Reload on this saved JCB project.');
        return;
      }
      if (Number(previous) === performance.timeOrigin) throw Error('Reload did not open a fresh browser document.');
      signal('progress', 'The saved MariaDB row survived a native reload in a fresh document.');
    }
    // The runner checks the native download bytes before permitting shutdown.
    for (let attempt = 0; ; attempt++) {
      signal('pass', (config.write ? 'write ' : 'restore ') + attempt);
      await delay(400);
    }
  } catch (error) { signal('fail', error.message); }
})();
