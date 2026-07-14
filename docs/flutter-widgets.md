# Flutter Widgets

`hydraline_flutter` provides Flutter widgets that have a **dual nature**: they
render visually in a running Flutter app *and* self-register their semantic
content into a `SsgCollector` for build-time SSG extraction.

## Seo.* Widgets

The `Seo` namespace provides static factory methods. Each returns a widget that
registers semantic information during SSG extraction and renders a lightweight
visual at runtime.

### Seo.text

```dart
Seo.text(
  String text, {
  int? headingLevel,   // 1-6 → creates a heading instead of paragraph
  Key? key,
})
```

Registers either a `HeadingNode` (when `headingLevel` is set) or a
`ParagraphNode` → `TextNode`. At runtime, renders a plain `Text` widget.

### Seo.heading

```dart
Seo.heading(
  String text, {
  required int level,  // 1-6
  Key? key,
})
```

Convenience wrapper around `Seo.text` with `headingLevel`.

### Seo.image

```dart
Seo.image(
  String src, {
  required String alt,
  int? width,
  int? height,
  Key? key,
})
```

Registers an `ImageNode` (with `SafeUrl` validation). At runtime, renders a
`SizedBox` with the given dimensions. If `src` is not a valid URL, registration
is silently skipped.

### Seo.link

```dart
Seo.link({
  required String href,
  required Widget child,
  Key? key,
})
```

Registers an `AnchorNode`. At runtime, renders a `GestureDetector` wrapping
`child`. The link text is not automatically extracted from the child — use
`Seo.text` for link labels visible to crawlers.

### Seo.section

```dart
Seo.section({
  required SectionRole role,     // section, article, nav, header, footer, main
  required List<Widget> children,
  Key? key,
})
```

Registers a `SectionNode`. At runtime, renders a `Column` with the children.

### Seo.list

```dart
Seo.list({
  required bool ordered,         // true → <ol>, false → <ul>
  required List<Widget> items,
  Key? key,
})
```

At runtime, renders a `Column` with the items.

### Seo.head

```dart
Seo.head(SeoMeta meta)
```

Registers route metadata (title, description, OG, Twitter, etc.). At runtime,
renders `SizedBox.shrink()` — it produces no visual output. This is the widget
equivalent of `buildHead()` in the pure-Dart surface.

## HydraApp and HydraScope

`HydraApp` is the top-level integration widget. It wraps your app and provides
the `HydraScope` InheritedWidget that `Seo.*` and `Island` widgets use to access
the `SsgCollector`.

```dart
HydraApp({
  required Widget child,
  SsgCollector? collector,
})
```

- In normal Flutter runtime: pass `null` for `collector`. Widgets render
  normally; registration is silently skipped.
- In SSG extraction: pass a `SsgCollector` instance. Widgets self-register
  their semantic content via `HydraScope.of(context).collector`.

`HydraApp` does **not** replace `MaterialApp`. Nest it inside your existing
widget tree:

```dart
MaterialApp(
  home: HydraApp(child: MyHomePage()),
)
```

`HydraScope` is the InheritedWidget that carries the collector:

```dart
class HydraScope extends InheritedWidget {
  final SsgCollector? collector;
  final bool isSsgMode;

  static HydraScope of(BuildContext context);
}
```

## Island Widget

The `Island` widget declares an interactive zone. In SSG mode it registers an
`IslandPlaceholderNode`; at runtime it renders a placeholder (typically a
`SizedBox`).

```dart
Island({
  required String id,
  required IslandType type,           // flutter, vanilla, htmx
  Map<String, Object?> props = const {},
  HydrationDirective directive = HydrationDirective.onIdle,
  IslandRenderMode renderMode = IslandRenderMode.ssr,
  IslandStyleMode styleMode = IslandStyleMode.shadow,
  double? width,
  double? height,
  Widget? placeholder,
  Widget? errorFallback,
  String? mediaQuery,
})
```

