#!/usr/bin/env node
// Checks a built site (web/build_site.sh) in a real Chrome, over the Chrome
// DevTools Protocol. No packages needed (Node 22+).
//
//   node web/test_site_browser.mjs <site_dir> <chrome> [screenshot_dir]
//
// 1. Update, then offline: version 1 is visited; version 2 is deployed (a
//    different CACHE_VERSION in sw.js) and the app is opened again, so
//    version 2's worker installs and waits (nobody taps Reload); the tab is
//    closed; the server goes away; a new tab must still start the app
//    (app/web/sw.js copies the older version's files when it installs).
// 2. A slow network: the server never answers the page; the cached copy
//    must start the app after sw.js's 4 s timeout.
// 3. Hosts: the first visit in English, and one in Arabic (a fresh
//    profile), must fetch only from the site itself (no Google fonts, no
//    CDN); every request of the pages and their workers is listed.
// 4. Reminders (a fresh profile, notifications allowed): a Web Push
//    delivered to the service worker (CDP ServiceWorker.deliverPushMessage)
//    shows its notification (registration.getNotifications()), a payload
//    that isn't JSON a plain "Taskwise reminder"; the worker's click logic
//    (openTask, run inside the worker: CDP can't click a notification)
//    sends the open app to the task; and a page opened at #task=<id> (where
//    a click opens a closed app) opens it too, with the address cleaned.
//
// "The app started" means the app wrote its start line ("started on web")
// to its log in localStorage, so main() ran with CanvasKit and the database.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';

const [siteDir, chromePath, shotsDir] = process.argv.slice(2);
if (!siteDir || !chromePath) {
  console.error('usage: node web/test_site_browser.mjs <site_dir> <chrome> [screenshot_dir]');
  process.exit(2);
}
const root = path.resolve(siteDir);
const swSource = fs.readFileSync(path.join(root, 'app/sw.js'), 'utf8');
if (!/const CACHE_VERSION = '[^{']+'/.test(swSource)) {
  console.error('app/sw.js has no CACHE_VERSION: build the site with web/build_site.sh');
  process.exit(2);
}

// ------------------------------------------------------------------ server

let version = 'v1';
let mode = 'online'; // 'online' | 'offline' (connections refused) | 'slow' (no answers)
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2',
  '.txt': 'text/plain', '.bin': 'application/octet-stream', '.frag': 'application/octet-stream',
};
const sockets = new Set();
const server = http.createServer((req, res) => {
  if (mode === 'slow') return; // never answers
  const url = new URL(req.url, 'http://localhost');
  let file = decodeURIComponent(url.pathname);
  if (file === '/app') {
    res.writeHead(308, { Location: '/app/' });
    return res.end();
  }
  if (file.endsWith('/')) file += 'index.html';
  const full = path.join(root, file);
  if (!full.startsWith(root + path.sep) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    res.writeHead(404);
    return res.end();
  }
  const headers = {
    'Content-Type': types[path.extname(full)] ?? 'application/octet-stream',
    'Cache-Control': 'no-cache',
  };
  if (file.startsWith('/app/')) {
    headers['Cross-Origin-Opener-Policy'] = 'same-origin';
    headers['Cross-Origin-Embedder-Policy'] = 'credentialless';
  }
  let body = fs.readFileSync(full);
  if (file === '/app/sw.js') {
    body = swSource.replace(/const CACHE_VERSION = '([^']*)'/, `const CACHE_VERSION = '$1-${version}'`);
  }
  res.writeHead(200, headers);
  res.end(body);
});
server.on('connection', (socket) => {
  if (mode === 'offline') return socket.destroy();
  sockets.add(socket);
  socket.on('close', () => sockets.delete(socket));
});
function goOffline() {
  mode = 'offline';
  for (const socket of sockets) socket.destroy();
}
function goSlow() {
  mode = 'slow';
  for (const socket of sockets) socket.destroy();
}
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const origin = `http://localhost:${server.address().port}`;
const appUrl = `${origin}/app/`;

