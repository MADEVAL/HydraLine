# hydraline

Pure-Dart core of [Hydraline](../../README.md) — the foundation all other
packages build on.

## What's inside

| Module | Description |
|---|---|
| `DocumentNode` | Sealed immutable tree — headings, paragraphs, links, images, tables, islands |
| `HtmlSerializer` | Single-pass deterministic HTML serializer (buffered + streaming + fragment) |
| `SafeUrl` | Type-safe URL validation against a scheme allowlist |
| `SeoMeta` | Open Graph, Twitter Card, hreflang, canonical, meta tags |
| `JsonLd` | Type-safe JSON-LD builders (Article, Product, FAQ, BreadcrumbList, …) |
| `Sitemap` | sitemap.xml generation with defaults + auto-split at 50k URLs |
| `Robots` | robots.txt generation |
| `RouteManifest` | `hydraline.routes.yaml` parser + Dart builder |
| `IslandSpec` / `IslandStateCodec` | `data-state` props contract (JSON-safe, ~10 KB budget) |
| `SsgCollector` | Widget-to-node registration surface |
| `SeoValidator` / `Audit` | SEO validation + crawler-view audit |
| `runAuditCli` | `dart run hydraline:audit` — page audit + anti-cloaking check |
| `vanillaIslandsJs` | Level-1 vanilla islands bundle (≤ 8 KB) |
| `htmxGlueJs` | HTMX bootstrap glue (< 1 KB) |

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
print(serializer.serialize(root)); // <!DOCTYPE html><html>...
```

Runnable example: [`example/main.dart`](example/main.dart) — document
building, streaming, sitemap, robots and validation in one file.

## Audit CLI

```bash
dart run hydraline:audit https://example.com            # what a crawler sees
dart run hydraline:audit dist/index.html                # audit a local file
dart run hydraline:audit --server-integration <url>     # anti-cloaking check
```

## Documentation

- [Document Model](../../docs/document-model.md) — full node hierarchy
- [Configuration](../../docs/configuration.md) — route manifest, sitemap, SEO
- [Security](../../docs/security.md) — SafeUrl, escaping, CSP
- [Getting Started](../../docs/getting-started.md) — prerequisites, examples

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