| Parameter | Description |
|---|---|
| `id` | Unique island identifier |
| `type` | `IslandType.flutter`, `.vanilla`, or `.htmx` |
| `props` | JSON-safe data passed to the island via `data-state` |
| `directive` | When the island hydrates (default: `onIdle`) |
| `renderMode` | `ssr` (semantic fallback in HTML) or `skeletonOnly` (skeleton only) |
| `styleMode` | `shadow` (isolated Shadow DOM) or `scoped` (CSS `@scope`, best for many identical islands) |
| `width` / `height` | Reserved space in px — prevents Cumulative Layout Shift |
| `placeholder` | Widget shown before hydration (default: sized `SizedBox`) |
| `errorFallback` | Shown when hydration fails |
| `mediaQuery` | CSS media query for `hydrateOnMedia` directive |

### Island Types

```dart
enum IslandType { flutter, vanilla, htmx }
```

- `flutter` — Level 2: CanvasKit-rendered Flutter widget. Engine loaded on trigger.
- `vanilla` — Level 1: Lightweight JS widget (~8 KB). No Flutter engine.
- `htmx` — Level 1: Server-driven HTML fragments (~14 KB HTMX). No Flutter engine.

### Hydration Directives

```dart
enum HydrationDirective {
  onLoad,          // Immediately on DOMContentLoaded
  onIdle,          // When main thread is idle (default)
  onVisible,       // When scrolled into viewport
  onInteraction,   // On first click, focus, or touch
  onMedia,         // When CSS media query matches
  manual,          // Explicit JS API call
}
```

### Render Modes

```dart
enum IslandRenderMode { ssr, skeletonOnly }
```

- `ssr` (default) — The island emits semantic fallback content into the HTML.
- `skeletonOnly` — Only a skeleton/placeholder is emitted. For islands that
  require runtime APIs (3D configurators, WebGL, `window`/`localStorage`).

`renderMode` is orthogonal to `directive` — it controls *what* goes into HTML,
while `directive` controls *when* the island hydrates.

### Style Modes

```dart
enum IslandStyleMode { shadow, scoped }
```

- `shadow` (default) — Declarative Shadow DOM. Full style isolation. The
  `<style>` block lives inside each island's shadow root.
- `scoped` — CSS `@scope` or attribute prefix. Styles are emitted once in
  the `<head>` and shared. Recommended for pages with many identical islands
  (product cards, feeds).

## SsgCollector

The collector receives semantic registrations from widgets during SSG extraction.
It deduplicates by key and produces an immutable `DocumentNode` via `seal()`.

```dart
abstract interface class SsgCollector {
  factory SsgCollector(String route);

  void addText(String text, {int? headingLevel, String? key});
  void addImage(SafeUrl src, String alt, {int? width, int? height, String? key});
  void addLink(SafeUrl href, String text, {String? key});
  void addIsland(IslandSpec spec, {String? key});
  void addNode(DocumentNode node, {String? key});
  void addMeta(SeoMeta meta);

  DocumentNode seal();
}
```

After `seal()` is called, the collector becomes immutable — subsequent `add*`
calls are silently ignored. Each extraction run gets its own collector instance.

## SsgSandbox

During SSG extraction (which runs in `flutter_tester`), widgets may depend on
ancestors that don't exist in the test environment — `MediaQuery`, `Navigator`,
`Directionality`. `SsgSandbox` provides stubs for these.

```dart
SsgSandbox({
  required Widget child,
})
```

Wrap your page inside `SsgSandbox` during extraction to prevent `NoSuchWidget`
errors:

```dart
void main() {
  testWidgets('extract blog page', (tester) async {
    final collector = SsgCollector('/blog/post-1');
    await tester.pumpWidget(
      SsgSandbox(
        child: HydraApp(
          collector: collector,
          child: const BlogPage(),
        ),
      ),
    );
    final doc = collector.seal();
    // doc contains the full DocumentNode tree
  });
}
```

## IslandHost

The server-side counterpart of the JavaScript dispatcher. `IslandHost` is the
root widget for the island entry-point (`lib/island_main.dart`). One engine
instance hosts N islands in N views.

```dart
typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

IslandHost({
  required Map<String, IslandFactory> factories,
})
```

Each factory maps an island `id` to a builder function. Heavy islands use
deferred imports (`deferred as` + `loadLibrary()`):

