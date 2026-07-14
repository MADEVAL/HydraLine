# hydraline_flutter

Flutter package for [Hydraline](../../README.md) - Seo.* widgets,
Island, HydraApp, IslandHost, SSG runner, and web runtime assets.

Re-exports the whole `hydraline` core: one import gives you the full API.

## What's inside

| Module | Description |
|---|---|
| `Seo.*` widgets | Self-registering widgets - build UI and register semantic info simultaneously |
| `Island` | Island zones with hydration directives, render/style modes, anti-CLS sizing |
| `HydraApp` / `HydraScope` | Integration wrapper + InheritedWidget for SsgCollector access |
| `IslandMultiViewApp` / `IslandHost` | Multi-view runtime - one engine, one FlutterView per island |
| `IslandViewRegistry` | View → island bindings, populated automatically from `addView()` initialData |
| `SsgRunner` | Build-time SSG - routes → HTML + sitemap + robots into `dist/` |
| `dart run hydraline_flutter:build` | SSG CLI (plain Dart VM) |
| `RouteAdapter` | go_router / Navigator 2.0 adapters for build-time route traversal |
| `SsgSandbox` | Build-time stub ancestors (MediaQuery, Directionality) for extraction |
| `SsgDevTools` | Island diagnostics - props size warnings, anti-CLS checks |
| `SsgDomDiff` | SSG-HTML vs hydrated DOM text-node divergence comparator |
| Web runtime | Pretty, branded JS: `<hydraline-island>` element, dispatcher (engine + `addView()` per island), Service Worker, virtual views |

## Flutter version policy

- **Minimum supported: Flutter 3.35.0** (`environment.flutter: ">=3.35.0"`),
  the first SDK bundling Dart 3.9 - required by pub workspaces.
- CI runs the minimum and the latest stable SDK as blocking jobs.

> **Warning:** Flutter 3.41.x has a known multi-view sizing issue (#185034).
> Hydraline pins explicit `viewConstraints` as a workaround. This version is
> tested in CI on an informational (non-blocking) basis. Use Flutter 3.35+
> or the latest stable.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) => HydraApp(
    child: Column(children: [
      Seo.head(const SeoMeta(title: 'Product', description: 'A great product')),
      Seo.heading('iPhone 15', level: 1),
      Seo.text('The latest iPhone with A17 Pro chip.'),
      Seo.image('/img/phone.png', alt: 'iPhone 15 in titanium'),
      const Island(
        id: 'calculator',
        type: IslandType.flutter,
        props: {'price': 89990},
        width: 640, height: 480,
      ),
    ]),
  );
}
```

```bash
# Generate static HTML from the route manifest
dart run hydraline_flutter:build hydraline.routes.yaml dist
```

Runnable example: [`example/lib/main.dart`](example/lib/main.dart) - a product
page with metadata, semantic content, islands and an `IslandHost` entry-point.

## Documentation

- [Flutter Widgets Guide](../../docs/flutter-widgets.md) - Seo.*, Island, HydraApp, SSG
- [Architecture](../../docs/architecture.md) - islands, SSG pipeline, client runtime
- [Configuration](../../docs/configuration.md) - route manifest, island manifest
- [Getting Started](../../docs/getting-started.md) - prerequisites, installation

## License

MIT - [Yevhen Leonidov](https://leonidov.dev)
