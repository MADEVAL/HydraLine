# hydraline_flutter

Flutter package for [Hydraline](../../README.md) — Seo.* widgets,
Island, HydraApp, IslandHost, SSG runner, and web runtime assets.

## What's inside

| Module | Description |
|---|---|
| `Seo.*` widgets | Self-registering widgets — build UI and register semantic info simultaneously |
| `Island` | Flutter island with configurable hydration, render mode, and size |
| `HydraApp` / `HydraScope` | Integration wrapper + InheritedWidget for SsgCollector access |
| `IslandHost` | Root multi-view widget — one Flutter engine hosts N islands |
| `SsgRunner` | Build-time SSG — traverse routes, extract DocumentNode, write HTML to dist |
| `RouteAdapter` | go_router / Navigator 2.0 adapters for build-time route traversal |
| `SsgSandbox` | Build-time stub ancestors (MediaQuery, Navigator) for extraction |
| `SsgDevTools` | Island diagnostics — props size warnings, anti-CLS checks |
| `SsgDomDiff` | SSG-HTML vs hydrated DOM text-node divergence comparator |
| Web runtime | Custom Element, dispatcher, Service Worker, virtual views |

## Flutter version policy

- **Minimum supported: Flutter 3.35.0** (`environment.flutter: ">=3.35.0"`),
  the first SDK bundling Dart 3.9 — required by pub workspaces.
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
  @override
  Widget build(BuildContext context) => HydraApp(
    child: Column(children: [
      Seo.head(SeoMeta(title: 'Product', description: 'A great product')),
      Seo.heading('iPhone 15', level: 1),
      Seo.text('The latest iPhone with A17 Pro chip.'),
      Seo.image('/img/phone.png', alt: 'iPhone 15 in titanium'),
      Island(
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
# Run SSG to generate static HTML
dart run hydraline_flutter:ssg --config hydraline.routes.yaml --output dist/
```

## Documentation

- [Flutter Widgets Guide](../../docs/flutter-widgets.md) — Seo.*, Island, HydraApp, SSG
- [Architecture](../../docs/architecture.md) — islands, SSG pipeline, client runtime
- [Configuration](../../docs/configuration.md) — route manifest, island manifest
- [Getting Started](../../docs/getting-started.md) — prerequisites, installation

## License

MIT — [Yevhen Leonidov](https://leonidov.dev)
