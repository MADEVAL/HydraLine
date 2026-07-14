## 0.0.2

- **Fixed:** builders registered under dynamic route patterns
  (`/product/:id`) are now invoked for matching concrete paths; previously
  dynamic routes silently rendered empty pages.
- **Fixed:** the HTML cache key now includes the query string;
  `/page?a=1` and `/page?a=2` no longer share one entry.
- Request paths are canonicalised (duplicate/trailing slashes) before route
  matching and cache lookup.
- ETag upgraded to 64-bit FNV-1a; `If-None-Match` handles ETag lists, weak
  validators (`W/`) and `*` per RFC 9110.
- Cacheable responses carry `Vary: Accept-Encoding`.
- **Breaking:** `HydralineCache.set` lost its unused `etag` parameter.
- `X-Robots-Tag` header name is emitted lowercase consistently.

## 0.0.1

Initial release.

- `hydralineMiddleware` - shelf middleware: route matching against the
  `RouteManifest`, SSR for `document`/`hybrid` routes via pure-Dart
  `DocumentBuilder`s, pass-through for `app` routes.
- UA-blind builder contract - `DocumentBuilder(Request, Object?)` cannot see
  the `User-Agent`; cloaking is prevented architecturally.
- Bot-aware transport - buffered (`Content-Length`) for bots, chunked
  streaming for users; byte-identical bodies.
- Automatic `X-Robots-Tag` - emitted for `noindex`/`nofollow` routes and for
  `app` routes (which default to noindex).
- `RedirectException` - 301/302/custom statuses and `.gone()` for 410 from
  inside builders.
- `HydralineCache` - pluggable cache with `HydralineCache.inMemory()`
  (max-size eviction, TTL); middleware integration with `ETag`,
  `If-None-Match` → 304 and `Cache-Control`.
- `Htmx` helpers - `renderFragment`, `response` (with `HX-Trigger` map),
  `trigger`, `redirect` (`HX-Redirect`), plus `HtmxResponse` with
  retarget/reswap headers.
- `Assets.serveCoreAssets` - robots.txt, sitemap.xml and the first-party
  L0-L1 JS bundles (`vanilla-islands.js`, `htmx-glue.js`).
- `Assets.injectFlutterAssets` - Flutter script injection for island routes.
- `Http` - status helpers, path canonicalization, `withRobots`.
- `DartFrogAdapter` - Dart Frog integration.