```dart
import 'islands/calculator.dart' deferred as calc;
import 'islands/chart.dart' deferred as chart;

final factories = <String, IslandFactory>{
  'calculator': (props) async {
    await calc.loadLibrary();
    return calc.CalculatorIsland(props: props);
  },
  'chart': (props) async {
    await chart.loadLibrary();
    return chart.ChartIsland(props: props);
  },
};

void main() {
  runWidget(IslandHost(factories: factories));
}
```

## Route Adapter

Hydraline integrates with Flutter routers through the `RouteAdapter` interface.
First-class support is provided for `go_router`.

### GoRouterAdapter

```dart
final adapter = GoRouterAdapter(router: myGoRouter);
final routes = adapter.extractRoutes();   // List<RouteInfo>
```

The adapter extracts route paths, names, and parameters for use in the route
manifest and SSG runner.

### Custom RouteAdapter

Implement `RouteAdapter` for other routers:

```dart
abstract interface class RouteAdapter {
  List<RouteInfo> extractRoutes();
  String? resolvePath(String name, Map<String, String> params);
}

class RouteInfo {
  final String path;
  final String? name;
  final List<String> segments;
}
```

## SSG Runner

The `SsgRunner` generates static HTML from a route manifest. It must execute
inside `flutter_tester` (it cannot run as plain `dart`).

```dart
SsgRunner({
  required Object routeManifest,
  required RouteAdapter routeAdapter,
  required Map<String, Object?> islandFactories,
})

Future<SsgResult> run({required String outputDir});
```

The runner:
1. Iterates the route manifest
2. Builds a `DocumentNode` per route
3. Serializes HTML to `dist/`
4. Generates `sitemap.xml` (with auto-split at 50,000 URLs)
5. Generates `robots.txt`
6. Copies the island bundle and web assets into `dist/` (only when Flutter
   islands exist)

CLI invocation:

```bash
dart run hydraline_flutter:build
```

`SsgResult` reports the number of pages written and whether island assets
were copied.

## Dynamic Segments

For routes with parameterized paths like `/blog/:slug`, use dynamic segments
to generate concrete pages:

```yaml
routes:
  - path: /blog/:slug
    mode: document
    dynamic_segments:
      slug: [post-1, post-2, hello-world]
```

Or programmatically:

```dart
DynamicSegments.expand({
  '/blog/:slug': {
    'slug': ['post-1', 'post-2'],
  },
})
```

## Complete Widget Example

```dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) => HydraApp(
    child: SsgSandbox(
      child: Column(children: [
        // Metadata (invisible at runtime)
        Seo.head(SeoMeta(
          title: 'iPhone 15',
          description: 'Apple iPhone 15, 128 GB',
          canonical: SafeUrl.parse('https://example.com/product/iphone15'),
          openGraph: OpenGraph(
            title: 'iPhone 15',
            type: 'product',
            image: SafeUrl.parse('https://example.com/og/iphone15.png'),
          ),
          robots: RobotsDirectives(noindex: false),
        )),

        // Semantic content
        Seo.heading('iPhone 15', level: 1),
        Seo.text('The latest smartphone from Apple.'),
        Seo.image('/images/iphone15.png', alt: 'iPhone 15 front view',
                   width: 800, height: 600),

        // Price table
        Seo.section(role: SectionRole.section, children: [
          Seo.heading('Specifications', level: 2),
          Seo.list(ordered: false, items: [
            Seo.text('Display: 6.1" Super Retina XDR'),
            Seo.text('Chip: A16 Bionic'),
            Seo.text('Storage: 128 GB'),
          ]),
        ]),

        // Flutter island — hydrates when scrolled into view
        Island(
          id: 'calculator',
          type: IslandType.flutter,
          props: {'price': 89990, 'currency': 'RUB'},
          directive: HydrationDirective.onVisible,
          width: 640,
          height: 480,
          placeholder: Container(
            width: 640, height: 480,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),

        // Vanilla island — lightweight accordion for FAQ
        Island(
          id: 'faq',
          type: IslandType.vanilla,
          props: {'kind': 'accordion'},
          directive: HydrationDirective.onIdle,
        ),
      ]),
    ),
  );
}
```
