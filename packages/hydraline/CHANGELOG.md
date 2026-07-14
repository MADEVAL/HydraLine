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
- Level 0–1 web assets: `vanillaIslandsJs` (≤ 8 KB), `htmxGlueJs` (< 1 KB).
- `Csp` - recommended Content-Security-Policy helper.
