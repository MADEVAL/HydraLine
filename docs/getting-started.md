# Getting Started

## Prerequisites

- **Dart SDK** ≥ 3.9
- **Flutter SDK** ≥ 3.35 (only for `hydraline_flutter`; core and server work with plain Dart)
- A **Dart server** (shelf, Dart Frog) for SSR - or static hosting for SSG
- A **Flutter Web** application to add SEO to

## Installation

Add the packages you need to your `pubspec.yaml`:

```yaml
dependencies:
  hydraline: ^0.0.2           # always needed
  hydraline_server: ^0.0.2    # for SSR / HTMX
  hydraline_flutter: ^0.0.2   # for Flutter widgets / SSG
```

If you only need a static site (SSG, no server), you can skip `hydraline_server`.
If you only need server-side rendering with pure-Dart builders, you can skip
`hydraline_flutter`.

## Concepts

### DocumentNode

`DocumentNode` is the central data model. It's a tree of semantic HTML nodes
(headings, paragraphs, links, images, lists, tables, island placeholders, etc.).
Everything - SSR, SSG, and the serializer - works from this single tree.

The tree is built one of two ways:

- **Pure-Dart builders** (surface B) - construct nodes directly. Works on the
  server and in tests without Flutter.
- **Flutter widgets** (surface A) - `Seo.text()`, `Seo.image()`, `Island()` etc.
  self-register into a collector during SSG extraction.

Both surfaces produce an identical `DocumentNode`. One serializer handles both.

### Routes and Modes

Every route in your app has a **render mode**:

| Mode | Description |
|---|---|
| `app` | Flutter CanvasKit renders everything. Use for dashboards, editors, private areas. |
| `document` | Pure semantic HTML. No Flutter engine on the page. Use for blogs, docs, landing pages. |
| `hybrid` | Semantic HTML for SEO content + Flutter islands for interactive zones. |

Modes are configured per-route in `hydraline.routes.yaml`.

### Islands

An **island** is an isolated interactive zone on an otherwise static page. Three
types exist:

- **Vanilla** - lightweight JS widgets (accordions, tabs, carousels). ~8 KB, no Flutter.
- **HTMX** - server-driven HTML fragments (forms, lazy loading). ~14 KB, no Flutter.
- **Flutter** - complex CanvasKit-rendered widgets. Engine loaded on trigger.

Islands hydrate according to a **hydration directive**:

| Directive | Trigger |
|---|---|
| `hydrateOnLoad` | Immediately on page load |
| `hydrateOnIdle` | When the main thread is idle (default) |
| `hydrateOnVisible` | When the island scrolls into the viewport |
| `hydrateOnInteraction` | On first click, focus, or touch |
| `hydrateOnMedia(q)` | When a CSS media query matches |
| `hydrateManual` | Via explicit JS API call |

### Delivery

Hydraline supports two delivery paths:

- **SSG (Static Site Generation)** - HTML is generated at build time.
  Outputs a `dist/` directory ready for static hosting.
- **SSR (Server-Side Rendering)** - HTML is generated at request time from
  pure-Dart builders. Supports streaming delivery.

## Minimal Static Site (SSG)

Describe your routes:

```yaml
# hydraline.routes.yaml
base_url: https://example.com   # used for absolute sitemap URLs
routes:
  - path: /
    mode: document
    metadata:
      title: My Blog
      description: A blog built with Hydraline
      lang: en
  - path: /blog/:slug
    mode: document
    dynamic_segments:
      slug: [post-1, post-2]
```

Generate the site:

```bash
dart run hydraline_flutter:build hydraline.routes.yaml dist
# dist/: index.html, blog/post-1.html, blog/post-2.html,
#        sitemap.xml, robots.txt
```

Register pure-Dart page builders for real body content (see
[Flutter Widgets → SSG Runner](./flutter-widgets.md#ssg-runner)), or extract
content from your widgets with `SsgSandbox` + `SsgCollector`.

## Minimal Flutter Page (widgets)

```dart
// lib/pages/blog_page.dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) => HydraApp(
    child: Column(children: [
      Seo.head(SeoMeta(
        title: 'My Blog',
        description: 'A blog built with Hydraline',
        openGraph: OpenGraph(
          title: 'My Blog',
          type: 'website',
          image: SafeUrl.parse('https://example.com/og.png'),
        ),
      )),
      Seo.heading('Welcome to My Blog', level: 1),
      Seo.text('This page is rendered as semantic HTML for SEO.'),
      Seo.image('/images/hero.png', alt: 'Hero banner', width: 1200, height: 630),
      Seo.link(href: '/about', child: const Text('About me')),
    ]),
  );
}
```

## Minimal Server (SSR)

```dart
// server.dart
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

DocumentNode buildHome(Request req, Object? data) => DocumentRootNode(
  head: buildHead(const SeoMeta(
    title: 'Hello from SSR',
    description: 'Rendered at request time',
  )),
  body: const [
    HeadingNode(level: 1, children: [TextNode('Hello, world!')]),
    ParagraphNode(children: [TextNode('This page is server-rendered.')]),
  ],
);

void main() async {
  final manifest = RouteManifest.builder()
      .route(const RouteEntry(path: '/', mode: RouteMode.document))
      .build();

  final handler = const Pipeline()
      .addMiddleware(hydralineMiddleware(HydralineConfig(
        manifest: manifest,
        builders: {'/': buildHome},
      )))
      .addHandler((req) => Response.ok('app shell'));

  final server = await io.serve(handler, 'localhost', 8080);
  print('Listening on ${server.address.host}:${server.port}');
}
```

## Verify What Crawlers See

```bash
dart run hydraline:audit http://localhost:8080/          # SEO audit
dart run hydraline:audit --server-integration http://localhost:8080/  # anti-cloaking
```

## Next Steps

- [Full-stack showcase](../example/README.md) - runnable demo of all three packages
- [Document Model](./document-model.md) - full `DocumentNode` reference
- [Server](./server.md) - SSR, streaming, HTMX, caching
- [Flutter Widgets](./flutter-widgets.md) - widget API reference
- [Configuration](./configuration.md) - route manifest, islands, SEO settings
- [Security](./security.md) - escaping, SafeUrl, CSP, anti-cloaking
