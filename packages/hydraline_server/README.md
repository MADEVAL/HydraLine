# hydraline_server

Pure-Dart server for [Hydraline](../../README.md) — SSR, streaming,
and HTMX helpers for shelf and Dart Frog.

## What's inside

| Module | Description |
|---|---|
| `hydralineMiddleware` | Route-matching shelf middleware for document/hybrid/app routes |
| `ResponseDelivery` | Buffered (bots) and chunked streaming (users) from DocumentNode |
| `HydralineCache` | Pluggable cache + in-memory implementation; ETag / 304 / Cache-Control |
| `Htmx` / `HtmxResponse` | Fragment rendering, `HX-Trigger`, `HX-Redirect`, retarget/reswap |
| `RedirectException` | 301/302/custom + `.gone()` (410) from inside builders |
| `Http` | Status helpers, `X-Robots-Tag`, path canonicalization |
| `Assets` | robots.txt, sitemap.xml, first-party L0–L1 JS + Flutter asset injection |
| `DartFrogAdapter` | Drop-in adapter for Dart Frog servers |

## Rules

No `package:flutter` — this package is pure Dart and works on any Dart server.

Automatic behaviors: bot-aware transport (byte-identical bodies),
`X-Robots-Tag` for noindex routes and `app` routes, ETag revalidation when a
cache is configured.

## Quick start

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

DocumentNode homePage(Request req, Object? data) => DocumentRootNode(
  head: buildHead(const SeoMeta(title: 'Home')),
  body: const [
    HeadingNode(level: 1, children: [TextNode('Home')]),
  ],
);

void main() async {
  final handler = const Pipeline()
      .addMiddleware(hydralineMiddleware(HydralineConfig(
        manifest: RouteManifest.builder()
            .route(const RouteEntry(path: '/', mode: RouteMode.document))
            .build(),
        builders: {'/': homePage},
        botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
        cache: HydralineCache.inMemory(),
        cacheTtl: const Duration(minutes: 5),
      )))
      .addHandler((req) => Response.ok('app shell'));

  await io.serve(handler, 'localhost', 8080);
}
```

Runnable example: [`example/main.dart`](example/main.dart) — SSR, streaming,
bot-aware delivery, caching and an HTMX endpoint.

## Documentation

- [Server Guide](../../docs/server.md) — full setup, streaming, HTMX, caching
- [Configuration](../../docs/configuration.md) — route manifest, SEO
- [Architecture](../../docs/architecture.md) — SSR flow, bot-aware delivery
- [Security](../../docs/security.md) — cloaking prevention, CSP
- [Getting Started](../../docs/getting-started.md) — prerequisites

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
