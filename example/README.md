# Hydraline showcase

A runnable full-stack demo of all three Hydraline packages working together
in one app: a shop that renders **real semantic HTML** for `/` and
`/product/:id` while keeping `/app/dashboard` as pure Flutter CanvasKit.

| File | Shows |
|---|---|
| [`lib/main.dart`](lib/main.dart) | Flutter app with `Seo.*` widgets: `Seo.section` (emits `<main>`), `Seo.list` (emits `<ul><li>`), `Seo.heading`, `Seo.image`, `Seo.link`, `Seo.head`, and `Island` zones (L1 vanilla + L2 Flutter) — [`hydraline_flutter`](../packages/hydraline_flutter/) |
| [`lib/content.dart`](lib/content.dart) | Pure-Dart page builders (surface B) — **one source of truth** shared by the SSR server and SSG build |
| [`lib/island_main.dart`](lib/island_main.dart) | Island entry-point: `IslandMultiViewApp` + deferred island factories (`loadLibrary()`) |
| [`lib/islands/calculator.dart`](lib/islands/calculator.dart) | The Flutter widget inside a L2 island: a quantity picker with live total |
| [`lib/app_dashboard.dart`](lib/app_dashboard.dart) | Pure Flutter CanvasKit page — **no Hydraline, no SEO**, automatically `noindex`'d |
| [`web/flutter_bootstrap.js`](web/flutter_bootstrap.js) | Custom bootstrap exposing `window._hydralineApp` (multi-view engine contract) |
| [`bin/server.dart`](bin/server.dart) | SSR server: streaming, bot-aware delivery, caching + ETag/304 — [`hydraline_server`](../packages/hydraline_server/) |
| [`bin/build.dart`](bin/build.dart) | SSG build: manifest + pure-Dart builders → static `dist/` |
| [`hydraline.routes.yaml`](hydraline.routes.yaml) | Route manifest: `document` / `hybrid` / `app` modes — [`hydraline`](../packages/hydraline/) |

## Run the SSR server

```bash
cd example
dart run bin/server.dart

curl -N http://localhost:8080/                # chunked streaming (humans)
curl -A Googlebot http://localhost:8080/      # buffered (bots) — byte-identical body
curl http://localhost:8080/product/espresso   # hybrid: HTML + island + JSON-LD
curl http://localhost:8080/robots.txt
```

## Generate a static site (SSG)

```bash
cd example
dart run hydraline_example:build hydraline.routes.yaml dist
# dist/:
#   index.html                    home page: <main>, <h1>, <ul>, <p>, links
#   product/espresso.html         hybrid: <hydraline-island>, OG tags, JSON-LD
#   product/grinder.html          same for grinder
#   sitemap.xml                   auto-split, with lastmod/changefreq/priority
#   robots.txt
#   hydraline-island.js           custom element (anti-CLS shadow DOM)
#   hydraline-dispatcher.js       directive wiring + engine loading
#   hydraline-virtual-views.js    tall-island segment observer
#   service-worker.js             stale-while-revalidate for warm visits
```

## Run the Flutter app

```bash
cd example
flutter run -d chrome
# /                  Seo.* widgets render visually AND register semantic HTML
# /product/espresso  shows the calculator island (hydrates on scroll)
# /app/dashboard     pure Flutter CanvasKit, no Hydraline, auto-noindex
```

## Build the island bundle (multi-view)

```bash
cd example
flutter build web --target=lib/island_main.dart
# The dispatcher loads flutter_bootstrap.js on the first island trigger and
# calls app.addView() per island; see web/flutter_bootstrap.js for the
# window._hydralineApp contract.
```

## Audit what a crawler sees

```bash
dart run hydraline:audit http://localhost:8080/
dart run hydraline:audit dist/index.html
```

More: [Getting Started](../docs/getting-started.md) · [full documentation](../docs/).
