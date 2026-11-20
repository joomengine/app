// The native QA target injects this script into the owner only. The installed
// application always loads the hosted Playground with its normal web settings.
(async () => {
  if (window !== window.top || window.opener || location.origin !== 'https://playground.joomengine.org') return;
  const config = __JOOMENGINE_QA_CONFIGURATION__;
  const write = config.phase === 'write';
  const signal = (command, detail) => {
    document.title = 'JE-QA/' + config.id + '/' + command + '/' + String(detail).replace(/[\r\n]/g, ' ').slice(0, 1400);
  };
  const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
  const element = id => document.getElementById(id);
  function safeText(text, limit = 120) {
    const line = String(text || '').replace(/\s+/g, ' ').trim();
    if (/password|passwd|credential|secret|api[_-]?key|authorization|cookie|bearer\s|csrf|token|\bselect\b.+\bfrom\b|\b(?:insert|replace)\s+into\b|\bupdate\s+\S+\s+set\b|\b(?:delete\s+from|(?:create|drop|alter)\s+table)\b/i.test(line)) return '[redacted]';
    return line.replace(/[\w.+-]+@[\w.-]+/g, '[email]').replace(/[A-Za-z0-9_-]{32,}/g, '[id]').slice(0, limit);
  }
  function errorFacts(sample) {
    // Classify plain-text CGI/WASM errors without exposing SQL, file contents,
    // query parameters, credentials, or application stack traces.
    const normalized = sample.toLowerCase();
    const causes = ['allowed memory size', 'maximum execution time', 'failed to open stream',
      'database is locked', 'database connection', 'access denied', 'table does not exist',
      'out of memory', 'class not found', 'unhandled exception', 'fatal error',
      'out of bounds memory access', 'memory access out of bounds', 'unreachable', 'stack overflow',
      'maximum call stack', 'null function', 'function signature mismatch', 'indirect call',
      'memory allocation', 'invalid array length', 'runtimeerror', 'rangeerror', 'typeerror',
      'webassembly.exception', 'aborted', 'php restarted after an application error',
      'internal server error'].filter(term => normalized.includes(term));
    const detail = { causes };
    const sqlState = sample.match(/SQLSTATE\[([A-Z0-9]{5})\]/i);
    if (sqlState) detail.sqlState = sqlState[1];
    return detail;
  }

  function dashboardState() {
    const frame = element('site-frame');
    const state = {
      controller: Boolean(navigator.serviceWorker?.controller), isolated: Boolean(globalThis.crossOriginIsolated),
      sharedBuffer: typeof globalThis.SharedArrayBuffer === 'function', atomics: typeof globalThis.Atomics?.add === 'function',
      worker: typeof globalThis.Worker === 'function', wasmMemory: typeof globalThis.WebAssembly?.Memory === 'function',
      environment: document.documentElement?.dataset.playgroundEnvironment,
      visible: document.visibilityState, update: element('build-update')?.hidden === false,
      launch: element('embedded-launch')?.disabled === false,
      policy: new URL(location.href).searchParams.get('__je_coep')?.split(':').pop(),
      frame: Boolean(frame), hidden: frame?.hidden
    };
    if (!frame) {
      const resources = performance.getEntriesByType('resource')
        .map(entry => new URL(entry.name, location.href)).filter(url => url.origin === location.origin)
        .map(url => url.pathname.split('/').pop())
        .filter(name => ['browser-compatibility.json', 'build.json', 'manifest.json', 'version-catalog.json', 'deploys.json'].includes(name));
      state.catalogs = [...new Set(resources)];
      return state;
    }
    try {
      const doc = frame.contentDocument;
      const url = new URL(frame.contentWindow.location.href);
      state.route = url.pathname.replace(/(__site\/)[^/]+\/[^/]+/g, '$1…') + (url.searchParams.has('option') ? '?option=' + url.searchParams.get('option') : '');
      state.document = doc?.readyState;
      state.title = safeText(doc?.title, 100);
      state.headings = [...(doc?.querySelectorAll('h1,h2') || [])].slice(0, 5).map(node => safeText(node.textContent, 70));
      state.login = Boolean(doc?.querySelector('form#login-form input[name="passwd"],input[autocomplete="current-password"]'));
      state.jcbLinks = doc?.querySelectorAll('a[href*="option=com_componentbuilder"][href*="view="]').length || 0;
      state.body = safeText(doc?.body?.innerText?.slice(0, 250), 140);
    } catch (error) { state.frameError = error.name; }
    return state;
  }
  const dashboardLabel = 'the deployed JCB dashboard';
  const controlledLabel = 'a controlled Playground document';
  function diagnostics() {
    const activity = [...document.querySelectorAll('#activity-log li')].slice(-5)
      .map(item => safeText(item.textContent, 105));
    return JSON.stringify({ ...dashboardState(), details: safeText(element('error-diagnostics')?.textContent, 240), activity });
  }
  async function until(label, check, milliseconds = 90000, failure) {
    const deadline = Date.now() + milliseconds;
    let error = '';
    let nextReport = Date.now() + 30000;
    while (Date.now() < deadline) {
      try { if (check()) return; } catch (exception) { error = exception.message; }
      const reason = failure?.();
      if (reason) throw Error(reason);
      const failed = document.querySelector('#error-view:not([hidden]) #error-message')?.textContent?.trim();
      if (failed) throw Error('Playground reported: ' + safeText(failed, 260) + ' ' + diagnostics());
      if (Date.now() >= nextReport) {
        const message = element('loading-message')?.textContent?.trim() || element('save-state')?.textContent?.trim() || '';
        signal('progress', 'Waiting for ' + label + '. ' + message.slice(0, 160) +
          (label === dashboardLabel || label === controlledLabel ? ' ' + diagnostics() : ''));
        nextReport = Date.now() + 30000;
      }
      await delay(200);
    }
    const feedback = [element('error-message'), element('header-feedback'), element('save-state')]
      .map(node => safeText(node?.textContent, 200)).filter(Boolean).join(' / ');
    throw Error(label + ' timed out. ' + [error, feedback].filter(Boolean).join(' / ') +
      (label === dashboardLabel || label === controlledLabel ? ' ' + diagnostics() : ''));
  }
  const dbFrame = () => document.querySelector('iframe[title="Database"]');
  const databaseImportError = 'Failed to fetch dynamically imported module: ' + location.origin + '/src/database/host.mjs';
  const reloadKey = 'joomengine-native-qa-reload-' + config.id;
  function adminerFailure() {
    const frame = dbFrame();
    const feedback = element('header-feedback');
    if (!frame && feedback?.dataset.error === 'true' && !feedback.hidden &&
        feedback.textContent.trim() === databaseImportError) return databaseImportError;
    const doc = frame?.contentDocument;
    if (doc?.readyState !== 'complete' || !/\/__adminer\/?$/.test(doc.location.pathname)) return '';
    const status = frame.contentWindow.performance.getEntriesByType('navigation')[0]?.responseStatus;
    if (!(status >= 400) && doc.contentType !== 'text/plain') return '';
    const body = doc.body?.innerText || '';
    const activity = [...document.querySelectorAll('#activity-log li')].slice(-3).map(node => node.textContent).join(' ');
    return 'Adminer failed to load: ' + JSON.stringify({
      route: '__adminer', status, type: doc.contentType, ready: doc.readyState, hidden: frame.hidden,
      bodyLength: body.length, body: errorFacts(body.slice(0, 8192)), activity: errorFacts(activity)
    });
  }
  async function fetchRepositoryCatalog() {
    signal('progress', 'Loading the network transport and fetching the external GitHub catalog.');
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
    }, 90000, adminerFailure);
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
  async function writeMarker() {
    const db = dbFrame().contentDocument;
    const link = [...db.querySelectorAll('a')].find(anchor => anchor.textContent.trim() === 'SQL command');
    if (!link) throw Error('Missing Adminer SQL command link');
    link.click();
    const form = () => {
      const next = dbFrame()?.contentDocument;
      return next !== db && next?.readyState === 'complete' && next.querySelector('textarea[name="query"]')?.form;
    };
    await until('Adminer SQL form', form);
    const editor = form();
    // Exercise the real native Edit command while focus is in Adminer's frame.
    const input = editor.ownerDocument.createElement('input');
    input.value = 'JoomEngine native edit command';
    editor.append(input);
    try {
      input.focus();
      input.setSelectionRange(0, 0);
      signal('select-all', 'Activate native Edit > Select All in a focused tool field.');
      await until('the native selection in Adminer', () =>
        input.selectionStart === 0 && input.selectionEnd === input.value.length, 15000);
    } finally { input.remove(); }
    const frame = dbFrame().contentWindow;
    const body = new URLSearchParams(new frame.FormData(editor));
    body.set('query', "CREATE TABLE desktop_smoke (value VARCHAR(80)); INSERT INTO desktop_smoke VALUES ('" +
      config.id + "'); SELECT value FROM desktop_smoke;");
    return frame.fetch(editor.action, { method: 'POST', body });
  }
  async function verifyMarker(write) {
    // Adminer's Browse view reads the stored row after import or restart. Only
    // creating the fixture needs a SQL command form and its session token.
    const frame = dbFrame().contentWindow;
    const response = write ? await writeMarker() :
      await frame.fetch(new URL('?select=desktop_smoke', frame.location.href), { cache: 'no-store' });
    const answer = new DOMParser().parseFromString(await response.text(), 'text/html');
    if (!response.ok || ![...answer.querySelectorAll('#content td')].some(cell => cell.textContent.trim() === config.id)) {
      const diagnostic = [...answer.querySelectorAll('#content .error, #content .message')].slice(0, 3)
        .map(node => safeText(node.textContent, 180)).join(' / ');
      throw Error('Adminer did not return the saved row (HTTP ' + response.status + '). ' + diagnostic);
    }
  }

  function visibleButton(id) {
    const button = element(id);
    return button && !button.disabled && button.getClientRects().length > 0 ? button : null;
  }
  function importFailure() {
    const feedback = element('header-feedback');
    if (feedback?.dataset.error === 'true' && !feedback.hidden) return 'Site upload: ' + safeText(feedback.textContent);
  }
  async function importSite() {
    const originalKey = element('storage-key').value;
    const originalFrame = element('site-frame');
    if (element('settings').hidden) element('settings-toggle').click();
    await until('enabled Upload button', () => visibleButton('upload-site-button')?.matches(':enabled'));
    const button = element('upload-site-button');
    button.focus();
    if (document.activeElement !== button) throw Error('Could not focus the Playground Upload button.');
    signal(config.nativeChooser ? 'choose-import' : 'import-file', 'Select the exported complete site ZIP.');
    await until('Upload replacement confirmation', () =>
      document.querySelector('dialog[data-live-replacement][open] button[data-replace-choice="continue"]'), 120000, importFailure);
    document.querySelector('dialog[data-live-replacement][open] button[data-replace-choice="continue"]').click();
    await until('the imported site in its new workspace', () => {
      const frame = element('site-frame');
      const key = element('storage-key').value;
      return key !== originalKey && key.startsWith('import-') && frame && frame !== originalFrame &&
        element('credentials-button').matches(':enabled') && frame.contentDocument?.readyState === 'complete';
    }, 480000, importFailure);
  }
  async function verifyImportedFile() {
    const site = new URL(element('site-frame').src);
    const base = site.pathname.match(/^(.*\/__site\/[^/]+\/[^/]+\/)/);
    if (!base || site.origin !== location.origin) throw Error('Missing imported site route.');
    const response = await fetch(new URL(base[1] + config.asset.path, site.origin), { cache: 'no-store' });
    const bytes = await response.arrayBuffer();
    const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
      byte => byte.toString(16).padStart(2, '0')).join('');
    if (!response.ok || digest !== config.asset.digest) throw Error('The imported site file differs from the ZIP.');
  }
  async function verifyStorageCapacity() {
    const size = 10 * 1024 ** 3;
    const directory = await navigator.storage.getDirectory();
    const name = 'joomengine-capacity-' + crypto.randomUUID();
    const handle = await directory.getFileHandle(name, { create: true });
    let stream;
    try {
      stream = await handle.createWritable();
      await stream.write(Uint8Array.of(0x4a));
      await stream.truncate(size);
      await stream.write({ type: 'write', position: size - 1, data: Uint8Array.of(0x45) });
      await stream.close();
      stream = null;
      const reopened = await directory.getFileHandle(name);
      const file = await reopened.getFile();
      const first = new Uint8Array(await file.slice(0, 1).arrayBuffer());
      const last = new Uint8Array(await file.slice(-1).arrayBuffer());
      if (file.size !== size || first[0] !== 0x4a || last[0] !== 0x45) {
        throw Error('The 10 GiB origin-private file did not retain its length and endpoint bytes.');
      }
      const { usage } = await navigator.storage.estimate();
      if (!(usage >= size)) throw Error('Origin storage did not account for the committed 10 GiB file.');
    } finally {
      try { if (stream) await stream.abort(); }
      finally { await directory.removeEntry(name); }
    }
    signal('progress', 'Verified and removed a sparse 10 GiB origin-private file, including quota usage and both endpoint bytes.');
  }
  function advanceFreshWelcome() {
    // Only the isolated, fresh deployment can use welcome actions. Never
    // restart a running/saved site, or retry a write or partially built site.
    if (!write || element('site-frame') || document.hidden ||
        document.documentElement.dataset.playgroundEnvironment !== 'ready') return;
    const key = 'joomengine-native-qa-welcome-' + config.id;
    const update = visibleButton('reload-build');
    if (element('build-update')?.hidden === false) {
      if (update && !sessionStorage.getItem(key + '-update')) {
        sessionStorage.setItem(key + '-update', '1');
        signal('progress', 'Playground offered a new build on welcome. Activated Reload Playground.');
        update.click();
      }
      return;
    }
    if (element('welcome')?.hidden !== false || element('launch-countdown')?.hidden !== true || sessionStorage.getItem(key)) return;
    const launch = visibleButton('embedded-launch');
    const ready = [...document.querySelectorAll('#activity-log li')].at(-1)?.textContent.includes('Ready to launch.');
    if (launch && ready) {
      sessionStorage.setItem(key, '1');
      signal('progress', 'Activated the available Launch button on the fresh welcome screen.');
      launch.click();
    }
  }
  try {
    // WebView2 installs this driver before the document has a head for its title.
    if (document.readyState === 'loading') {
      await new Promise(resolve => document.addEventListener('DOMContentLoaded', resolve, { once: true }));
    }
    signal('progress', 'Loading the hosted Playground.');
    if (write) {
      await until(controlledLabel, () => navigator.serviceWorker?.controller && Boolean(globalThis.crossOriginIsolated));
      if (config.checkStorage) await verifyStorageCapacity();
      await fetchRepositoryCatalog();
    }
    await until(dashboardLabel, () => {
      advanceFreshWelcome();
      const state = dashboardState();
      if (!state.controller || !state.isolated || !state.frame || state.hidden || state.login || state.document !== 'complete') return false;
      // A component route by itself does not prove Joomla rendered anything.
      // Accept its rendered dashboard heading or several actual workspace links.
      return state.headings.some(text => /component builder dashboard/i.test(text)) ||
        (state.route.endsWith('?option=com_componentbuilder') && state.jcbLinks >= 2 && Boolean(state.body));
    }, 480000);
    signal('progress', 'JCB dashboard rendered with service-worker control and shared-memory isolation.');
    if (config.phase === 'import') await importSite();
    if (!write) {
      const key = element('storage-key').value;
      if (config.phase === 'restore' && key !== config.importKey) throw Error('Reopened a different saved site.');
      await verifyImportedFile();
    }
    await openDatabase();
    if (write) await detach();
    await verifyMarker(write);
    signal('progress', write ? 'Saved the marker row in MariaDB.' : 'Recovered the marker row in MariaDB.');
    await until('the Playground checkpoint', () => /^saved locally/i.test(element('save-state')?.textContent || ''), 240000);
    if (write) {
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
    } else if (config.phase === 'restore') {
      const previous = sessionStorage.getItem(reloadKey);
      if (!previous) {
        sessionStorage.setItem(reloadKey, String(performance.timeOrigin));
        signal('reload', 'Activate native View > Reload on this saved JCB project.');
        return;
      }
      if (Number(previous) === performance.timeOrigin) throw Error('Reload did not open a fresh browser document.');
      signal('progress', 'The imported file and MariaDB row survived restart and native Reload.');
    }
    // Carry the new workspace identity through the native pass event. The next
    // process must recover that same imported site after a complete shutdown.
    const result = config.phase === 'import' ? element('storage-key').value : config.phase;
    for (let attempt = 0; ; attempt++) {
      signal('pass', result + ' ' + attempt);
      await delay(400);
    }
  } catch (error) {
    // A failed ES module import can stick to its document. Allow a single
    // fresh document for this specific hosted GET on the first, read-only
    // restore. The database and the independently verified native Reload
    // must still succeed. Never retry a PHP response or a write operation.
    const retryKey = 'joomengine-native-qa-module-retry-' + config.id;
    const phpRestarted = [...document.querySelectorAll('#activity-log li')].some(item =>
      item.textContent.includes('PHP restarted after an application error'));
    if (config.phase === 'restore' && !phpRestarted && error.message === databaseImportError &&
        !sessionStorage.getItem(reloadKey) && !sessionStorage.getItem(retryKey)) {
      sessionStorage.setItem(retryKey, '1');
      signal('retry-module', 'The hosted Database module failed to download. Reloading the saved workspace once.');
      return;
    }
    signal('fail', error.message);
  }
})();
