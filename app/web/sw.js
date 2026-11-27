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

async function precache() {
  const cache = await caches.open(CACHE);
  await Promise.all(
    PRECACHE.map(async (path) => {
      try {
        const response = await fetchFresh(scope + path);
        if (cacheable(response)) await cache.put(keyFor(path), response);
      } catch (_) {
        // Missing or offline: it's cached when the app asks for it.
      }
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

async function networkFirst(event, key) {
  const cache = await caches.open(CACHE);
  try {
    // Page loads go as they are (a navigation can't be copied freely).
    const request = event.request;
    const response = await (request.mode === 'navigate'
      ? fetch(request)
      : fetchFresh(request));
    if (cacheable(response)) event.waitUntil(cache.put(key, response.clone()));
    return response;
  } catch (error) {
    const cached = await cache.match(key);
    if (cached) return cached;
    throw error;
  }
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
