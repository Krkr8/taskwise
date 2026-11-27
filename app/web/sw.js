// Taskwise's service worker (not Flutter's: the app is built with
// `--pwa-strategy=none`). It keeps the app's own files for an offline start
// and tells the page when a new version is waiting. See app/web_README.md.
//
// The site build replaces the placeholder below with the version, so every
// release has a new cache (and a changed sw.js, which makes browsers install
// it). An unreplaced dev build caches nothing.
const CACHE_VERSION = '{{VERSION}}';
const DEV = CACHE_VERSION.startsWith('{{');
const PREFIX = 'taskwise-app-';
const CACHE = PREFIX + CACHE_VERSION;

// Relative to the scope (the app's folder, e.g. /app/). '' is index.html.
// Everything else, flutter_bootstrap.js too, is cache first from this
// version's cache, so a page never mixes files of two versions.
const NETWORK_FIRST = ['', 'index.html', 'manifest.json'];
// Fetched while installing. The rest (CanvasKit, fonts, assets) the page
// lists once this worker controls it ({type: 'cache'}, index.html).
const PRECACHE = [
  '',
  'flutter_bootstrap.js',
  'manifest.json',
  'main.dart.js',
  'sqlite3.wasm',
  'drift_worker.js',
];

const scope = self.registration.scope;

function keyFor(path) {
  // index.html is kept under the folder's address.
  return path === 'index.html' ? scope : scope + path;
}

function pathOf(url) {
  return new URL(url).pathname.slice(new URL(scope).pathname.length);
}

function cacheable(response) {
  return response.ok && response.type === 'basic' && !response.redirected;
}

// Every file that goes into the cache is revalidated with the server first:
// Flutter doesn't hash CanvasKit's or the assets' names, so the browser's
// HTTP cache could still hold the previous version's copy.
function fetchFresh(urlOrRequest) {
  return fetch(new Request(urlOrRequest, { cache: 'no-cache' }));
}

// Everything this version needs for an offline start, before it replaces
// the running one: the main files, and every file an older version's cache
// holds (CanvasKit, fonts, assets), fetched fresh. Activating deletes the
// older caches, so without them an update that was never reloaded (the new
// worker waits, the user closes the tab) would start offline with no
// CanvasKit: a blank page.
async function precache() {
  const cache = await caches.open(CACHE);
  const urls = new Set(PRECACHE.map(keyFor));
  for (const name of await caches.keys()) {
    if (!name.startsWith(PREFIX) || name === CACHE) continue;
    const old = await caches.open(name);
    for (const request of await old.keys()) {
      if (request.url.startsWith(scope)) urls.add(request.url);
    }
  }
  await Promise.all(
    [...urls].map(async (url) => {
      // Offline or a server error rejects: the install fails as a whole and
      // the running version keeps serving (the browser tries again later).
      const response = await fetchFresh(url);
      if (response.status === 404 && !PRECACHE.map(keyFor).includes(url)) {
        // An older version's file that this one no longer has.
        return;
      }
      if (!cacheable(response)) {
        throw new Error(`sw: ${url} answered ${response.status}`);
      }
      await cache.put(url, response);
    }),
  );
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      if (!DEV) await precache();
      // An older version is running: this one waits until the page says
      // {type: 'reload'}.
      if (self.registration.active) {
        const clients = await self.clients.matchAll({
          type: 'window',
          includeUncontrolled: true,
        });
        for (const client of clients) client.postMessage({ type: 'new-version' });
      }
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith(PREFIX) && name !== CACHE)
          .map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

// The files the page loaded before this worker controlled it (the first
// visit): cached now, so one online visit is enough for an offline start.
async function cacheUrls(urls) {
  const cache = await caches.open(CACHE);
  await Promise.all(
    urls.map(async (url) => {
      try {
        if (typeof url !== 'string') return;
        const clean = new URL(url);
        clean.hash = '';
        // Only the app's own files (this also rules out other sites).
        if (!clean.href.startsWith(scope)) return;
        const path = pathOf(clean.href);
        // index.html (with or without ?server=…) is kept under the folder.
        const key = path === '' || path === 'index.html' ? scope : clean.href;
        if (await cache.match(key)) return;
        const response = await fetchFresh(clean.href);
        if (cacheable(response)) await cache.put(key, response);
      } catch (_) {
        // Offline or gone: it's cached when the app asks for it.
      }
    }),
  );
}

self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data) return;
  if (data.type === 'reload') self.skipWaiting();
  if (data.type === 'cache' && Array.isArray(data.urls) && !DEV) {
    event.waitUntil(cacheUrls(data.urls));
  }
});

// How long a page load waits for the network before it uses the cached
// copy (a very slow connection shouldn't keep a blank page). Without a
// cached copy it keeps waiting for the network.
const NETWORK_TIMEOUT_MS = 4000;

function networkFirst(event, key) {
  // Page loads go as they are (a navigation can't be copied freely).
  const request = event.request;
  const network =
    request.mode === 'navigate' ? fetch(request) : fetchFresh(request);
  // Saved even when the cached copy answered first. The copy is taken as
  // soon as the response arrives, before the page reads it.
  const saved = network.then((response) => {
    if (!cacheable(response)) return undefined;
    const copy = response.clone();
    return caches.open(CACHE).then((cache) => cache.put(key, copy));
  });
  event.waitUntil(saved.catch(() => {}));

  return (async () => {
    const cached = () => caches.open(CACHE).then((cache) => cache.match(key));
    let timer;
    const timeout = new Promise((resolve) => {
      timer = setTimeout(resolve, NETWORK_TIMEOUT_MS, null);
    });
    try {
      const response = await Promise.race([network, timeout]);
      if (response) return response;
      // Slow network: the cached copy, else keep waiting.
      return (await cached()) || (await network);
    } catch (error) {
      const copy = await cached();
      if (copy) return copy;
      throw error;
    } finally {
      clearTimeout(timer);
    }
  })();
}

async function cacheFirst(event) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(event.request);
  if (cached) return cached;
  const response = await fetchFresh(event.request);
  if (cacheable(response)) {
    event.waitUntil(cache.put(event.request, response.clone()));
  }
  return response;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  // Only the app's own files: never other sites (the sync server, map
  // tiles), never anything but GET.
  if (DEV || request.method !== 'GET' || !request.url.startsWith(scope)) {
    return;
  }
  const path = pathOf(request.url);
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(event, scope));
  } else if (NETWORK_FIRST.includes(path)) {
    event.respondWith(networkFirst(event, keyFor(path)));
  } else {
    event.respondWith(cacheFirst(event));
  }
});
