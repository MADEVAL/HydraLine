# hydraline

Pure-Dart core of [Hydraline](../../README.md) — the foundation all other
packages build on.

## What's inside

| Module | Description |
|---|---|
| `DocumentNode` | Sealed immutable tree — headings, paragraphs, links, images, tables, islands |
| `HtmlSerializer` | Single-pass deterministic HTML serializer (buffered + streaming) |
| `SafeUrl` | Type-safe URL validation against scheme allowlist |
| `SeoMeta` | Open Graph, Twitter Card, hreflang, canonical, meta tags |
| `JsonLd` | Type-safe JSON-LD builders (Article, Product, FAQ, BreadcrumbList, etc.) |
| `Sitemap` | sitemap.xml generation with auto-split at 50k URLs |
| `Robots` | robots.txt generation |
| `RouteManifest` | hydraline.routes.yaml parser + Dart builder |
| `SsgCollector` | Widget-to-node registration surface |
| `Audit` | CLI audit — what crawler sees + body-identity comparator |
| `vanillaIslandsJs` | Level-1 vanilla islands bundle (<8 KB) |
| `htmxGlueJs` | HTMX bootstrap glue (<14 KB) |

## Rules

No `package:flutter`, `dart:ui`, or `dart:html` — ever. This package is
pure Dart.

## Quick start

```dart
import 'package:hydraline/hydraline.dart';

final root = DocumentRootNode(
  head: buildHead(SeoMeta(
    title: 'My Page',
    description: 'A Hydraline-powered page',
    openGraph: OpenGraph(
      title: 'My Page',
      image: SafeUrl.parse('https://example.com/og.png'),
    ),
  )),
  body: [
    HeadingNode(level: 1, children: [TextNode('Welcome')]),
    ParagraphNode(children: [TextNode('This is real HTML from Dart.')]),
  ],
);

const serializer = HtmlSerializer();
print(serializer.serialize(root)); // <!DOCTYPE html><html lang="en">...
```

## Documentation

- [Document Model](../../docs/document-model.md) — full node hierarchy
- [Configuration](../../docs/configuration.md) — route manifest, sitemap, SEO
- [Security](../../docs/security.md) — SafeUrl, escaping, CSP
- [Getting Started](../../docs/getting-started.md) — prerequisites, examples

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
