# Flutter Widgets

`hydraline_flutter` provides Flutter widgets that have a **dual nature**: they
render visually in a running Flutter app *and* self-register their semantic
content into a `SsgCollector` for build-time SSG extraction.

> `hydraline_flutter` re-exports the whole `hydraline` core, so a single
> `import 'package:hydraline_flutter/hydraline_flutter.dart';` gives you
> `SeoMeta`, `SafeUrl`, `IslandType`, node classes, and everything else.

## Seo.* Widgets

The `Seo` namespace provides static factory methods. Each returns a widget that
registers semantic information during SSG extraction and renders a lightweight
visual at runtime.

Registration is **flat**: widgets register into the collector in build order.
Nested structures (sections, lists) register their children individually.

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

Registers an `ImageNode` (with `SafeUrl` validation). At runtime, renders an
`Image.network` with `alt` as the semantic label; when the image cannot load
it degrades to a `SizedBox` with the given dimensions. If `src` is not a
valid URL, registration is silently skipped.

### Seo.link

```dart
Seo.link({
  required String href,
  required Widget child,
  VoidCallback? onTap,
  Key? key,
})
```

Registers an `AnchorNode`. When `child` is a `Text` widget, its string becomes
the link label visible to crawlers; for other child widgets the label is empty
- add `Seo.text` nearby for crawler-visible copy. At runtime the link is
tappable and exposes link semantics: `onTap` wins when provided; otherwise
internal hrefs (starting with `/`) navigate via `Navigator.pushNamed`.
External hrefs need an explicit `onTap` (for example with `url_launcher`).

### Seo.section

```dart
Seo.section({
  required SectionRole role,     // section, article, nav, header, footer, main
  required List<Widget> children,
  Key? key,
})
```

Renders a `Column` with the children. The children self-register into the
collector in build order (flat model); the `role` shapes visual grouping.

### Seo.list

```dart
Seo.list({
  required bool ordered,         // visual hint only
  required List<Widget> items,
  Key? key,
})
```

Renders a `Column`; the items self-register individually (flat model).

### Seo.head

```dart
Seo.head(SeoMeta meta)
```

Registers route metadata (title, description, OG, Twitter, etc.). At runtime,
renders `SizedBox.shrink()` - it produces no visual output. This is the widget
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
  String? kind,                       // required for IslandType.vanilla
  String? endpoint,                   // required for IslandType.htmx
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
| `width` / `height` | Reserved space in px - prevents Cumulative Layout Shift, serialized as `data-size` |
| `placeholder` | Widget shown before hydration (default: sized `SizedBox`) |
| `errorFallback` | Reserved for a future release; on failure the SSR fallback stays visible |
| `mediaQuery` | CSS media query for `hydrateOnMedia` - serialized as `data-media` |
| `kind` | Vanilla handler name (`data-island` attribute): `accordion`, `tabs`, ... - asserted non-null for vanilla islands |
| `endpoint` | HTMX fragment endpoint (`hx-get`) - asserted non-null for htmx islands |

### Island Types

```dart
enum IslandType { flutter, vanilla, htmx }
```

- `flutter` - Level 2: CanvasKit-rendered Flutter widget. Engine loaded on trigger.
- `vanilla` - Level 1: Lightweight JS widget (~8 KB). No Flutter engine.
- `htmx` - Level 1: Server-driven HTML fragments (~14 KB HTMX). No Flutter engine.

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

- `ssr` (default) - The island emits semantic fallback content into the HTML.
- `skeletonOnly` - Only a skeleton/placeholder is emitted. For islands that
  require runtime APIs (3D configurators, WebGL, `window`/`localStorage`).

`renderMode` is orthogonal to `directive` - it controls *what* goes into HTML,
while `directive` controls *when* the island hydrates.

### Style Modes

```dart
enum IslandStyleMode { shadow, scoped }
```

- `shadow` (default) - Declarative Shadow DOM. Full style isolation. The
  `<style>` block lives inside each island's shadow root.
- `scoped` - CSS `@scope` or attribute prefix. Styles are emitted once in
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

After `seal()` is called, the collector becomes immutable - subsequent `add*`
calls are silently ignored. Each extraction run gets its own collector instance.

## SsgSandbox

During SSG extraction (which runs in `flutter_tester`), widgets may depend on
ancestors that don't exist in the test environment - `MediaQuery`,
`Directionality`. `SsgSandbox` provides stubs for these *and* wires the
collector into scope:

```dart
SsgSandbox({
  required SsgCollector collector,
  required Widget child,
})
```

Wrap your page inside `SsgSandbox` during extraction:

```dart
void main() {
  testWidgets('extract blog page', (tester) async {
    final collector = SsgCollector('/blog/post-1');
    await tester.pumpWidget(
      SsgSandbox(
        collector: collector,
        child: const BlogPage(),
      ),
    );
    final doc = collector.seal();
    // doc contains the full DocumentNode tree
  });
}
```

## IslandHost and IslandViewRegistry

The Dart-side counterpart of the JavaScript dispatcher. One engine instance
hosts N islands in N views:

```dart
typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

// Multi-view root for the island entry-point (lib/island_main.dart):
IslandMultiViewApp({
  required Map<String, IslandFactory> factories,
})

// Per-view widget: resolves the island bound to the current view.
IslandHost({
  required Map<String, IslandFactory> factories,
})
```

The flow on the web:

1. The dispatcher hydrates an island and calls `app.addView()` with
   `{ islandId, state }` as `initialData`.
