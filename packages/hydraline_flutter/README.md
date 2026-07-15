# hydraline_flutter

> Part of [**Hydraline**](https://github.com/MADEVAL/HydraLine) - real crawlable
> HTML for Flutter Web. Three packages, one toolkit.
>
> [`hydraline`](https://pub.dev/packages/hydraline)
> (core) ·
> [`hydraline_server`](https://pub.dev/packages/hydraline_server)
> (SSR) ·
> [`hydraline_flutter`](https://pub.dev/packages/hydraline_flutter)
> (widgets, you are here)

**Flutter package - Seo.* widgets, Island, IslandHost, SSG runner,
and the L2 web runtime.** Re-exports the whole `hydraline` core: one import gives
you the full API.

Add SEO to any existing Flutter Web app without touching your `main()` or
`MaterialApp`. `Seo.*` widgets render visually AND register semantic HTML.
Islands hydrate on scroll, click, idle - engine loads only when triggered.

[![pub](https://img.shields.io/pub/v/hydraline_flutter)](https://pub.dev/packages/hydraline_flutter)
[![tests](https://img.shields.io/badge/tests-140%20passed-brightgreen)](#)
[![e2e](https://img.shields.io/badge/e2e-Chrome%2026%20passed-brightgreen)](#)
[![CLS](https://img.shields.io/badge/CLS-≈%200-blue)](#)

## Why

Your Flutter Web app already works. You just need it to be **visible in Google**.
This package adds that without touching `main()` or `MaterialApp`.

- **Seo.* widgets — dual nature.** `Seo.heading`, `Seo.text`, `Seo.image`,
  `Seo.link`, `Seo.section` (emits `<main>`/`<nav>`/`<article>`), `Seo.list`
  (emits `<ol>`/`<ul>` + `<li>`) — each renders visually AND registers the
  corresponding semantic `DocumentNode`. One widget tree, real HTML output.
- **Islands — interactive Flutter, zero overhead.** `Island` zones with
  hydration directives (`onVisible`, `onIdle`, `onInteraction`, `onMedia`,
  `manual`). Props cross as JSON in `data-state`. One engine hosts N islands in
  N views. Pages without islands **never load** the Flutter engine — proven by
  CI in real Chrome.
- **Zero layout shift.** Islands reserve pixel dimensions via Declarative
  Shadow DOM. CLS < 0.01 — proven by CI.
- **SSG runner.** `dart run hydraline_flutter:build` — routes to static HTML +
  sitemap + robots + runtime JS in one command. Pure-Dart build surface for
  your own `bin/build.dart`.
- **Proven in real Chrome.** 26 Playwright e2e tests for the runtime JS, 5
  real-engine tests (CanvasKit boot, IslandHost mounting, semantics-tree
  interaction), service worker caching, Edge channel.
- **A11y.** Accessibility tree driven through the Flutter engine semantics
  placeholder, auto-activated for screen readers and test assertions.

## What's inside

| Module | Description |
|---|---|
| `Seo.*` widgets | Self-registering: `Seo.head`, `Seo.heading`, `Seo.text`, `Seo.image`, `Seo.link`, `Seo.section` (emits `<main>`/`<nav>`/`<article>`/...), `Seo.list` (emits `<ol>`/`<ul>` + `<li>`) |
| `Island` | Declarative island zones: Flutter (`IslandType.flutter`), vanilla (`.vanilla`), HTMX (`.htmx`). Hydration directives: `onLoad`, `onIdle`, `onVisible`, `onInteraction`, `onMedia`, `manual` |
| `HydraApp` / `HydraScope` | InheritedWidget for `SsgCollector` access - widgets self-register during SSG extraction |
| `IslandMultiViewApp` / `IslandHost` | Multi-view runtime: one Flutter engine, one `FlutterView` per island. Deferred island factories (`loadLibrary()`) |
| `IslandViewRegistry` | View → island binding registry, populated from `addView()` `initialData` |
| `SsgRunner` / `runSsgCli()` | Build-time SSG: routes → HTML + sitemap + robots + runtime JS → `dist/` |
| `dart run hydraline_flutter:build` | CLI for metadata-only shells; use `runSsgCli` from your own `bin/build.dart` for full pages |
| `package:hydraline_flutter/build.dart` | Pure-Dart build surface - safe for VM executables |
| `RouteAdapter` / `GoRouterAdapter` / `Navigator2Adapter` | Router integration: `navigateToForExtraction()` drives `go_router.go()` per route; `Navigator2Adapter` records the current route for widget extraction |
| `SsgSandbox` | Build-time stub ancestors (`MediaQuery`, `Directionality`) for headless extraction |
| `SsgDevTools` | Island diagnostics: props size warnings, anti-CLS checks |
| `SsgDomDiff` | SSG-HTML vs hydrated DOM text-node divergence comparator |
| Web runtime (L2) | Pretty, branded JS kept byte-identical to `web/*.js` (locked by test): |
| | `<hydraline-island>` - Custom Element with Declarative Shadow DOM, `data-size` anti-CLS sizing, `ResizeObserver` for multi-view constraints |
| | `hydraline-dispatcher.js` - directive wiring (IntersectionObserver, idle callback, matchMedia), engine loading (once, on first trigger), `addView()` per island, `dehydrate()`, bootstrap rejection parking |
| | `hydraline-virtual-views.js` - tall-island segment observer: `segment-enter` / `segment-leave` events |
| | `service-worker.js` - stale-while-revalidate for warm visits, old-cache purge on `activate` |

## Zero-overhead guarantee

Pages without Flutter islands **never load the engine**. The L2 runtime
(CanvasKit, `main.dart.js`, `canvaskit/*`) is fetched only when an island
actually triggers. Document pages request zero engine bytes. Verified by
CI test in real Chrome.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) => HydraApp(
    child: Column(children: [
      Seo.head(const SeoMeta(
        title: 'Espresso Machine',
        description: 'Compact 15-bar espresso machine.',
        openGraph: OpenGraph(
          type: 'product',
          image: SafeUrl.parse('https://shop.example/og.jpg'),
        ),
      )),
      Seo.heading('Espresso Machine', level: 1),
      Seo.section(role: SectionRole.main, children: [
        Seo.text('Real HTML. Real rankings.'),
        Seo.image('/img/espresso.jpg', alt: 'Espresso machine', width: 800, height: 600),
        Seo.list(ordered: false, items: [
          Seo.text('Feature one'),
          Seo.text('Feature two'),
        ]),
      ]),
      // Level 2: Flutter island - engine loads on scroll. Reserved size prevents CLS.
      Island(
        id: 'calculator',
        type: IslandType.flutter,
        directive: HydrationDirective.onVisible,
        props: const {'price': 249},
        width: 640, height: 320,
      ),
      // Level 1: vanilla accordion - no Flutter engine at all.
      Island(id: 'faq', type: IslandType.vanilla, kind: 'accordion'),
    ]),
  );
}
```

```bash
# Generate static HTML (SSG):
dart run hydraline_flutter:build hydraline.routes.yaml dist

# Full pages: call runSsgCli from your bin/build.dart with builders -
# see ../../example/bin/build.dart.
```

## Proven

- **140 widget/unit tests** - widget extraction, SSG runner, island host, route adapter, zero-overhead
- **26 Playwright e2e tests** in real Chrome: all hydration directives, vanilla islands (accordion/tabs/carousel/theme/lazy/copy), failure paths, re-wire guard, dehydrate
- **5 real-engine e2e tests** (`melos run e2e:engine`): `flutter build web` + SSG overlay → Chrome verifies genuine CanvasKit boot, `IslandHost` mounting, calculator interaction via semantics tree, service worker caching, CLS < 0.01
- **Multi-view runtime**: one engine, N islands, N `FlutterView`s - each receives `{ islandId, state }` as `initialData`
- **Edge channel** tested alongside Chrome in Playwright

Runnable example: [`example/lib/main.dart`](example/lib/main.dart) - a product
page with `Seo.*` widgets, `Seo.section`/`Seo.list`, L1/L2 islands, and
an `IslandHost` entry-point.

## Documentation

- [Flutter Widgets Guide](../../docs/flutter-widgets.md)
- [Architecture](../../docs/architecture.md) - islands, SSG pipeline, client runtime
- [Configuration](../../docs/configuration.md) - route manifest, island manifest
- [Security](../../docs/security.md) - SRI, sanitizer, CSP
- [Getting Started](../../docs/getting-started.md)

## License

MIT - [Yevhen Leonidov](https://leonidov.dev)
