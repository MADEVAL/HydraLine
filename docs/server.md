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
      .route(const RouteEntry(path: '/', mode: RouteMode.document))
      .route(const RouteEntry(path: '/product/:id', mode: RouteMode.hybrid))
      .route(const RouteEntry(path: '/app/dashboard', mode: RouteMode.app))
      .build();

  final config = HydralineConfig(
    manifest: manifest,
    builders: {
      '/': homeBuilder,
      '/product/:id': productBuilder,
    },
  );

  final handler = const Pipeline()
      .addMiddleware(hydralineMiddleware(config))
      .addHandler((req) => Response.ok('app shell'));

  await io.serve(handler, 'localhost', 8080);
}
```

Requests that match a `document`/`hybrid` route are rendered by the
middleware. Requests that match an `app` route are passed through to the inner
handler (your Flutter app shell). Requests that match nothing return 404 -
serve API endpoints and static assets *in front of* the middleware (see
[Complete Example](#complete-example)).

### With Dart Frog

```dart
import 'package:hydraline_server/hydraline_server.dart';

final middleware = DartFrogAdapter.middleware(HydralineConfig(
  manifest: RouteManifest.parseYaml(yamlString),
  builders: {'/': homeBuilder},
));
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
| `app` | Passes through to the inner handler (Flutter SPA). Defaults to `noindex` and exclusion from the sitemap. |

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
architecturally prevented from cloaking - it always produces the same tree for
the same input, regardless of who requested it. Keep builders deterministic:
no `DateTime.now()`, no random values.

```dart
DocumentNode buildProduct(Request req, Object? data) {
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
        size: const IslandSize(width: 640, height: 480),
        state: {'price': product.price},
      ),
    ],
  );
}
```

Builders are registered per route pattern in the `HydralineConfig`:

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

1. **Shell** - `<!DOCTYPE html>`, `<head>` with metadata and JSON-LD
2. **Static content** - headings, paragraphs, images, links
3. **Island placeholders** - skeletons with `data-state`

This allows the browser to start rendering and fetching subresources before
the full response arrives.

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
differs. This is not cloaking - cloaking means *different bodies*. The content
builder never sees the `User-Agent` header.

**Important**: `botUserAgentPattern` is read only by the transport layer, not
by the content builder. This separation is architectural, not just a convention.

Verify the invariant against a running server at any time:

```bash
dart run hydraline:audit --server-integration https://example.com
```

## HTTP Semantics

### Status Codes and Redirects

Throw `RedirectException` from a builder to issue a redirect. The location
comes first; the status is a named parameter (301 by default):

```dart
DocumentNode oldPageBuilder(Request req, Object? data) {
  throw const RedirectException('/new-location');            // 301
  // throw const RedirectException('/temp', status: 302);    // 302
  // throw const RedirectException.gone();                   // 410
}
```

| Status | How |
|---|---|
| 200 | Normal rendering |
| 301 | `throw RedirectException(location)` (default status) |
| 302 | `throw RedirectException(location, status: 302)` |
| 404 | Returned automatically when no route matches |
| 410 | `throw RedirectException.gone()` for permanently removed content |
| other | `throw RedirectException(location, status: 308)` - status + `Location` header |
| 5xx | Unhandled exceptions in the builder produce a 500 |

The standalone `Http` helper covers the same ground outside builders:
`Http.redirect`, `Http.notFound`, `Http.gone`, `Http.withRobots`,
`Http.canonicalizePath`.

### X-Robots-Tag

The middleware adds `X-Robots-Tag` automatically:

- `document`/`hybrid` routes with `noindex: true` (or metadata
  `robots.noindex/nofollow`) get `X-Robots-Tag: noindex[, nofollow]` in
  addition to the `<meta name="robots">` tag in the HTML.
- `app` routes get `X-Robots-Tag: noindex` by default; override with
  `noindex: false` in the manifest.

## HTMX Helpers

For HTMX-driven endpoints (used by `HtmxIslandNode`), render HTML fragments
without `<html>`/`<head>`:

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';

