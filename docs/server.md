# Server

`hydraline_server` provides SSR (server-side rendering) for Dart HTTP servers.
It plugs into shelf or Dart Frog via middleware and renders `DocumentNode` trees
from pure-Dart builders.

## Setup

### With shelf

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final manifest = RouteManifest.builder()
    .route(RouteEntry(path: '/', mode: RouteMode.document))
    .route(RouteEntry(path: '/product/:id', mode: RouteMode.hybrid))
    .route(RouteEntry(path: '/app/dashboard', mode: RouteMode.app))
    .build();

  final config = HydralineConfig(
    manifest: manifest,
    builders: {
      '/': homeBuilder,
      '/product/:id': productBuilder,
    },
  );

  final handler = Pipeline()
    .addMiddleware(hydralineMiddleware(config))
    .addHandler((req) => Response.notFound('Not found'));

  final server = await io.serve(handler, 'localhost', 8080);
}
```

### With Dart Frog

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:hydraline_server/hydraline_server.dart';

Handler middleware(Handler handler) {
  final config = HydralineConfig(
    manifest: RouteManifest.parseYaml(yamlString),
    builders: {'/': homeBuilder},
  );

  final adapter = DartFrogAdapter(config);
  return adapter.wrap(handler);
}
```

## Route Configuration

Routes are defined in `hydraline.routes.yaml` or via the `RouteManifest`
Dart API. The manifest is the single source of truth for both the server
and the SSG runner.

```yaml
# hydraline.routes.yaml
routes:
  - path: /
    mode: document
    metadata:
      title: Home
      description: Welcome to my site
      canonical: https://example.com/
  - path: /blog/:slug
    mode: document
  - path: /product/:id
    mode: hybrid
    metadata:
      title: Product
  - path: /app/dashboard
    mode: app
```

### Route Modes

| Mode | Behaviour |
|---|---|
| `document` | Full HTML from a `DocumentBuilder`. No Flutter engine required. |
| `hybrid` | Full HTML from a `DocumentBuilder`. Island placeholders are included for Flutter hydration. |
| `app` | Passes through to the inner handler (Flutter SPA). Defaults to `noindex` and exclusion from sitemap. Optional `document`-fallback for bots. |

## Document Builders

A `DocumentBuilder` is a pure-Dart function that builds a `DocumentNode` tree
at request time:

```dart
typedef DocumentBuilder = FutureOr<DocumentNode> Function(
  Request request,
  Object? data,
);
```

The signature deliberately **does not accept `User-Agent`**. The builder is
architecturally prevented from cloaking — it always produces the same tree for
the same input, regardless of who requested it.

```dart
DocumentRootNode buildProduct(Request req, Object? data) {
  // Parse route params, fetch data from DB, etc.
  final productId = req.url.pathSegments.last;
  final product = fetchProduct(productId);

  return DocumentRootNode(
    head: buildHead(SeoMeta(
      title: product.name,
      description: product.description,
      canonical: SafeUrl.parse('https://example.com/product/$productId'),
    )),
    body: [
      HeadingNode(level: 1, children: [TextNode(product.name)]),
      ParagraphNode(children: [TextNode(product.description)]),
      IslandPlaceholderNode(
        id: 'calculator',
        size: IslandSize(width: 640, height: 480),
        state: {'price': product.price},
      ),
    ],
  );
}
```

Builders are registered per-path in the `HydralineConfig`:

```dart
HydralineConfig(
  manifest: manifest,
  builders: {
    '/': homeBuilder,
    '/product/:id': productBuilder,
  },
)
```

## SSR Delivery

### Buffered Mode

The full HTML is rendered and sent as a single response with `Content-Length`.
Used by default for bots. Gives crawlers a complete document in one chunk.

### Chunked Streaming

HTML is sent progressively as chunks using `Transfer-Encoding: chunked`.
The serializer emits in document order:

1. **Shell** — `<!DOCTYPE html>`, `<head>` with metadata and JSON-LD
2. **Static content** — headings, paragraphs, images, links
3. **Island placeholders** — skeletons with `data-state`

This allows the browser to start rendering and fetching subresources before
the full response arrives. TTFB (first chunk) is < 100ms for most routes.

### Bot-Aware Transport

```dart
HydralineConfig(
  manifest: manifest,
  builders: builders,
  botUserAgentPattern: RegExp(r'Googlebot|bingbot|Twitterbot|facebookexternalhit'),
)
```

When `botUserAgentPattern` is configured and the request's `User-Agent` matches:
- **Bots** get buffered delivery (single response, `Content-Length`)
- **Users** get chunked streaming (`Transfer-Encoding: chunked`)

The body bytes are **identical** in both cases. Only the transport encoding
differs. This is not cloaking — cloaking means *different bodies*. The content
builder never sees the `User-Agent` header.

**Important**: `botUserAgentPattern` is read only by the transport layer, not
by the content builder. This separation is architectural, not just a convention.

## HTTP Semantics

### Status Codes and Redirects

Throw `RedirectException` from a builder to issue a redirect:

```dart
DocumentRootNode redirectBuilder(Request req, Object? data) {
  if (someCondition) {
    throw const RedirectException(301, '/new-location');
  }
  // ... normal rendering
}
```

