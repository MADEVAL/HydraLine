# Getting Started

## Prerequisites

- **Dart SDK** ≥ 3.9
- **Flutter SDK** ≥ 3.35 (only for `hydraline_flutter`; core and server work with plain Dart)
- A **Dart server** (shelf, Dart Frog) for SSR — or static hosting for SSG
- A **Flutter Web** application to add SEO to

## Installation

```yaml
# pubspec.yaml
dependencies:
  hydraline: ^0.0.4           # always needed
  hydraline_server: ^0.0.4    # for SSR / HTMX
  hydraline_flutter: ^0.0.4   # for Flutter widgets / SSG
```

Skip `hydraline_server` for static-only sites (SSG). Skip `hydraline_flutter`
for pure-Dart builders without Flutter widgets.

## Adding SEO to an Existing Flutter Web App

Hydraline is **additive**. Your existing `main()` and `MaterialApp` don't change.
You add SEO route by route:

```
Step 1: create hydraline.routes.yaml       (which routes get SEO)
Step 2: write a page builder               (pure Dart, or Seo.* widgets)
Step 3: wire SSR or SSG                    (two lines of code)
Result: /blog is real HTML in view-source; /app still runs CanvasKit
```

## Concepts

### DocumentNode

`DocumentNode` is the central data model — a tree of semantic HTML nodes
(headings, paragraphs, links, images, lists, tables, island placeholders, etc.).
It is **not** Flutter widget trees. Serialization is single-pass, deterministic,
and produces valid HTML5.

### Route modes

Every route in `hydraline.routes.yaml` has a mode:

| Mode | What the crawler sees | Flutter involved? |
|---|---|---|
| `document` | Full semantic HTML | No |
| `hybrid` | Semantic HTML + island placeholders | Yes, per-island on trigger |
| `app` | Empty shell (Flutter CanvasKit) | Yes — auto `noindex` |

### Two surfaces, same HTML

Hydraline gives you two ways to build the same page, producing **byte-identical
semantic HTML**:

| Surface | What you write | Best for |
|---|---|---|
| **A — Seo.\* widgets** | Flutter widgets inside `HydraApp` / `SsgSandbox` | Teams that think in Flutter; widget tests |
| **B — pure-Dart builders** | `DocumentRootNode` / `HeadingNode` / ... in `.dart` files | CI pipelines; content teams; SSG |

You can mix both: surface A for product pages, surface B for blog posts. The
serializer produces the same HTML from either.

## Option A — Seo.* Widgets (Flutter-native)

Replace the root of your page widget tree with `HydraApp` and `SsgSandbox`:

```dart
import 'package:hydraline_flutter/hydraline_flutter.dart';

Widget productPage() => SsgSandbox(
  collector: SsgCollector('/product/123'),
  child: HydraApp(
    child: Column(children: [
      Seo.head(SeoMeta(
        title: 'Product — Espresso Machine',
        description: 'Compact 15-bar espresso machine.',
        canonical: SafeUrl.parse('https://shop.example/product/123'),
        openGraph: OpenGraph(type: 'product',
            image: SafeUrl.parse('https://shop.example/og.jpg')),
      )),
      Seo.heading('Espresso Machine', level: 1),
      Seo.text('Real HTML. Real rankings.'),
      Seo.image('/img/espresso.jpg', alt: 'Espresso machine', width: 800, height: 600),
      Seo.section(role: SectionRole.main, children: [
        Seo.list(ordered: false, items: [
          Seo.text('Feature one'),
          Seo.text('Feature two'),
        ]),
      ]),
      Island(
        id: 'calculator-123',
        type: IslandType.flutter,
        props: {'price': 249},
        width: 640, height: 320,
        directive: HydrationDirective.onVisible,
      ),
    ]),
  ),
);
```

- Each `Seo.*` widget renders visually AND registers a `DocumentNode` into the
  collector. At extraction time, `seal()` produces the same `DocumentRootNode`
  that a pure-Dart builder would.
- `SsgSandbox` provides stub `MediaQuery`/`Directionality` so extraction never
  fails on missing Flutter ancestors.
- Widget-based tests use `flutter test --tags ssg`.

## Option B — Pure-Dart Builders (no Flutter dependency)