Future<Response> reviewsEndpoint(Request req) async {
  final reviews = await fetchReviews();
  final fragment = SectionNode(role: SectionRole.section, children: [
    for (final review in reviews)
      SectionNode(role: SectionRole.article, children: [
        HeadingNode(level: 3, children: [TextNode(review.title)]),
        ParagraphNode(children: [TextNode(review.body)]),
      ]),
  ]);

  return Htmx.response(
    const HtmlSerializer().serializeFragment(fragment),
    triggers: {'showConfirmation': 'Updated!'},
  );
}
```

The `Htmx` class provides:

| Method | Description |
|---|---|
| `Htmx.renderFragment(DocumentNode node)` | Serializes a fragment and returns it as `text/html` |
| `Htmx.response(String html, {triggers})` | 200 response; `triggers` become an `HX-Trigger` JSON header |
| `Htmx.trigger(String event, [String? detail])` | Builds an `HtmxTrigger` value |
| `Htmx.redirect(String url)` | Client-side redirect via `HX-Redirect` |

For full control use `HtmxResponse`:

```dart
HtmxResponse(
  body: fragment,                       // a DocumentNode
  trigger: Htmx.trigger('saved'),
  retarget: '#result',                  // HX-Retarget
  reswap: 'outerHTML',                  // HX-Reswap
).toResponse();
```

## Caching

```dart
HydralineConfig(
  manifest: manifest,
  builders: builders,
  cache: HydralineCache.inMemory(maxSize: 500),
  cacheTtl: const Duration(minutes: 5),
)
```

When a cache is configured the middleware:

- stores rendered HTML keyed by the canonical path plus query string and
  serves subsequent requests from it;
- adds a deterministic 64-bit `ETag` and answers `If-None-Match`
  revalidation (including ETag lists, weak validators and `*`) with
  `304 Not Modified`;
- emits `Vary: Accept-Encoding`, and `Cache-Control: public, max-age=<ttl>`
  when `cacheTtl` is set.

Request paths are canonicalised before route matching and cache lookup:
`/page/`, `//page` and `/page` are the same route and the same cache entry.

The `HydralineCache` interface is pluggable (implement it over Redis, files,
etc.):

| Method | Description |
|---|---|
| `get(String key)` | Returns the cached HTML or null |
| `set(String key, String html, {Duration? ttl})` | Stores with optional TTL |
| `invalidate(String key)` | Removes a cached entry |

`HydralineCache.inMemory({int maxSize = 500})` evicts the oldest entry past
`maxSize` and honours per-entry TTLs.

## Asset Serving

### L0-L1 JS Assets, robots.txt, sitemap.xml

Vanilla islands and the HTMX glue are served as first-party assets straight
from the `hydraline` package - no CDN, compatible with
`Content-Security-Policy: script-src 'self'`:

```dart
final assets = Assets.serveCoreAssets(
  sitemapXml: mySitemapXml,             // optional; 404 when omitted
  robotsTxt: myRobotsTxt,               // optional; sane default otherwise
);
// Serves: /robots.txt, /sitemap.xml, /vanilla-islands.js, /htmx-glue.js
// (also under the /assets/hydraline/ prefix)
```

### Flutter Asset Injection

For routes with Flutter islands, inject the engine scripts into a document:

```dart
final page = Assets.injectFlutterAssets(root, baseHref: '/');
// Appends <script src="/flutter_bootstrap.js" defer> and
// <script src="/main.dart.js" type="module" defer> before </body>.
```

For routes without Flutter islands, no Flutter assets are injected - the
zero-overhead guarantee.

## Complete Example

A runnable version of this example lives in
[`packages/hydraline_server/example/main.dart`](../packages/hydraline_server/example/main.dart).

```dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// ── Builders (UA-blind, deterministic) ──────────────────────────────────

DocumentNode buildHome(Request req, Object? data) => DocumentRootNode(
  head: buildHead(const SeoMeta(
    title: 'My Site',
    description: 'A Hydraline-powered website',
  )),
  body: [
    SectionNode(role: SectionRole.main, children: const [
      HeadingNode(level: 1, children: [TextNode('Welcome!')]),
      HtmxIslandNode(
        id: 'faq',
        endpoint: '/api/faq',
        fallback: [ParagraphNode(children: [TextNode('Loading FAQ…')])],
      ),
    ]),
  ],
);

// ── HTMX endpoint (served in front of the middleware) ───────────────────

Response faqEndpoint(Request req) {
  const fragment = DetailsNode(
    summary: SummaryNode(children: [TextNode('What is Hydraline?')]),
    children: [
      ParagraphNode(children: [TextNode('SEO + islands for Flutter Web.')]),
    ],
  );
  return Htmx.renderFragment(fragment);
}

// ── Main ─────────────────────────────────────────────────────────────────

void main() async {
  final pages = const Pipeline()
      .addMiddleware(hydralineMiddleware(HydralineConfig(
        manifest: RouteManifest.builder()
            .route(const RouteEntry(path: '/', mode: RouteMode.document))
            .build(),
        builders: {'/': buildHome},
        botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
        cache: HydralineCache.inMemory(),
        cacheTtl: const Duration(minutes: 5),
      )))
      .addHandler((req) => Response.ok('app shell'));

  final assets = Assets.serveCoreAssets();

  final server = await io.serve((Request req) {
    final path = req.url.path;
    if (path == 'api/faq') return faqEndpoint(req);
    if (path == 'robots.txt' || path.endsWith('.js')) return assets(req);
    return pages(req);
  }, 'localhost', 8080);

  print('Serving on http://${server.address.host}:${server.port}');
}
```

## See Also

- [Architecture](./architecture.md) - SSR flow, two-layer delivery design
- [Configuration](./configuration.md) - route manifest reference
- [Security](./security.md) - cloaking prevention, CSP
- [`hydraline_server` package README](../packages/hydraline_server/README.md)
