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
const NETWORK_FIRST = ['', 'index.html', 'flutter_bootstrap.js', 'manifest.json'];
// Fetched while installing, so the first start works offline next time.
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

function cacheable(response) {
  return response.ok && response.type === 'basic' && !response.redirected;
}

async function precache() {
  const cache = await caches.open(CACHE);
  await Promise.all(
    PRECACHE.map(async (path) => {
      try {
        // Revalidate with the server, so a new version gets new files.
        const response = await fetch(scope + path, { cache: 'no-cache' });
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

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'reload') self.skipWaiting();
});

async function networkFirst(event, key) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(event.request);
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
  const response = await fetch(event.request);
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
  const path = new URL(request.url).pathname.slice(new URL(scope).pathname.length);
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(event, scope));
  } else if (NETWORK_FIRST.includes(path)) {
    event.respondWith(networkFirst(event, keyFor(path)));
  } else {
    event.respondWith(cacheFirst(event));
  }
});
