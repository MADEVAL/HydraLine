/*! ==========================================================================
 *  HYDRALINE - Service Worker
 *
 *  Caches the heavy Flutter engine assets (main.dart.js, canvaskit.*) with a
 *  stale-while-revalidate strategy: warm visits hydrate in about one second
 *  from cache, while a background fetch refreshes the cache so the next visit
 *  picks up a redeployed engine. Bump CACHE_NAME to force a full purge.
 *
 *  Part of the Hydraline project - MIT License
 *  https://github.com/MADEVAL/HydraLine
 * ========================================================================== */
var CACHE_NAME = 'hydraline-v1';

/* URL substrings identifying cacheable engine assets. */
var ENGINE_ASSETS = ['main.dart.js', 'canvaskit'];

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (names) {
      return Promise.all(
        names.map(function (name) {
          return name === CACHE_NAME ? null : caches.delete(name);
        })
      );
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (event) {
  var url = event.request.url;
  var isEngineAsset = ENGINE_ASSETS.some(function (asset) {
    return url.indexOf(asset) > -1;
  });
  if (!isEngineAsset) {
    return;
  }
  event.respondWith(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.match(event.request).then(function (cached) {
        var network = fetch(event.request)
          .then(function (response) {
            if (response.ok) {
              cache.put(event.request, response.clone());
            }
            return response;
          })
          .catch(function () {
            return cached;
          });
        return cached || network;
      });
    })
  );
});
