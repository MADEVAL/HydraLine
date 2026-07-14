# Configuration

Hydraline is configured through two primary manifests — the route manifest and
the island manifest — plus additional settings for SEO, performance, caching,
and security.

## Route Manifest

The route manifest (`hydraline.routes.yaml`) is the single source of truth for
all routes and their render modes. Both the server and the SSG runner read it.

### YAML Format

```yaml
# hydraline.routes.yaml
version: "1"
base_url: https://example.com

routes:
  - path: /
    mode: document
    content_source: widget:HomePage
    metadata:
      title: Home
      description: Welcome to my site
      canonical: https://example.com/
      lang: en
      robots:
        noindex: false
        nofollow: false

  - path: /blog/:slug
    mode: document
    content_source: dart_builder:BlogPostBuilder.new
    dynamic_segments:
      slug:
        - post-1
        - post-2
        - hello-world
    metadata:
      title: Blog

  - path: /product/:id
    mode: hybrid
    content_source: dart_builder:ProductBuilder.new
    metadata:
      title: Product

  - path: /app/dashboard
    mode: app
    noindex: true
    sitemap: false
```

### Fields

| Field | Type | Description |
|---|---|---|
| `version` | string | Manifest schema version |
| `base_url` | string | Base URL for generating absolute canonical URLs |
| `routes` | list | Array of route entries |

#### Route Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `path` | string | yes | URL path (e.g. `/`, `/blog/:slug`) |
| `mode` | enum | yes | `document` \| `hybrid` \| `app` |
| `content_source` | string | no | How content is produced: `widget` (surface A), `widget:BuilderName`, or `dart_builder:BuilderName` (surface B) |
| `metadata` | object | no | Per-route SEO metadata |
| `dynamic_segments` | map | no | Param values for SSG expansion (`slug: [a, b, c]`) |
| `noindex` | bool | no | Override `noindex`; when unset, `app` routes default to `noindex` |
| `sitemap` | bool | no | Override sitemap inclusion; when unset, `document`/`hybrid` are included, `app` excluded |

#### Metadata

| Field | Type | Description |
|---|---|---|
| `title` | string | Page title |
| `description` | string | Meta description |
| `canonical` | string | Canonical URL |
| `lang` | string | Document language (`<html lang="...">`) |
| `robots.noindex` | bool | Add `noindex` meta + header |
| `robots.nofollow` | bool | Add `nofollow` meta + header |

### Dart Builder API

The same manifest can be built programmatically:

```dart
final manifest = RouteManifest.builder()
  .route(RouteEntry(
    path: '/',
    mode: RouteMode.document,
    contentSource: const WidgetContent('HomePage'),
    metadata: SeoMeta(title: 'Home', description: '...'),
  ))
  .route(RouteEntry(
    path: '/blog/:slug',
    mode: RouteMode.document,
    contentSource: const DartBuilderContent('BlogPostBuilder.new'),
    dynamicSegments: {'slug': ['post-1', 'post-2']},
  ))
  .route(RouteEntry(
    path: '/app/dashboard',
    mode: RouteMode.app,
    noindex: true,
    includeInSitemap: false,
  ))
  .build();

// Round-trip to YAML
print(manifest.toYaml());
```

## Island Manifest

The island manifest describes every island on a page. It is generated
automatically by the serializer and embedded in the HTML. The client-side
dispatcher reads it to know what to hydrate and when.

### Fields (per island)

```json
{
  "id": "calculator",
  "type": "flutter",
  "directive": "hydrateOnVisible",
  "renderMode": "ssr",
  "styleMode": "shadow",
  "size": { "width": 640, "height": 480 },
  "state": { "price": 89990 },
  "mediaQuery": null,
  "mountSelector": null
}
```

| Field | Description |
|---|---|
| `id` | Unique island identifier |
| `type` | `flutter`, `vanilla`, or `htmx` |
| `directive` | Hydration trigger: `hydrateOnLoad`, `hydrateOnIdle`, `hydrateOnVisible`, `hydrateOnInteraction`, `hydrateOnMedia`, `hydrateManual` |
| `renderMode` | `ssr` (semantic fallback) or `skeletonOnly` (placeholder only) |
| `styleMode` | `shadow` (isolated) or `scoped` (shared styles) |
| `size` | `{width, height}` in px for anti-CLS reservation |
| `state` | `Map<String, Object?>` — props passed to the island (JSON-safe types only) |
| `mediaQuery` | CSS media query for `hydrateOnMedia` (serialized as `data-media`) |
| `mountSelector` | CSS selector for conditional mounting |

### data-state Contract

Props traverse the boundary `server → HTML → client` via the `data-state`
attribute:

- **Serialization**: `JSON.stringify` on the server (with HTML attribute
  escaping), `JSON.parse` on the client. No `eval`, `Function`, or `DOMParser`.
- **Allowed types**: `String`, `int`, `double`, `bool`, `null`, `List`,
  `Map<String, dynamic>` (with allowed leaf types).
- **Forbidden**: Functions, `DateTime` (use ISO string), `Uri` (use string),
  `Color` (use int), cyclic references, `Symbol`.
- **Size limit**: ~10 KB per island. DevTools warns on excess.
- **Determinism**: `DateTime.now()`, `Math.random()`, and other non-deterministic
  values are forbidden in render-time props.

## SEO Configuration

### Sitemap

The sitemap is generated from route manifest entries. `document` and `hybrid`
routes are included by default; `app` routes are excluded.