2. `IslandMultiViewApp` (a `runWidget` root observing view changes) reads
   the `initialData` of every new view and registers the binding:
   `IslandViewRegistry.register(viewId, islandId, state)` - automatic on
   the web, no manual glue needed.
3. `IslandHost` inside that view looks up the binding and mounts the
   matching factory. Views without a binding render a neutral container.

For tests or custom bootstraps you can register bindings manually:

```dart
IslandViewRegistry.register(viewId, 'calculator', {'price': 89990});
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
  runWidget(IslandMultiViewApp(factories: factories));
}
```

## Route Adapter

Hydraline integrates with Flutter routers through the `RouteAdapter` interface.
First-class support is provided for `go_router` (without a hard dependency -
the adapter inspects the router object dynamically).

```dart
abstract interface class RouteAdapter {
  List<RouteInfo> get routes;
  Future<void> navigateToForExtraction(RouteInfo route);
}

class RouteInfo {
  final String path;
  final String? name;
}
```

### GoRouterAdapter

```dart
final adapter = GoRouterAdapter(myGoRouter);
final routes = adapter.routes;   // List<RouteInfo> from GoRouter.configuration
```

### Navigator2Adapter

For bare Navigator 2.0 apps, list the routes explicitly:

```dart
final adapter = Navigator2Adapter([
  const RouteInfo(path: '/', name: 'home'),
  const RouteInfo(path: '/product/:id', name: 'product'),
]);
```

## SSG Runner

The `SsgRunner` generates static HTML from a route manifest.

```dart
SsgRunner({
  required Object routeManifest,        // RouteManifest
  required RouteAdapter routeAdapter,
  required Map<String, Object?> islandFactories,
  Map<String, SsgPageBuilder> builders = const {},
})

Future<SsgResult> run({required String outputDir});
```

The runner:
1. Iterates the route manifest (skipping `app` routes)
2. Expands dynamic segments into concrete paths
3. Builds a `DocumentNode` per page - a registered pure-Dart
   `SsgPageBuilder` (surface B) wins; otherwise a metadata-only shell is
   generated from the manifest
4. Serializes HTML files into the output directory
5. Generates `sitemap.xml` (with auto-split at 50,000 URLs) and `robots.txt`
6. Copies the island runtime assets (custom element, dispatcher, service
   worker) into the output - only when Flutter islands exist

```dart
typedef SsgPageBuilder = DocumentNode Function(String path);

final runner = SsgRunner(
  routeManifest: manifest,
  routeAdapter: Navigator2Adapter([]),
  islandFactories: {},
  builders: {
    '/blog/:slug': (path) => DocumentRootNode(
      head: buildHead(SeoMeta(title: 'Post $path')),
      body: [/* ... */],
    ),
  },
);
final result = await runner.run(outputDir: 'dist');
// result.pagesWritten, result.assetsCopied
```

Widget extraction (surface A) runs inside `flutter_tester`: pump pages in a
`SsgSandbox` from a test tagged `ssg` and serialize `collector.seal()` - see
[SsgSandbox](#ssgsandbox).

CLI invocation (plain Dart VM, no Flutter engine needed):

```bash
dart run hydraline_flutter:build hydraline.routes.yaml dist
# or
dart run hydraline_flutter:build --config hydraline.routes.yaml --output dist
```

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
// ['/blog/post-1', '/blog/post-2']
```

## SsgDevTools and SsgDomDiff

Diagnostics for island-heavy pages:

```dart
// Island report: props sizes (10 KB budget), anti-CLS warnings.
final report = SsgDevTools.fromCollector(collector).analyze();
for (final island in report.islands) {
  print('${island.id}: ${island.propsBytes} B ${island.warnings}');
}

// Compare SSG output against the hydrated DOM (>5% divergence -> warning).
final diff = SsgDomDiff.compare(ssgHtml, hydratedDomHtml);
if (diff.hasWarning) print('${diff.divergencePercent}% text divergence');
```

## Complete Widget Example

A runnable version lives in
[`packages/hydraline_flutter/example/lib/main.dart`](../packages/hydraline_flutter/example/lib/main.dart)
and a full-stack demo in [`example/`](../example/README.md).

```dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) => HydraApp(
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
      )),

      // Semantic content
      Seo.heading('iPhone 15', level: 1),
      Seo.text('The latest smartphone from Apple.'),
      Seo.image('/images/iphone15.png', alt: 'iPhone 15 front view',
                 width: 800, height: 600),

      // Specifications
      Seo.section(role: SectionRole.section, children: [
        Seo.heading('Specifications', level: 2),
        Seo.list(ordered: false, items: [
          Seo.text('Display: 6.1" Super Retina XDR'),
          Seo.text('Chip: A16 Bionic'),
          Seo.text('Storage: 128 GB'),
        ]),
      ]),

      // Flutter island - hydrates when scrolled into view
      const Island(
        id: 'calculator',
        type: IslandType.flutter,
        props: {'price': 89990, 'currency': 'RUB'},
        directive: HydrationDirective.onVisible,
        width: 640,
        height: 480,
      ),

      // Vanilla island - lightweight accordion for FAQ
      const Island(
        id: 'faq',
        type: IslandType.vanilla,
        kind: 'accordion',
      ),
    ]),
  );
}
```

## See Also

- [Getting Started](./getting-started.md) - installation, SSG vs SSR
- [Architecture](./architecture.md) - islands, SSG pipeline, client runtime
- [Configuration](./configuration.md) - route manifest, island manifest
- [`hydraline_flutter` package README](../packages/hydraline_flutter/README.md)
