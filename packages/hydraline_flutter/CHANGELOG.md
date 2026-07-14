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
