# hydraline

**Pure-Dart core of Hydraline — the foundation everything else builds on.**
No Flutter, no `dart:ui`, no `dart:html`. Works on any Dart VM.

Build, serialize and audit real semantic HTML from Dart: headings, paragraphs,
images with `alt`, links, tables, sections, ordered/unordered lists, and island
placeholders — all typed, all safe, all crawlable.

[![pub](https://img.shields.io/pub/v/hydraline)](https://pub.dev/packages/hydraline)
[![tests](https://img.shields.io/badge/tests-229%20passed-brightgreen)](#)

## What's inside

| Module | Description |
|---|---|
| `DocumentNode` | Sealed immutable tree: `HeadingNode`, `ParagraphNode`, `ImageNode`, `AnchorNode`, `SectionNode` (`<main>`/`<nav>`/`<article>`), `ListNode` (`<ol>`/`<ul>` + `ListItemNode`), `TableNode`, `DetailsNode`, `BlockquoteNode`, `PreNode`, `CodeNode`, `TimeNode`, `IslandPlaceholderNode`, `HtmxIslandNode`, `VanillaIslandNode`, `JsonLdNode` |
| `HtmlSerializer` | Single-pass deterministic HTML serializer — buffered, streaming, and fragment modes. O(nodes + text), 10k paragraphs in 29 ms |
| `SafeUrl` | Type-safe URL — no public constructor, scheme allowlist blocks `javascript:`/`data:` at construction. A node can never hold an unchecked URL |
| `sanitizeHtml()` | Baseline HTML sanitizer: strips `<script>` and `on*` event handlers |
| `UnsafeHtmlNode` / `.trusted()` | Opt-in raw HTML escape hatch. `.trusted()` explicitly signals reviewed content |
| `escapeHtmlText` / `escapeHtmlAttribute` | Context-aware escaping — text vs attribute, never confused. Backed by a 1e6-input XSS fuzz suite |
| `SeoMeta` / `buildHead()` | Deterministic `<head>`: title, description, canonical, viewpoint, robots, full Open Graph (with image dimensions), Twitter Card, hreflang alternates, extra meta/link |
| `JsonLd` | Type-safe JSON-LD builders: `Article`, `Product` (+Offer/price), `BreadcrumbList`, `WebPage`, `Organization`, `FAQPage`, `Event`, `Recipe`, `Review` + `raw()` escape hatch |
| `Sitemap` | `sitemap.xml` with auto-split at 50k URLs / 50 MB, hreflang per URL, `changefreq`, `priority`, `lastmod` (UTC) |
| `Robots` | `robots.txt` with programmable rules, line-break validation |
| `RouteManifest` | `hydraline.routes.yaml` parser + Dart builder — `document` / `hybrid` / `app` modes |
| `IslandSpec` / `IslandStateCodec` | `data-state` props contract — JSON-safe, validated |
| `SsgCollector` | Widget-to-node registration with nested sectioning (`beginSection`, `beginList`) |
| `islandRuntime()` | One-liner for runtime script injection: engine config + dispatcher + custom element. Optional SRI (`integrity`/`crossorigin`) |
| `SeoValidator` / `Audit` | SEO validator: title/description length, alt text, duplicate canonicals, hreflang, unsafe HTML. Audit CLI: `dart run hydraline:audit` |
| `Csp` | Recommended Content-Security-Policy: `script-src 'self' 'wasm-unsafe-eval'` |
| `vanillaIslandsJs` | Level-1 vanilla islands bundle (≤ 8 KB) — accordion, tabs, carousel, theme, copy-button, lazy-image with hardened null guards |
| `htmxGlueJs` | HTMX bootstrap glue — loads self-hosted HTMX runtime on demand |
| `web/vanilla-islands.js` | Browser-consumable mirror, byte-identical to the Dart constant (locked by test) |

## Rules

No `package:flutter`, `dart:ui`, or `dart:html` — ever. This package is pure Dart.
Enforced at build time by `melos run boundaries`.

## Quick start

```dart
import 'package:hydraline/hydraline.dart';

final root = DocumentRootNode(
  lang: 'en',
  head: buildHead(SeoMeta(
    title: 'Espresso Machine',
    description: 'Compact 15-bar espresso machine.',
    canonical: SafeUrl.parse('https://shop.example/'),
    openGraph: OpenGraph(
      type: 'product',
      image: SafeUrl.parse('https://shop.example/og.jpg'),
    ),
  ), structuredData: [JsonLd.product(name: 'Espresso', price: 249, currency: 'EUR')]),
  body: [
    HeadingNode(level: 1, children: [TextNode('Espresso Machine')]),
    ParagraphNode(children: [TextNode('Real HTML. Real rankings.')]),
    SectionNode(role: SectionRole.main, children: [
      ListNode(ordered: false, items: [
        ListItemNode(children: [ParagraphNode(children: [TextNode('Feature one')])]),
      ]),
    ]),
    IslandPlaceholderNode(
      id: 'calculator',
      directive: HydrationDirective.onVisible,
      size: IslandSize(width: 640, height: 320),
      state: {'price': 249},
    ),
    ...islandRuntime(),
  ],
);

const serializer = HtmlSerializer();
print(serializer.serialize(root));
// <!DOCTYPE html><html lang="en"><head>...<main><ol><li>...
```

```bash
dart run hydraline:audit dist/index.html       # what a crawler sees
```

## Proven

- **229 unit/widget tests** — including a 1e6-input XSS fuzz suite
- **Single-pass serializer**: 10k paragraphs 29 ms (16.7 MB/s), no quadratic concat
- **Security**: `SafeUrl` type-level allowlist, context-aware escaping, HTML sanitizer
- **CI-gated**: analyze (`--fatal-infos`), format:check, boundaries (I1), coverage

Runnable example: [`example/main.dart`](example/main.dart).

## Documentation

- [Document Model](../../docs/document-model.md) — full node hierarchy
- [Configuration](../../docs/configuration.md) — route manifest, sitemap, SEO
- [Security](../../docs/security.md) — SafeUrl, escaping, CSP, sanitizer, SRI
- [Getting Started](../../docs/getting-started.md)

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
