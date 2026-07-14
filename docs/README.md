# Hydraline

**SEO, SSR, prerender + islands for Flutter Web.** Real semantic HTML in the
first HTTP response, with hydration of interactive zones (islands) on top -
without rewriting your app and without a new framework.

| | |
|---|---|
| Packages | `hydraline` · `hydraline_server` · `hydraline_flutter` |
| Platform | Flutter Web (CanvasKit/Skwasm) + Dart servers (shelf / Dart Frog) |
| License | MIT |
| Dart / Flutter | Dart ≥ 3.9 · Flutter ≥ 3.35 |

---

## The Problem

Flutter Web renders UI into a `<canvas>` element. The first HTTP response is an
empty app-shell. Social media crawlers (Facebook, X/Twitter, LinkedIn, Telegram,
WhatsApp, Slack, Discord) don't execute JavaScript - they parse raw HTML and look
for `og:*` / `twitter:*` tags. They see an empty shell and can't build previews.
Search engines index content slower and poorer.

Existing SEO packages do runtime DOM injection *after* Flutter loads - the tags
aren't present in `view-source`. Firebase Functions + UA-sniff is cloaking (risk
of search-engine penalties).

## The Solution

Hydraline gives Flutter Web three things:

1. **Real HTML in the first response** for `document` / `hybrid` routes -
   accessible in `view-source`, without JavaScript.
2. **Flutter hydrates islands on top** via the multi-view API - static content is
   never re-rendered.
3. **Three interactivity levels** - the Flutter engine loads *only* when truly needed:

```
Level 0  Static HTML                          FCP < 100 ms, no JS
Level 1  Vanilla (~8 KB) + HTMX (~14 KB)     TTI ~50 ms, no Flutter
Level 2  Flutter islands (CanvasKit)          engine loaded on island trigger
```

80% of interactivity on content pages is covered by levels 0-1 without loading
the Flutter engine at all.

## Route Modes (per-route, coexist in one app)

| Mode | Content owner | Use for |
|---|---|---|
| `app` | CanvasKit (as today) | Dashboards, editors, private screens |
| `document` | Semantic HTML | Blog, docs, landing pages, product cards |
| `hybrid` | HTML + Flutter islands | Product with calculator, article with widget |

## Interactivity Levels

### Level 0 - Static HTML

Semantic headings, paragraphs, images with `alt`, links, `<details>`/`<summary>`
accordions. Full metadata: `title`, `meta`, Open Graph, Twitter Card, JSON-LD.
Works without any JavaScript. Skeleton placeholders reserve space for islands.

### Level 1 - Vanilla + HTMX Islands

Lightweight interactivity without the Flutter engine. **Vanilla islands** (~8 KB JS):
accordions, tabs, carousels, copy buttons, theme toggles, lazy images - each with
no-JS fallback. **HTMX islands** (~14 KB JS): forms, search, pagination, lazy
loading - server-rendered HTML fragments replace DOM without page reload.

### Level 2 - Flutter Islands

Complex interactive widgets: calculators, configurators, charts, 3D viewers.
The Flutter engine loads only when an island's hydration trigger fires
(`hydrateOnVisible`, `hydrateOnIdle`, `hydrateOnInteraction`, etc.). A Service
Worker caches the engine, making warm visits ~1 second TTI.

## Package Map

| Package | Role | Requires Flutter? |
|---|---|---|
| `hydraline` | Pure-Dart core: DocumentNode, HTML serializer, escaping, metadata, JSON-LD, sitemap, robots, manifests, validators, audit CLI, L0-L1 web assets | No |
| `hydraline_server` | Pure-Dart server: shelf/Dart Frog middleware, SSR handler, streaming delivery, HTMX helpers, caching, HTTP semantics | No |
| `hydraline_flutter` | Flutter package: `Seo.*` widgets, `Island` widget, `HydraApp`, `IslandHost`, SSG runner, go_router adapter, L2 web runtime (Custom Element, dispatcher, Service Worker) | Yes |

**Dependency rule**: `hydraline` must not import `flutter` or `dart:ui`.
`hydraline_server` must not import `flutter`. This is enforced at build time.

## No Cloaking

Bots and users receive **byte-identical document bodies**. Only the transport
differs: buffered for bots (single response), chunked streaming for users. The
content builder is architecturally UA-blind - its API doesn't accept `User-Agent`.
This invariant is verified in CI.

## Quick Start

```yaml
# pubspec.yaml
dependencies:
  hydraline: ^0.0.2
  hydraline_server: ^0.0.2    # for SSR
  hydraline_flutter: ^0.0.2   # for widgets / SSG
```

```dart
// Minimal pure-Dart document builder
import 'package:hydraline/hydraline.dart';

DocumentNode myPage() => DocumentRootNode(
  head: buildHead(SeoMeta(title: 'Hello World')),
  body: [
    HeadingNode(level: 1, children: [TextNode('Welcome!')]),
    ParagraphNode(children: [TextNode('This is a Hydraline page.')]),
  ],
);
```

```dart
// Server middleware (shelf)
import 'package:hydraline_server/hydraline_server.dart';

final handler = Pipeline()
  .addMiddleware(hydralineMiddleware(HydralineConfig(
    manifest: RouteManifest.builder()
      .route(RouteEntry(path: '/', mode: RouteMode.document))
      .build(),
    builders: {'/': (req, data) async => myPage()},
  )))
  .addHandler((req) => Response.notFound(''));
```

```dart
// Flutter widgets
import 'package:hydraline_flutter/hydraline_flutter.dart';

Widget build(BuildContext context) => HydraApp(
  child: Column(children: [
    Seo.head(SeoMeta(title: 'Product Page')),
    Seo.heading('iPhone 15', level: 1),
    Seo.text('Description of the product...'),
    Seo.image('/img/phone.png', alt: 'iPhone 15'),
    Island(
      id: 'calculator',
      type: IslandType.flutter,
      props: {'price': 89990},
      width: 640, height: 480,
    ),
  ]),
);
```

## Documentation Index

- [Getting Started](./getting-started.md) - installation, prerequisites, minimal examples
- [Architecture](./architecture.md) - project structure, subsystems, data flows
- [Document Model](./document-model.md) - DocumentNode hierarchy, all node types, metadata, escaping
- [Server](./server.md) - shelf/Dart Frog setup, SSR, streaming, HTMX, caching, bot-aware delivery
- [Flutter Widgets](./flutter-widgets.md) - Seo.* widgets, Island, HydraApp, IslandHost, SSG runner
- [Configuration](./configuration.md) - route manifest, island manifest, SEO config, budgets, security
- [Security](./security.md) - SafeUrl, contextual escaping, CSP, XSS prevention, cloaking guarantee
- [Showcase example](../example/README.md) - runnable full-stack demo (SSR + SSG + Flutter)

## What Hydraline Is Not

Hydraline is **not a framework**. It doesn't own `main()`, doesn't dictate which
router you use, doesn't replace `MaterialApp`. It doesn't automatically convert
arbitrary Flutter widgets to HTML. It doesn't execute Flutter widgets on the
server. It's a set of libraries you plug into an existing project - additively,
one route at a time.