```dart
// Generate sitemap.xml from a source
final output = await Sitemap.generate(
  source,                   // SitemapSource (list or async provider)
  baseUrl: SafeUrl.parse('https://example.com'),
  changefreq: ChangeFreq.weekly,   // default for entries without their own
  defaultPriority: 0.5,            // default for entries without their own
);
// output.files: {'sitemap.xml': '<?xml ...'}
```

When the source provides more than 50,000 URLs or the sitemap exceeds 50 MB,
the output is automatically split into a sitemap index (`sitemap.xml` →
`sitemap-1.xml`, `sitemap-2.xml`, …).

```dart
abstract class SitemapSource {
  Stream<SitemapEntry> entries();
}

class SitemapEntry {
  final SafeUrl loc;
  final DateTime? lastmod;
  final ChangeFreq? changefreq;
  final double? priority;
  final List<({String hreflang, SafeUrl href})> alternates;
}
```

### Robots.txt

```dart
final robots = Robots.generate(
  rules: [
    RobotsRule(userAgent: '*', allow: ['/'], disallow: ['/app/']),
  ],
  sitemaps: [SafeUrl.parse('https://example.com/sitemap.xml')],
);
```

### SEO Validators and Audit CLI

```bash
# What a crawler sees: title/description lengths, alt text, canonical,
# Open Graph, h1. Non-zero exit code on errors (CI-compatible).
dart run hydraline:audit https://example.com
dart run hydraline:audit dist/index.html

# Cloaking check: bot body must be byte-identical to the user body.
dart run hydraline:audit --server-integration https://example.com
```

In code, the same checks are `Audit.auditHtml(html)` and
`Audit.compareBodies(buffered, chunks)`; document trees and `SeoMeta` are
validated with `const SeoValidator().validate(target)`.

## Performance Budgets

### JS Budgets (gzip)

Values are hard limits enforced in CI:

| Asset | Budget | Level |
|---|---|---|
| Dispatcher | ≤ 2 KB | 2 |
| Custom Element | ≤ 2 KB | 2 |
| Service Worker | ≤ 2 KB | 2 |
| **Total baseline L2 JS** | **≤ 6 KB** | 2 |
| Vanilla Islands | ≤ 8 KB | 1 |
| HTMX (self-hosted) | ~14 KB | 1 |
| Virtual Views manager | ≤ 2 KB | 2 (deferred) |

### Island Bundle Budget

| Component | Budget |
|---|---|
| Base island JS (`main.dart.js` + runtime + `IslandHost`) | ≈ 450 KB (without `canvaskit.wasm` and deferred chunks) |
| `canvaskit.wasm` | ~1.1 MB (separate, SW/CDN-cached) |
| One island + dependencies (deferred chunk) | < 100 KB |
| Bundle size regression between versions | ≤ 5% |

### Core Web Vitals Targets

| Metric | Target |
|---|---|
| FCP | < 1 second |
| LCP | < 2.5 seconds |
| CLS | ≈ 0 (reserved island sizes) |
| TTFB (streaming SSR, first chunk) | < 100 ms |
| Lighthouse score (mobile, throttled) | ≥ 70 |
| Skeleton HTML per island | < 50 KB gzip |

### TTI for Flutter Islands

| Scenario | TTI |
|---|---|
| Cold cache, 4G | ~3–5 seconds |
| Cold cache, 3G | ~10–19 seconds |
| Warm cache (Service Worker) | ~1 second |

## Security Settings

### CSP (Content-Security-Policy)

Recommended header value (built into `Csp` helper):

```
default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; object-src 'none'; base-uri 'self'
```

This allows CanvasKit's WASM (`wasm-unsafe-eval`) while blocking inline scripts
(`unsafe-inline`). HTMX and vanilla JS are self-hosted as first-party assets,
fully compatible with `script-src 'self'`.

In your server code:

```dart
// As HTTP header
headers['Content-Security-Policy'] = Csp.recommendedHeaderValue();

// As meta tag (SSG)
final meta = Csp.metaTag(extraDirectives: ['img-src *']);
```

### URL Scheme Allowlist

Only these schemes are permitted in `SafeUrl`:

| Scheme | Example |
|---|---|
| `http` | `http://example.com` |
| `https` | `https://example.com` |
| `mailto` | `mailto:user@example.com` |
| `tel` | `tel:+1234567890` |
| Relative | `/path`, `./path`, `#anchor`, `?query` |

Blocked: `javascript:`, `data:`, `vbscript:`, and all other schemes.

### Sanitizer

`UnsafeHtmlNode` optionally accepts a sanitizer function:

```dart
UnsafeHtmlNode(
  rawHtml,
  sanitizer: (s) => mySanitizer.clean(s),
)
```

The validator warns when `UnsafeHtmlNode` is used without a sanitizer.

## Environment Variables

Hydraline itself does not use environment variables — all configuration is
through manifests and builder code. However, the server middleware and SSG
runner operate within the host's environment:

| Concern | Handled by |
|---|---|
| Port binding | User's shelf/Dart Frog setup |
| Database connections | User's builder functions |
| API keys / secrets | User's configuration — never logged by Hydraline |

## See Also

- [Getting Started](./getting-started.md) — installation, minimal examples
- [Server](./server.md) — how the manifest drives SSR
- [Flutter Widgets](./flutter-widgets.md) — how the manifest drives SSG
- [Security](./security.md) — CSP, SafeUrl, data-state contract