```dart
import 'package:hydraline/hydraline.dart';

DocumentNode productPage() => DocumentRootNode(
  head: buildHead(SeoMeta(
    title: 'Product — Espresso Machine',
    description: 'Compact 15-bar espresso machine.',
    canonical: SafeUrl.parse('https://shop.example/product/123'),
    openGraph: OpenGraph(type: 'product',
        image: SafeUrl.parse('https://shop.example/og.jpg')),
  )),
  body: [
    HeadingNode(level: 1, children: [TextNode('Espresso Machine')]),
    ParagraphNode(children: [TextNode('Real HTML. Real rankings.')]),
    ImageNode(
      src: SafeUrl.parse('/img/espresso.jpg'),
      alt: 'Espresso machine', width: 800, height: 600,
    ),
    SectionNode(role: SectionRole.main, children: [
      ListNode(ordered: false, items: [
        ListItemNode(children: [ParagraphNode(children: [TextNode('Feature one')])]),
        ListItemNode(children: [ParagraphNode(children: [TextNode('Feature two')])]),
      ]),
    ]),
    IslandPlaceholderNode(
      id: 'calculator-123',
      directive: HydrationDirective.onVisible,
      size: IslandSize(width: 640, height: 320),
      state: {'price': 249},
    ),
    // Inject the island runtime: custom element + dispatcher + engine location.
    ...islandRuntime(),
  ],
);
```

### Securing your scripts with SRI

`islandRuntime()` accepts optional Subresource Integrity hashes. Compute them
once and hardcode — the browser will reject a tampered runtime even on a
compromised CDN:

```dart
...islandRuntime(
  islandElementIntegrity: 'sha384-...',   // $ openssl dgst -sha384 -binary | base64
  dispatcherIntegrity: 'sha384-...',
),
```

## Route Manifest

Create `hydraline.routes.yaml` in your project root:

```yaml
version: "1"
base_url: https://mysite.example
routes:
  - path: /
    mode: document
    metadata:
      title: Home
      description: Welcome to my site.

  - path: /product/:id
    mode: hybrid
    dynamic_segments:
      id: [espresso, grinder]

  - path: /app/dashboard
    mode: app
    noindex: true
```

- `document` / `hybrid` routes get real SEO HTML.
- `app` routes pass through to your existing Flutter Web app (auto `noindex`).
- `dynamic_segments` expand to concrete paths for SSG or are matched at runtime
  for SSR.

## SSR (Server-Side Rendering)

```dart
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final manifest = RouteManifest.parseYaml(
    await File('hydraline.routes.yaml').readAsString(),
  );

  final config = HydralineConfig(
    manifest: manifest,
    builders: {
      '/': (request, data) => homePage(),
      '/product/:id': (request, data) => productPage(),
    },
    botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
    cache: HydralineCache.inMemory(maxSize: 500),
    cacheTtl: Duration(minutes: 10),
  );

  final handler = Pipeline()
    .addMiddleware(hydralineMiddleware(config))
    .addHandler((req) => Response.ok('flutter app shell'));

  // Asset endpoints: robots.txt, sitemap.xml, vanilla/htmx JS
  final assets = Assets.serveCoreAssets();

  final server = await io.serve((req) {
    final path = req.url.path;
    if (path == 'robots.txt' || path == 'sitemap.xml' || path.endsWith('.js')) {
      return assets(req);
    }
    return handler(req);
  }, 'localhost', 8080);
}
```

The `data` parameter on builders receives the matched `RouteEntry` so you can
read route metadata without re-parsing the URL.

## SSG (Static Site Generation)

```dart
import 'package:hydraline_flutter/build.dart';

Future<void> main() async {
  await runSsgCli(
    manifestPath: 'hydraline.routes.yaml',
    outputDir: 'dist',
    islandFactories: {'calculator': IslandType.flutter},
    builders: {
      '/': (path) => homePage(),
      '/product/:id': (path) => productPage(path.split('/').last),
    },
  );
}
```

```bash
dart run your_app:build
# dist/: HTML pages + sitemap.xml + robots.txt + runtime JS — ready for any static host.
```

## Island Runtime

For hybrid routes with Flutter islands, the page needs the Hydraline runtime
scripts. Use the one-liner helper:

```dart
// Append to the body of any DocumentRootNode that carries islands:
body: [
  HeadingNode(...),
  IslandPlaceholderNode(...),
  ...islandRuntime(),               // engine config + dispatcher + custom element
],
```

This injects three self-contained `<script>` tags: the `HYDRALINE_CONFIG`
engine location, the custom element definition (`<hydraline-island>`), and the
dispatcher (directive wiring, IntersectionObserver, engine loading).

## Verification

- **SEO audit**: `dart run hydraline:audit dist/index.html`
- **Unit tests**: `dart test` / `flutter test`
- **E2E browser tests**: `melos run e2e` (runtime JS in real Chrome)
- **Real-engine e2e**: `melos run e2e:engine` (flutter build web + SSG overlay)
- **Full gate**: `melos run precommit`
