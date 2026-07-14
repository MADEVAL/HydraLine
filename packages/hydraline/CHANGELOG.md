## 0.0.3

- `RouteManifestBuilder` gained `version()` and `baseUrl()` setters, so
  programmatically built manifests can carry a `base_url`.
- The serializer now routes flutter-island `data-state` through
  `IslandStateCodec.encode`, so non-JSON-safe props raise a clear
  `ArgumentError` at serialization time.
- `VanillaIslandNode.config` is serialized as a `data-config` JSON attribute
  when non-empty (previously the field was silently dropped).
- Sitemap single-quote escaping switched from `&apos;` to `&#39;` to match
  `escapeHtmlAttribute`.
- Added `issue_tracker` to the package metadata.

## 0.0.2

- **Breaking:** `HtmlSerializer()` no longer takes `SerializerOptions`; the
  dead `pretty` option is removed.
- **Breaking:** `SsgCollector.addIsland` throws `ArgumentError` for an htmx
  spec without `endpoint` or a vanilla spec without `kind` (previously
  produced dead `hx-get=""` / `data-island=""` islands silently).
- **Breaking:** `Robots.generate` throws `ArgumentError` when a user agent or
  path contains a line break (robots.txt directive injection guard).
- Flutter island placeholders now serialize their reserved size as a
  `data-size="w,h"` attribute (consumed by the client runtime for anti-CLS).
- `RouteManifest.baseUrl` exposes the parsed `base_url`.
- Sitemap XML now escapes `"`/`'` in attribute values (`xhtml:link href`).
- Audit CLI: the default HTTP fetcher (`defaultHtmlFetcher`, now public)
  applies a 30 s timeout and fails on non-2xx responses instead of auditing
  error pages.
- Escaping fast-path regexes are compiled once (hot-path micro-optimisation).

## 0.0.1

Initial release.

- `DocumentNode` - sealed, immutable semantic HTML tree: headings, paragraphs,
  sections, lists, tables, blockquote/pre/code/time, details/summary, anchors,
  images, island placeholders (Flutter / HTMX / vanilla), `UnsafeHtmlNode`,
  JSON-LD nodes.
- `HtmlSerializer` - single-pass deterministic serializer with buffered,
  streaming and fragment modes; `serialize == concat(serializeToStream)`.
- Contextual escaping (`escapeHtmlText` / `escapeHtmlAttribute`) and `SafeUrl`
  scheme-allowlist URL validation (no public constructor).
- `SeoMeta` + `buildHead()` - title, description, canonical, robots,
  Open Graph, Twitter Card, hreflang, extra meta/links.
- `JsonLd` - type-safe builders: article, product, breadcrumbList, webPage,
  organization, faq, event, recipe, review, raw.
- `Sitemap` - sitemap.xml generation with hreflang alternates, default
  changefreq/priority and auto-split into a sitemap index at 50k URLs / 50 MB.
- `Robots` - robots.txt generation.
- `RouteManifest` - `hydraline.routes.yaml` parser + Dart builder API with
  YAML round-trip.
- `IslandSpec` / `IslandManifest` / `IslandStateCodec` - `data-state` props
  contract (JSON-safe, HTML-escaped, ~10 KB budget).
- `SsgCollector` - flat registration surface for widget extraction.
- `SeoValidator` + `Audit` - SEO/safety validation and crawler-view audit.
- `dart run hydraline:audit` - CLI: standalone page audit and
  `--server-integration` buffered↔chunked body-identity check.
- Level 0-1 web assets: `vanillaIslandsJs` (≤ 8 KB), `htmxGlueJs` (< 1 KB).
- `Csp` - recommended Content-Security-Policy helper.
