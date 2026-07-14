# hydraline_server

Pure-Dart server for [Hydraline](../../README.md) — SSR, streaming,
and HTMX helpers for shelf and Dart Frog.

## What's inside

| Module | Description |
|---|---|
| `hydralineMiddleware` | Route-matching shelf middleware for document/hybrid/app routes |
| `ResponseDelivery` | Buffered (bots) and chunked streaming (users) from DocumentNode |
| `HtmxResponse` | HTMX fragment rendering + `HX-Trigger` response headers |
| `Http` | Status codes, redirects, `X-Robots-Tag`, path canonicalization |
| `HydralineCache` | Pluggable cache interface + in-memory implementation |
| `Assets` | robots.txt, sitemap.xml endpoints + Flutter asset injection |
| `DartFrogAdapter` | Drop-in adapter for Dart Frog servers |
| `BotDetector` | User-Agent matching for bot-aware transport selection |

## Rules

No `package:flutter` — this package is pure Dart and works on any Dart server.

## Quick start

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

DocumentNode homePage() => DocumentRootNode(
  head: buildHead(SeoMeta(title: 'Home')),
  body: [HeadingNode(level: 1, children: [TextNode('Home')])],
);

void main() async {
  final handler = Pipeline()
    .addMiddleware(hydralineMiddleware(HydralineConfig(
      manifest: RouteManifest.builder()
        .route(RouteEntry(path: '/', mode: RouteMode.document))
        .build(),
      builders: {'/': (req, data) async => homePage()},
      botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
    )))
    .addHandler((req) => Response.notFound(''));

  await io.serve(handler, 'localhost', 8080);
}
```

## Documentation

- [Server Guide](../../docs/server.md) — full setup, streaming, HTMX, caching
- [Configuration](../../docs/configuration.md) — route manifest, SEO
- [Architecture](../../docs/architecture.md) — SSR flow, bot-aware delivery
- [Security](../../docs/security.md) — cloaking prevention, CSP
- [Getting Started](../../docs/getting-started.md) — prerequisites

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
