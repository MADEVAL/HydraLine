# Hydraline showcase

A minimal full-stack demo of all three Hydraline packages working together:

| File | Shows |
|---|---|
| [`lib/main.dart`](lib/main.dart) | Flutter app with `Seo.*` widgets and `Island` zones - [`hydraline_flutter`](../packages/hydraline_flutter/) |
| [`lib/content.dart`](lib/content.dart) | Pure-Dart page builders (surface B) shared by SSR and SSG |
| [`lib/island_main.dart`](lib/island_main.dart) | Island entry-point: `IslandMultiViewApp` + deferred island factories |
| [`web/flutter_bootstrap.js`](web/flutter_bootstrap.js) | Custom bootstrap exposing `window._hydralineApp` (multi-view engine contract) |
| [`bin/server.dart`](bin/server.dart) | SSR server: streaming, bot-aware delivery, caching - [`hydraline_server`](../packages/hydraline_server/) |
| [`bin/build.dart`](bin/build.dart) | SSG build: manifest + the same builders -> static `dist/` |
| [`hydraline.routes.yaml`](hydraline.routes.yaml) | Route manifest: `document` / `hybrid` / `app` modes - [`hydraline`](../packages/hydraline/) |

## Run the SSR server

```bash
cd example
dart run bin/server.dart

curl -N http://localhost:8080/                # chunked streaming (users)
curl -A Googlebot http://localhost:8080/      # buffered (bots) - same bytes
curl http://localhost:8080/product/espresso   # hybrid page with an island
curl http://localhost:8080/robots.txt
```

## Generate a static site (SSG)

```bash
cd example
dart run hydraline_example:build hydraline.routes.yaml dist
# dist/: index.html, product/espresso.html, product/grinder.html,
#        sitemap.xml, robots.txt, hydraline-*.js runtime assets.
# bin/build.dart feeds the manifest + the pure-Dart builders from
# lib/content.dart into runSsgCli - full page content, not just metadata.
```

## Run the Flutter app

```bash
cd example
flutter run -d chrome
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
dart run hydraline:audit --server-integration http://localhost:8080/
```

More: [Getting Started](../docs/getting-started.md) · [full documentation](../docs/).
