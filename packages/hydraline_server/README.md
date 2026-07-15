# hydraline_server

**Pure-Dart SSR for Hydraline — streaming, caching, and HTMX helpers for
shelf and Dart Frog.** No Flutter dependency. Works on any Dart server.

Turn a `DocumentNode` tree into an HTTP response: real HTML in `view-source`
for crawlers, chunked streaming for humans, byte-identical bodies (anti-cloaking
by architecture). Add SEO to one route, keep the rest on your existing server.

[![pub](https://img.shields.io/pub/v/hydraline_server)](https://pub.dev/packages/hydraline_server)
[![tests](https://img.shields.io/badge/tests-107%20passed-brightgreen)](#)

## What's inside

| Module | Description |
|---|---|
| `hydralineMiddleware()` | Route-matching shelf middleware — `document` / `hybrid` / `app` modes, builder dispatch, redirect handling |
| `HydralineConfig` | Configuration: manifest, builders, cache, TTL, bot UA pattern |
| `DocumentBuilder` | Builder typedef — receives `Request` + matched `RouteEntry` as `data`. Architecturally UA-blind |
| `ResponseDelivery` | Buffered (bots) and chunked streaming (users) from a `DocumentNode` tree |
| `HydralineCache` | Pluggable cache interface + `InMemoryCache` with configurable `maxSize` and `maxEntryBytes` byte cap |
| `Http` | Status helpers: `redirect()` (301/302/303/307/308), `notFound()`, `gone()`, `withRobots()`, path canonicalization |
| `RedirectException` | Redirect from inside a builder — `.gone()` (410) and custom status |
| `Htmx` / `HtmxResponse` | Fragment rendering, `HX-Trigger`, `HX-Retarget`, `HX-Reswap`, `HX-Redirect` with CRLF validation |
| `HtmxTrigger` | Trigger helper: bare event name or `{event: detail}` JSON |
| `Assets` | `robots.txt`, `sitemap.xml`, L0-L1 JS serving, Flutter asset injection with escaped `baseHref` |
| `DartFrogAdapter` | Drop-in adapter for Dart Frog servers |

## Automatic behaviours

- **HEAD handling** — same status + headers as GET, empty body
- **ETag / 304** — deterministic 64-bit FNV-1a hash over the rendered HTML, `If-None-Match` revalidation (RFC 9110)
- **Cache-Control / Vary** — `max-age` from TTL, `Vary: Accept-Encoding`
- **X-Robots-Tag** — `noindex` for `app` routes, `nofollow` from route metadata
- **Cache-key normalisation** — `?a=1&b=2` and `?b=2&a=1` share one entry
- **Bot-aware transport** — buffered (Content-Length) when cache is configured or bot UA matched; chunked for humans
- **Anti-cloaking** — builders physically cannot see `User-Agent`. Byte-identical bodies verified by CI test
- **HTMX header safety** — CRLF rejected at construction (response-splitting prevention)

## Quick start

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

DocumentNode home(Request req, Object? data) => DocumentRootNode(
  head: buildHead(const SeoMeta(title: 'Home')),
  body: const [
    HeadingNode(level: 1, children: [TextNode('Home')]),
  ],
);

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(hydralineMiddleware(HydralineConfig(
        manifest: RouteManifest.builder()
            .route(const RouteEntry(path: '/', mode: RouteMode.document))
            .build(),
        builders: {'/': home},
        botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
        cache: HydralineCache.inMemory(maxSize: 500),
        cacheTtl: const Duration(minutes: 5),
      )))
      .addHandler((req) => Response.ok('app shell'));

  // Asset endpoints: robots.txt, sitemap.xml, vanilla/htmx JS
  final assets = Assets.serveCoreAssets();

  await io.serve((req) {
    final path = req.url.path;
    if (path == 'robots.txt' || path == 'sitemap.xml' || path.endsWith('.js')) {
      return assets(req);
    }
    return handler(req);
  }, 'localhost', 8080);
}
```

```bash
curl -N http://localhost:8080/              # chunked streaming (humans)
curl -A Googlebot http://localhost:8080/    # buffered (bots) — same bytes
curl -I http://localhost:8080/              # HEAD → 200, etag, content-type
curl -H "If-None-Match: \"...\"" ...       # 304 Not Modified
```

## Proven

- **107 unit/integration tests** — route matching, cache lifecycle, ETag/304, HEAD, redirects, SSR invariants (anti-cloaking byte-identity), HTMX headers
- **SSR-invariant CI**: bot vs human bodies are byte-identical — proven by test
- **Cache-key normalisation**: query-parameter ordering doesn't fragment the cache
- **HEAD semantics**: same status and headers as GET, empty body

Runnable example: [`example/main.dart`](example/main.dart) — SSR, streaming,
bot-aware delivery, caching and HTMX endpoint in one file.

## Documentation

- [Server Guide](../../docs/server.md) — full setup, streaming, HTMX, caching
- [Configuration](../../docs/configuration.md) — route manifest, SEO
- [Architecture](../../docs/architecture.md) — SSR flow, bot-aware delivery
- [Security](../../docs/security.md) — cloaking prevention, CSP, header injection
- [Getting Started](../../docs/getting-started.md)

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