// ------------------------------------------------------------------ chrome

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function launchChrome() {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'taskwise-chrome-'));
  const proc = spawn(chromePath, [
    '--headless=new', `--user-data-dir=${profile}`, '--remote-debugging-port=0',
    '--no-first-run', '--no-default-browser-check', '--no-sandbox',
    '--disable-background-networking', '--disable-component-update', '--disable-sync',
    '--disable-default-apps', '--window-size=1280,900', 'about:blank',
  ], { stdio: 'ignore' });
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let i = 0; !fs.existsSync(portFile) || fs.readFileSync(portFile, 'utf8').split('\n').length < 2; i++) {
    if (i > 200) throw new Error('Chrome did not start');
    await sleep(100);
  }
  const [port, wsPath] = fs.readFileSync(portFile, 'utf8').trim().split('\n');
  const ws = new WebSocket(`ws://127.0.0.1:${port}${wsPath}`);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let nextId = 0;
  const pending = new Map();
  const listeners = [];
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id !== undefined) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) p.reject(new Error(`${p.method}: ${msg.error.message}`));
      else p.resolve(msg.result);
    } else {
      for (const listener of listeners) listener(msg);
    }
  };
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject, method });
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });
  const chrome = {
    send,
    requests: [], // { url, target }
    errors: [],
    pageSessions: new Map(), // targetId -> sessionId
    workerSessions: [], // service worker sessions
    listeners,
    language: 'en',
    async close() {
      try { await send('Browser.close'); } catch (_) { /* gone */ }
      ws.close();
      await new Promise((resolve) => (proc.exitCode !== null ? resolve() : proc.on('exit', resolve)));
      fs.rmSync(profile, { recursive: true, force: true });
    },
  };
  const { userAgent } = await send('Browser.getVersion');
  listeners.push(async ({ method, params, sessionId }) => {
    if (method === 'Target.attachedToTarget') {
      const s = params.sessionId;
      const type = params.targetInfo.type;
      if (type === 'page') chrome.pageSessions.set(params.targetInfo.targetId, s);
      if (type === 'service_worker') chrome.workerSessions.push(s);
      // All at once, as the target waits for runIfWaitingForDebugger (some
      // commands wait for it to run).
      const commands = [send('Network.enable', {}, s), send('Runtime.enable', {}, s)];
      if (type === 'page') {
        commands.push(
          send('Emulation.setUserAgentOverride', { userAgent, acceptLanguage: chrome.language }, s),
          send('Emulation.setLocaleOverride', { locale: chrome.language }, s),
        );
      }
      // The page's own workers (the database worker); service workers are
      // attached at the top already.
      commands.push(send('Target.setAutoAttach', { autoAttach: true, waitForDebuggerOnStart: true, flatten: true }, s));
      commands.push(send('Runtime.runIfWaitingForDebugger', {}, s));
      await Promise.all(commands.map((c) => c.catch(() => {})));
    } else if (method === 'Network.requestWillBeSent') {
      chrome.requests.push({ url: params.request.url, session: sessionId });
    } else if (method === 'Network.loadingFailed' || (method === 'Network.responseReceived' && params.response.status >= 400)) {
      chrome.errors.push(`${method} ${params.errorText ?? params.response?.status} ${params.response?.url ?? ''}`);
    } else if (method === 'Runtime.exceptionThrown') {
      chrome.errors.push(params.exceptionDetails.exception?.description ?? params.exceptionDetails.text);
    }
  });
  await send('Target.setAutoAttach', { autoAttach: true, waitForDebuggerOnStart: true, flatten: true });
  return chrome;
}

