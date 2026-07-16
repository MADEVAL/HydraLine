## 0.0.12

- Further shortened pubspec description; added AGENTS.md hard rules.

## 0.0.11

- Shortened pubspec description to pass pub.dev 180-char limit.

## 0.0.10

- Added "Why" section to README: explains problem, solution, and core value.

## 0.0.8

- Cross-link banner at top of README: shows all three packages.

## 0.0.7

- Better package description with cross-links; CHANGELOG references current version.

## 0.0.6

- Publisher verification: homepage switched to verified domain.

## 0.0.5

- `web/vanilla-islands.js` and `web/htmx-glue.js` mirror the inline Dart
  constants (byte-identity locked by test), so browser harnesses load the
  exact shipped bytes.
- Vanilla accordion guards a `<details>` without a `<summary>` (no null
  dereference during hydration).
- Polished README: full module catalogue, proven metrics, quick start with
  `sanitizeHtml`, `islandRuntime()`, `UnsafeHtmlNode.trusted`, web mirrors.

## 0.0.4

- `SsgCollector` gained `beginSection`/`beginList` (and `SsgListScope.beginItem`)
  for nested semantic sectioning; child scopes have their own dedup namespace
  and forward `addMeta` to the document root.
- `SafeUrl.tryParse` now rejects empty and whitespace-only input (no more
  `href=""`/`src=""` self-link footgun).
- Sitemap `lastmod` is emitted in UTC, so dates no longer shift by a day for
  local-time `DateTime`s near midnight.
- Vanilla island runtime: `Carousel`/`CopyButton` guard missing controls and
  the bootstrap loop isolates a throwing handler so one bad island cannot abort
  hydration of the rest of the page.

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
