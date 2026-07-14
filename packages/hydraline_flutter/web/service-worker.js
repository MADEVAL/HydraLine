/*! ==========================================================================
 *  HYDRALINE - Service Worker
 *
 *  Caches the heavy Flutter engine assets (main.dart.js, canvaskit.*) with
 *  a cache-first strategy, so warm visits hydrate islands in about one
 *  second instead of re-downloading the engine.
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
  event.waitUntil(self.clients.claim());
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
        if (cached) {
          return cached;
        }
        return fetch(event.request).then(function (response) {
          if (response.ok) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      });
    })
  );
});