async function openTab(chrome, url) {
  const { targetId } = await chrome.send('Target.createTarget', { url });
  for (let i = 0; !chrome.pageSessions.has(targetId); i++) {
    if (i > 100) throw new Error('no session for the new tab');
    await sleep(50);
  }
  const sessionId = chrome.pageSessions.get(targetId);
  return {
    sessionId,
    async eval(expression) {
      const { result, exceptionDetails } = await chrome.send(
        'Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId);
      if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
      return result.value;
    },
    async shot(name) {
      if (!shotsDir) return;
      fs.mkdirSync(shotsDir, { recursive: true });
      const { data } = await chrome.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      fs.writeFileSync(path.join(shotsDir, `${name}.png`), Buffer.from(data, 'base64'));
    },
    close: () => chrome.send('Target.closeTarget', { targetId }),
  };
}

const startsJs = `(() => {
  try { return (localStorage.getItem('taskwise.log') || '').split('started on web').length - 1; }
  catch (_) { return -1; }
})()`;
const swStateJs = `navigator.serviceWorker.getRegistration().then((r) => r ? {
  installing: r.installing && r.installing.state, waiting: r.waiting && r.waiting.state,
  active: r.active && r.active.state, controller: !!navigator.serviceWorker.controller } : 'no registration')`;
const cachesJs = `(async () => {
  const out = {};
  for (const name of await caches.keys()) {
    out[name] = (await (await caches.open(name)).keys()).map((r) => r.url);
  }
  return out;
})()`;

async function waitFor(what, check, timeoutMs) {
  const end = Date.now() + timeoutMs;
  let last;
  while (Date.now() < end) {
    try {
      last = await check();
      if (last) return last;
    } catch (error) {
      last = error.message;
    }
    await sleep(250);
  }
  throw new Error(`timed out waiting for ${what} (last: ${JSON.stringify(last)})`);
}

/** Waits until the app has started [count] times in this profile. */
async function waitStarted(tab, count, timeoutMs = 60000) {
  const t0 = Date.now();
  await waitFor(`start #${count}`, async () => (await tab.eval(startsJs)) >= count, timeoutMs);
  return Date.now() - t0;
}

function hostsOf(requests) {
  const hosts = new Set();
  for (const { url } of requests) {
    if (/^https?:/.test(url)) hosts.add(new URL(url).host);
  }
  return [...hosts];
}

// ------------------------------------------------------------------ checks

let failed = false;
const ok = (message) => console.log(`ok: ${message}`);
const bad = (message) => { console.log(`FAIL: ${message}`); failed = true; };
const siteHost = new URL(origin).host;

function checkHosts(label, chrome) {
  const hosts = hostsOf(chrome.requests);
  const others = hosts.filter((h) => h !== siteHost);
  console.log(`${label}: ${chrome.requests.length} requests, hosts: ${hosts.join(', ')}`);
  if (others.length) bad(`${label}: requests to ${others.join(', ')}: ${chrome.requests.filter((r) => !r.url.startsWith(origin) && /^https?:/.test(r.url)).map((r) => r.url).join(' ')}`);
  else ok(`${label}: only the site itself (${siteHost})`);
  const fallback = chrome.requests.map((r) => r.url).filter((u) => u.includes('/fallback-fonts/') && !u.includes('/roboto/'));
  if (fallback.length) bad(`${label}: the engine looked for fallback fonts: ${[...new Set(fallback)].join(' ')}`);
}

const chrome = await launchChrome();
try {
  // 1. Version 1, first visit (English).
  const tab1 = await openTab(chrome, appUrl);
  await waitStarted(tab1, 1);
  try {
    await waitFor('the worker to control the page', () => tab1.eval('!!navigator.serviceWorker.controller'), 30000);
  } catch (error) {
    throw new Error(`${error.message}; worker: ${JSON.stringify(await tab1.eval(swStateJs))}`);
  }
  // The first visit's files reach the cache once the worker controls the page.
  let v1Keys;
  await waitFor('CanvasKit and the fonts in the cache', async () => {
    const all = await tab1.eval(cachesJs);
    const names = Object.keys(all).filter((n) => n.startsWith('taskwise-app-'));
    if (names.length !== 1) return false;
    v1Keys = all[names[0]];
    return v1Keys.some((u) => u.endsWith('canvaskit.wasm')) &&
      v1Keys.some((u) => u.includes('roboto')) &&
      v1Keys.some((u) => u.endsWith('main.dart.js'));
  }, 30000);
  await sleep(3000);
  v1Keys = Object.values(await tab1.eval(cachesJs))[0];
  await tab1.shot('1-first-visit-en');
  console.log(`version 1 cached ${v1Keys.length} files`);
  checkHosts('first visit (English)', chrome);
  await tab1.close();

  // 2. Version 2 is deployed; the app is opened again (online). Its worker
  //    installs and waits: nobody taps Reload.
  version = 'v2';
  const tab2 = await openTab(chrome, appUrl);
  await waitStarted(tab2, 2);
  await waitFor('version 2 to wait', () => tab2.eval('window.taskwiseNewVersionReady === true'), 60000);
  const both = await tab2.eval(cachesJs);
  const v2Name = Object.keys(both).find((n) => n.endsWith('-v2'));
  if (!v2Name) throw new Error(`no version 2 cache: ${Object.keys(both)}`);
  const missing = v1Keys.filter((u) => !both[v2Name].includes(u));
  if (missing.length) bad(`version 2's cache lacks ${missing.join(' ')}`);
  else ok(`version 2 installed and waits; its cache has all ${v1Keys.length} files of version 1 (${both[v2Name].length} in all)`);
  await tab2.close();
  await sleep(500);

  // 3. Offline, a new tab: version 2 takes over (deleting version 1's
  //    cache) and must start the app from its own cache.
  goOffline();
  const tab3 = await openTab(chrome, appUrl);
  try {
    const ms = await waitStarted(tab3, 3, 45000);
    const after = await tab3.eval(cachesJs);
    const names = Object.keys(after).filter((n) => n.startsWith('taskwise-app-'));
    ok(`offline after the update: the app started in ${ms} ms (caches now: ${names.join(', ')})`);
    if (names.length !== 1 || !names[0].endsWith('-v2')) bad(`expected only version 2's cache, found ${names.join(', ')}`);
    await tab3.shot('2-offline-after-update');
  } catch (error) {
    await tab3.shot('2-offline-after-update');
    bad(`offline after the update: ${error.message}`);
  }
  await tab3.close();

  // 4. A server that never answers: the cached page after the timeout.
  goSlow();
  const tab4 = await openTab(chrome, appUrl);
  try {
    const ms = await waitStarted(tab4, 4, 45000);
    ok(`no answer from the server: the app started from the cache in ${ms} ms`);
  } catch (error) {
    bad(`no answer from the server: ${error.message}`);
  }
  await tab4.close();
} catch (error) {
  bad(error.stack ?? String(error));
} finally {
  if (chrome.errors.length) console.log(`errors and failed requests seen: ${chrome.errors.join(' | ')}`);
  await chrome.close();
}

// 5. A first visit in Arabic, in a fresh profile.
mode = 'online';
version = 'v1';
const arabic = await launchChrome();
arabic.language = 'ar';
try {
  // The language applies to tabs opened from now on.
  const tab = await openTab(arabic, appUrl);
  await waitStarted(tab, 1);
  const languages = await tab.eval('navigator.languages.join(",")');
  await sleep(5000);
  await tab.shot('3-first-visit-ar');
  console.log(`Arabic visit: navigator.languages = ${languages}`);
  if (!languages.startsWith('ar')) bad('the Arabic visit did not get Arabic as the browser language');
  checkHosts('first visit (Arabic)', arabic);
} catch (error) {
  bad(error.stack ?? String(error));
} finally {
  await arabic.close();
}

// 6. Reminders, in a fresh profile with notifications allowed.
const push = await launchChrome();
try {
  await push.send('Browser.grantPermissions', { origin, permissions: ['notifications'] });
  const registrations = new Map(); // scope -> registration id
  push.listeners.push(({ method, params }) => {
    if (method !== 'ServiceWorker.workerRegistrationUpdated') return;
    for (const r of params.registrations) {
      if (r.isDeleted) registrations.delete(r.scopeURL);
      else registrations.set(r.scopeURL, r.registrationId);
    }
  });
  const tab = await openTab(push, appUrl);
  await waitStarted(tab, 1);
  await waitFor('the worker to control the page', () => tab.eval('!!navigator.serviceWorker.controller'), 30000);
  await push.send('ServiceWorker.enable', {}, tab.sessionId);
  const registrationId = await waitFor('the worker registration', () => registrations.get(appUrl), 10000);
  const deliver = (data) => push.send(
    'ServiceWorker.deliverPushMessage', { origin, registrationId, data }, tab.sessionId);
  const notificationsJs = `navigator.serviceWorker.ready.then((r) => r.getNotifications()).then((list) =>
    list.map((n) => ({ title: n.title, body: n.body, tag: n.tag, icon: n.icon, data: n.data, actions: n.actions.length })))`;

  await deliver(JSON.stringify({ title: 'Pay rent', body: 'Today at 09:00', taskId: 'task-123', key: 'k1' }));
  const shown = await waitFor('the notification', async () =>
    (await tab.eval(notificationsJs)).find((n) => n.tag === 'k1'), 10000);
  console.log(`push notification: ${JSON.stringify(shown)}`);
  if (shown.title === 'Pay rent' && shown.body === 'Today at 09:00' && shown.data?.taskId === 'task-123' &&
      shown.actions === 0 && shown.icon.endsWith('/app/icons/Icon-192.png')) {
    ok('a push shows its notification (title, body, tag, task id, icon, no buttons)');
  } else {
    bad(`unexpected notification ${JSON.stringify(shown)}`);
  }

  await deliver('not json');
  const plain = await waitFor('the plain notification', async () =>
    (await tab.eval(notificationsJs)).find((n) => n.title === 'Taskwise reminder'), 10000);
  ok(`a payload that isn't JSON still shows "${plain.title}"`);

  // The click: the worker's own openTask() with the notification's task id.
  const opensJs = (id) => `(localStorage.getItem('taskwise.log') || '').includes('Opening task ${id} from a notification')`;
  const worker = await waitFor('the worker session', async () => {
    for (const s of push.workerSessions) {
      try {
        const { result } = await push.send('Runtime.evaluate', {
          expression: 'typeof openTask === "function" && self.registration.scope', returnByValue: true }, s);
        if (result.value === appUrl) return s;
      } catch (_) { /* a stopped worker */ }
    }
    return null;
  }, 10000);
  const { result: clicked, exceptionDetails } = await push.send('Runtime.evaluate', {
    expression: `self.registration.getNotifications({ tag: 'k1' })
      .then((list) => openTask(list[0].data.taskId)).then(() => taskUrl('task-456'))`,
    awaitPromise: true, returnByValue: true }, worker);
  if (exceptionDetails) throw new Error(`openTask: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`);
  try {
    await waitFor('the open app to open the task', () => tab.eval(opensJs('task-123')), 10000);
    ok('a tapped notification sends the open app to its task (open-task message)');
  } catch (error) {
    bad(`tapping with the app open: ${error.message}`);
  }
  await sleep(1000);
  await tab.shot('4-opened-from-notification');
  await tab.close();

  // The app was closed: the click opens the address taskUrl() gives.
  if (clicked.value !== `${appUrl}#task=task-456`) bad(`taskUrl gave ${clicked.value}`);
  const cold = await openTab(push, clicked.value);
  await waitStarted(cold, 2);
  try {
    await waitFor('the started app to open the task', () => cold.eval(opensJs('task-456')), 15000);
    const hash = await cold.eval('location.hash');
    if (hash) bad(`#task= was left in the address: ${hash}`);
    else ok('an app opened at #task=<id> opens that task, and the address is cleaned');
  } catch (error) {
    bad(`opening at #task=: ${error.message}`);
  }
  await cold.close();
} catch (error) {
  bad(error.stack ?? String(error));
} finally {
  await push.close();
  server.close();
}

console.log(failed ? 'Some checks failed.' : 'All browser checks passed.');
process.exit(failed ? 1 : 0);
