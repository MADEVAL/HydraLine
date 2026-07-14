## 0.0.2

- **Breaking:** `Island` gained `kind` (vanilla) and `endpoint` (htmx)
  parameters, asserted non-null for their island types - vanilla/htmx islands
  built through the widget surface actually work now.
- **Breaking:** `SsgRunner` factory takes a typed `RouteManifest` instead of
  `Object`.
- `Seo.link` is functional at runtime: optional `onTap`, default
  `Navigator.pushNamed` for internal hrefs, link semantics and a click cursor.
- `Seo.image` renders an `Image.network` (with graceful fallback) instead of
  an empty `SizedBox`.
- **Fixed:** the SSG sitemap uses the manifest `base_url` for every entry
  (previously hardcoded `https://localhost`).
- **Fixed:** `DynamicSegments.expand` handles multiple named segments as a
  correlated cartesian product; missing segment values throw.
- **Fixed:** the SSG runner writes only the first-party runtime JS (from the
  inline constants) and never copies the application's `web/` host files over
  generated pages.
- New pure-Dart library `package:hydraline_flutter/build.dart` for
  `bin/build.dart` executables (exports `runSsgCli`, adapters, `SsgRunner`);
  `runSsgCli` is also exported from the umbrella library.
- Runtime JS: DSD fallback adopts the server-rendered template (fallback
  content survives on browsers without Declarative Shadow DOM), `data-size`
  sizing targets `:host`, `dehydrate` cannot tear down a re-hydrated view,
  re-evaluating the dispatcher never wires duplicate listeners, media-query
  listeners detach when the island leaves the DOM.

## 0.0.1

Initial release.

- `Seo.*` widgets - dual-nature widgets (`text`, `heading`, `image`, `link`,
  `section`, `list`, `head`) that render visually and self-register semantic
  content into the `SsgCollector`.
- `Island` - declarative island zones with hydration directives, render/style
  modes, anti-CLS sizing, JSON-safe props and `mediaQuery` support.
- `HydraApp` / `HydraScope` - integration wrapper + InheritedWidget carrying
  the collector; does not replace `MaterialApp`.
- `SsgSandbox` - stub `MediaQuery`/`Directionality` ancestors for headless
  extraction.
- `IslandMultiViewApp` + `IslandHost` + `IslandViewRegistry` - multi-view
  island runtime: one engine instance, one FlutterView per island, bindings
  populated automatically from `addView()` initialData on the web,
  per-island async factories with deferred imports.
- `SsgRunner` - build-time HTML generation from the route manifest with
  pure-Dart page builders, dynamic segment expansion, sitemap.xml, robots.txt
  and island asset copying.
- `dart run hydraline_flutter:build` - SSG CLI
  (`<manifest.yaml> <outputDir>` or `--config`/`--output`).
- `RouteAdapter` - `GoRouterAdapter` and `Navigator2Adapter`.
- `SsgDevTools` - island diagnostics (props budget, anti-CLS warnings).
- `SsgDomDiff` - SSG-HTML vs hydrated-DOM text divergence comparator.
- Level-2 web runtime assets - pretty, branded, first-party JS:
  `<hydraline-island>` Custom Element with Declarative Shadow DOM, island
  dispatcher (directive wiring, engine loading, `app.addView()` per island
  with `{ islandId, state }` initialData, `window.hydraline` API,
  `window.HYDRALINE_CONFIG`), Service Worker, virtual views.
- Hosting recipes for Firebase, Netlify, Cloudflare Pages and GitHub Pages.

Minimum Flutter 3.35.