| Status | Method |
|---|---|
| 200 | Normal rendering |
| 301 | `Response.movedPermanently(location)` via `RedirectException(301, ...)` |
| 302 | `Response.found(location)` via `RedirectException(302, ...)` |
| 404 | `Response.notFound(...)` — returned when no route matches |
| 410 | Throw `RedirectException(410, ...)` for permanently removed content |
| 5xx | Unhandled exceptions in the builder produce a 500 |

### X-Robots-Tag

When a route has `noindex: true` (explicitly or because `mode: app`), the
server adds `X-Robots-Tag: noindex` to the response headers in addition to
the `<meta name="robots">` tag in the HTML body.

## HTMX Helpers

For HTMX-driven endpoints (used by `HtmxIslandNode`), render HTML fragments
without `<html>`/`<head>`:

```dart
import 'package:hydraline_server/hydraline_server.dart';

Future<Response> reviewsEndpoint(Request req) async {
  final reviews = await fetchReviews();
  final fragment = DocumentRootNode(body: [
    for (final review in reviews)
      SectionNode(role: SectionRole.article, children: [
        HeadingNode(level: 3, children: [TextNode(review.title)]),
        ParagraphNode(children: [TextNode(review.body)]),
      ]),
  ]);

  return Htmx.response(
    const HtmlSerializer().serializeFragment(fragment),
    triggers: {
      'showConfirmation': 'Updated!',
    },
  );
}
```

The `Htmx` class provides helpers:

| Method | Description |
|---|---|
| `Htmx.response(String html, {Map<String, String>? triggers})` | Returns a 200 response with HTMX trigger headers |
| `Htmx.trigger(String event, [String? detail])` | Creates an `HtmxTrigger` for response headers |
| `Htmx.redirect(String url)` | Returns a response that triggers client-side redirect via HTMX |

## Caching

```dart
final cache = HydralineCache.inMemory(maxSize: 500);

HydralineConfig(
  manifest: manifest,
  builders: builders,
  cache: cache,
)
```

The cache stores rendered HTML keyed by path. Keys to `HydralineCache`:

| Method | Description |
|---|---|
| `get(String key)` | Returns cached value or null |
| `set(String key, String value, {Duration? ttl})` | Stores with optional TTL |
| `invalidate(String key)` | Removes a cached entry |

The middleware sets `Cache-Control` headers based on configured TTL and
supports `ETag`/`If-None-Match` for conditional requests.

## Asset Injection

For routes with Flutter islands, the server injects:

- `<link rel="preload">` for `flutter_bootstrap.js`, `main.dart.js`, `canvaskit.wasm`
- Absolute paths to Flutter assets (`/main.dart.js`, `/canvaskit/`, etc.)
- `<base href="/">` for correct resolution on nested path routes

For routes without Flutter islands, zero Flutter assets are injected.

### Serving L0–L1 Assets

Vanilla islands and HTMX scripts are served as first-party assets from the
`hydraline` package. No external CDN dependencies — compatible with
`Content-Security-Policy: script-src 'self'`.

```dart
// Serve vanilla islands JS
import 'package:hydraline/hydraline.dart';

// The vanillaIslandsJs constant contains the minified JS bundle (~8 KB)
// The htmxGlueJs constant contains the HTMX runtime (~14 KB)
```

The server's asset handler (`assets_handler.dart`) serves these along with
`sitemap.xml` and `robots.txt`.

## Complete Example

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// ── Builders (UA-blind) ──────────────────────────────────────────────────

DocumentRootNode buildHome(Request req, Object? data) => DocumentRootNode(
  head: buildHead(SeoMeta(
    title: 'My Site',
    description: 'A Hydraline-powered website',
    openGraph: OpenGraph(title: 'My Site', type: 'website'),
  )),
  body: [
    SectionNode(role: SectionRole.main, children: [
      HeadingNode(level: 1, children: [TextNode('Welcome!')]),
      ParagraphNode(children: [TextNode('Rendered at: ${DateTime.now()}')]),
    ]),
  ],
);

// ── HTMX endpoint ────────────────────────────────────────────────────────

Future<Response> faqEndpoint(Request req) async {
  final items = [
    ('What is Hydraline?', 'SEO + islands for Flutter Web.'),
    ('Is it a framework?', 'No. It is a set of libraries.'),
  ];
  final fragment = DocumentRootNode(body: [
    for (final (q, a) in items)
      DetailsNode(
        summary: SummaryNode(children: [TextNode(q)]),
        children: [ParagraphNode(children: [TextNode(a)])],
      ),
  ]);
  return Htmx.response(
    const HtmlSerializer().serializeFragment(fragment),
  );
}

// ── Main ─────────────────────────────────────────────────────────────────

void main() async {
  final manifest = RouteManifest.builder()
    .route(RouteEntry(path: '/', mode: RouteMode.document))
    .route(RouteEntry(
      path: '/api/faq',
      mode: RouteMode.document,
      noindex: true,
    ))
    .build();

  final handler = Pipeline()
    .addMiddleware(hydralineMiddleware(HydralineConfig(
      manifest: manifest,
      builders: {'/': buildHome},
      botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
    )))
    .addHandler((req) {
      if (req.url.path == 'api/faq') return faqEndpoint(req);
      return Response.notFound('Not found');
    });

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
```
