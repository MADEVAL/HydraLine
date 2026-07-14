/// Service Worker JS (≤2 KB).
///
/// Caches `main.dart.js` and `canvaskit.*` assets.
/// WASM streaming + `<link rel="preload">` for warm visits.
library;

const jsServiceWorker = r'''
self.addEventListener('install',function(ev){
self.skipWaiting()});
self.addEventListener('activate',function(ev){
ev.waitUntil(self.clients.claim())});
self.addEventListener('fetch',function(ev){
var url=ev.request.url;
if(url.indexOf('main.dart.js')>-1||url.indexOf('canvaskit')>-1){
ev.respondWith(caches.open('hydraline-v1').then(function(cache){
return cache.match(ev.request).then(function(r){
return r||fetch(ev.request).then(function(resp){
if(resp.ok){cache.put(ev.request,resp.clone())}return resp})})}))}});
''';
