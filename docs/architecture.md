# Architecture

## Project Structure

Hydraline is a Dart/Flutter monorepo with three packages:

```
hydraline/
├── packages/
│   ├── hydraline/            Core — pure Dart
│   ├── hydraline_server/     Server — pure Dart
│   └── hydraline_flutter/    Flutter — widgets + JS runtime
└── docs/
```

### `hydraline` (core)

Pure-Dart package with **zero Flutter dependencies**. Contains everything
needed to build and serialize semantic HTML:

- `DocumentNode` tree (all node types)
- HTML serializer (single-pass, streaming, fragment modes)
- Contextual escaping and `SafeUrl`
- Metadata model (Open Graph, Twitter Card, hreflang)
- JSON-LD structured data builders
- Sitemap and robots.txt generators
- Route manifest and island manifest
- `SsgCollector` for widget extraction
- SEO validators and CLI audit tools
- Level 0–1 web assets (vanilla islands, HTMX glue)

### `hydraline_server`

Pure-Dart server package with **zero Flutter dependencies**. Plugs into shelf
or Dart Frog:

- shelf middleware + Dart Frog adapter
- Route matching and server-side rendering
- Streaming delivery (single-pass in-order)
- Bot-aware transport (buffered for bots, chunked for users)
- HTMX helpers (`renderFragment`, `HtmxResponse`, `HtmxTrigger`)
- HTTP semantics (status codes, redirects, `X-Robots-Tag`)
- Caching (in-memory, pluggable)
- Asset serving (sitemap, robots, L0–L1 JS)

### `hydraline_flutter`

Flutter package with the widget surface and client-side runtime:

- `Seo.*` widgets (dual-nature: visual + self-registering)
- `Island` widget (declarative island zones)
- `HydraApp` / `HydraScope` (InheritedWidget for collector access)
- `IslandHost` (multi-view runtime, one engine → N islands)
- `SsgRunner` + CLI (build-time HTML generation)
- `SsgSandbox` (stubs for headless extraction)
- `RouteAdapter` + `GoRouterAdapter` (router integration)
- L2 web runtime: Custom Element, dispatcher, Service Worker, virtual views

## Dependency Rules

```
hydraline (core)  ──► No flutter, no dart:ui, no dart:html
hydraline_server  ──► Imports hydraline; no flutter, no dart:ui
hydraline_flutter ──► Imports hydraline + flutter
```

These boundaries are enforced at build time. The server physically cannot
execute Flutter widgets — it works exclusively with pure-Dart `DocumentNode`
builders.

## DocumentNode Model

The central data structure is a sealed, immutable tree of `DocumentNode`
subtypes:

```
DocumentNode (sealed)
├── DocumentRootNode       Root: head + body + lang
├── HeadNode               <head> container
│   ├── TitleNode          <title>
│   ├── MetaNode           <meta name/property/content>
│   ├── LinkNode           <link rel href hreflang>
│   └── JsonLdNode         <script type="application/ld+json">
├── Block nodes
│   ├── HeadingNode        <h1>..<h6>
│   ├── ParagraphNode      <p>
│   ├── SectionNode        <section>/<article>/<nav>/<header>/<footer>/<main>
│   ├── ListNode           <ul>/<ol> with ListItemNode
│   ├── BlockquoteNode     <blockquote>
│   ├── PreNode            <pre>
│   ├── CodeNode           <code>
│   ├── TimeNode           <time datetime>
│   ├── TableNode          <table> with TableRowNode / TableCellNode
│   └── DetailsNode        <details> with SummaryNode
├── Inline nodes
│   ├── TextNode           Plain text (escaped on serialization)
│   ├── AnchorNode         <a href> (SafeUrl required)
│   └── ImageNode          <img src alt width height> (SafeUrl required)
├── Island placeholders
│   ├── IslandPlaceholderNode  Flutter island (level 2)
│   ├── HtmxIslandNode         HTMX island (level 1)
│   └── VanillaIslandNode      Vanilla JS island (level 1)
└── UnsafeHtmlNode         Raw HTML (opt-in, sanitizer recommended)
```

The tree is always:
- **Immutable** — nodes are `const`-constructible where possible
- **Deterministic** — same input → identical tree → identical HTML
- **Acyclic** — verified at build time
- **Type-safe** — URLs are `SafeUrl`, text is always escaped

## HTML Serialization

The serializer walks the `DocumentNode` tree exactly once, writing directly
to a `StringSink`. It never builds an intermediate string tree or VDOM.

Three modes:

| Mode | Method | Output |
|---|---|---|
| Buffered | `serialize(root)` | Complete HTML string — for bots, SSG files |
| Streaming | `serializeToStream(root)` | `Stream<String>` — progressive chunked delivery |
| Fragment | `serializeFragment(node)` | HTML without `<html>/<head>` — for HTMX responses |

Key properties:
- **Single-pass** — O(nodes + text length), no quadratic concatenation
- **Deterministic** — stable attribute order, predictable output
- **Identity guarantee** — `serialize(root)` is byte-identical to the
  concatenation of `serializeToStream(root)` on the same input
- **Line endings** — always `\n`, cross-platform

## SSR + Streaming

Request-time rendering follows a two-layer design:

```
Content layer (UA-BLIND)     Transport layer (may read UA)
─────────────────────────    ─────────────────────────────
builder(req, data)           bot  → buffered (Content-Length)
  → DocumentNode             user → chunked  (Transfer-Encoding)
  → identical HTML           → SAME byte stream →
```

The `DocumentBuilder` function signature deliberately excludes `User-Agent`.
The builder always produces the same `DocumentNode` for the same input.
The transport layer decides buffered vs. chunked delivery based on UA,
but the body bytes are identical. This is not cloaking — cloaking means
*different bodies*; here only `Transfer-Encoding` differs.

Streaming order (in-order, progressive flush):
1. Shell: `<!DOCTYPE html>`, `<head>` with metadata and JSON-LD
2. Static content: headings, paragraphs, images, links (in document order)
3. Island placeholders: skeletons with `data-state` (in document order)

## Islands Architecture

Islands are isolated interactive zones on a static page. They hydrate
independently — one island never blocks another.

### Level 0: Static HTML

No JavaScript. Semantic HTML with `<details>`/`<summary>` for no-JS accordions.
Island skeletons reserve space with `min-height` to prevent CLS.

### Level 1: Vanilla + HTMX

- **Vanilla islands** (~8 KB): A small JS bundle provides tabs, accordions,
  carousels, copy buttons, theme toggles, lazy images. Each has a no-JS fallback
  (e.g. tabs use `:target` anchors).
- **HTMX islands** (~14 KB): Server renders HTML fragments on demand. HTMX
  replaces DOM without page reload. No Flutter engine involved.

### Level 2: Flutter Islands

The Flutter engine is loaded only when a level-2 island triggers hydration.
The client-side runtime consists of:

1. **Custom Element** `<hydraline-island>` with Declarative Shadow DOM.
   Reserves exact pixel dimensions and pins them with a ResizeObserver -
   avoiding multi-view sizing bugs.
2. **Dispatcher**: a single global script. One `IntersectionObserver` for
   all `onVisible` islands, one `requestIdleCallback` for all `onIdle`, one
   delegated event listener for `onInteraction`. Loads the Flutter engine
   only on the first trigger, then mounts one `FlutterView` per island via
   `app.addView()` with explicit `viewConstraints` and
   `{ islandId, state }` as `initialData`.
3. **IslandMultiViewApp / IslandHost** (Dart side): the multi-view root.
   Turns the `initialData` of each view into an `IslandViewRegistry`
   binding and mounts the matching island widget factory. One engine
   instance, N views.
4. **Service Worker**: caches `main.dart.js` and `canvaskit.wasm` with a
   cache-first strategy. Warm visits: ~1s TTI.

Island lifecycle states:

```
data-hydration="pending"     Initial, waiting for trigger
data-hydration="hydrating"   Engine loading, deferred chunk fetching
data-hydration="hydrated"    Island is interactive
data-hydration="failed"      Terminal failure; fallback remains visible
```

On failure, a `hydraline:island-error` DOM event fires with `{id, reason}`.

### Resumable Model

Island state is serialized as JSON into the `data-state` HTML attribute.
On hydration, the island deserializes this state and resumes from it —
no widget tree recalculation needed.

## SSG Pipeline

Build-time static site generation:

```
1. Parse hydraline.routes.yaml
2. For each document/hybrid route (dynamic segments expanded):
   a. (Surface B) Call the registered pure-Dart SsgPageBuilder
   b. (Surface A) Or extract widgets in flutter_tester:
      Seo.* widgets self-register into SsgCollector (SsgSandbox harness)
   c. Fallback: metadata-only shell from the manifest
3. Serialize DocumentNode → HTML files in dist/
4. Generate sitemap.xml + robots.txt
5. Copy island runtime assets into dist/ (only if Flutter islands exist)
6. Output: self-contained dist/ ready for static hosting
```

The CLI runs surface B on the plain Dart VM:

```bash
dart run hydraline_flutter:build hydraline.routes.yaml dist
```

Surface A (widget extraction) requires `flutter_tester` — run it as a test
tagged `ssg` that pumps pages inside `SsgSandbox` and feeds the sealed
collector output to the runner.

## Client-Side Runtime

### Custom Element

```html
<hydraline-island
  id="calculator"
  data-directive="hydrateOnVisible"
  data-render-mode="ssr"
  data-style-mode="shadow"
  data-state='{"price":89990}'
  role="region"
  aria-busy="true">
  <template shadowrootmode="open">
    <style>
      :host { display: block; contain: layout style paint; }
      .host { width: 640px; height: 480px; }
    </style>
    <div class="host">
      <slot> <!-- SSR fallback / skeleton --> </slot>
    </div>
  </template>
</hydraline-island>
```

Declarative Shadow DOM means no FOUC — the shadow root exists from HTML parse
time. The same element is reused during hydration (no re-creation).

### Dispatcher

A single global script (`hydraline-dispatcher.js`, pretty and branded) that:
- Observes all islands and triggers hydration per directive - one
  `IntersectionObserver` for all `onVisible` islands, one idle callback for
  `onIdle`, one delegated listener for `onInteraction`, `matchMedia`
  listeners for `onMedia`
- Loads the Flutter engine once (on the first trigger)
- Mounts one `FlutterView` per island via `app.addView()`, passing explicit
  `viewConstraints` and `{ islandId, state }` as `initialData`
- Manages `data-hydration` lifecycle states, timeouts and the
  `hydraline:island-error` event
- Exposes `window.hydraline` (`hydrate(id)`, `hydrateAll()`,
  `dehydrate(id)`, `views`) and reads `window.HYDRALINE_CONFIG`
  (`engineScript`, `timeoutMs`, `rootMargin`, `debug`)

The engine contract is either of:

1. `window._hydralineApp` - a Promise of the multi-view Flutter app handle,
   exposed by a custom `flutter_bootstrap.js` (preferred):

   ```js
   {{flutter_js}}
   {{flutter_build_config}}
   window._hydralineApp = new Promise((resolve, reject) => {
     _flutter.loader.load({
       onEntrypointLoaded: async (init) => {
         const engine = await init.initializeEngine({ multiViewEnabled: true });
         resolve(await engine.runApp());
       },
     });
   });
   ```

2. A bootstrap exposing `_flutter.loader.load()`, which the dispatcher
   drives itself with `{ multiViewEnabled: true }`.

On the Dart side, `IslandMultiViewApp` reads each view's `initialData`,
registers the binding in `IslandViewRegistry` and `IslandHost` mounts the
matching island widget - one engine instance, N views (see
[Flutter Widgets](./flutter-widgets.md#islandhost-and-islandviewregistry)).

### Service Worker

Caches the engine binary and WASM module. On warm visits, TTI drops to ~1 second
by serving cached assets and pre-warming the WASM module via streaming
instantiation.

## Zero Overhead Guarantee

If a page has no `IslandType.flutter` islands, `flutter_bootstrap.js` is never
inserted and the Flutter engine is never loaded. Levels 0 and 1 work entirely
without Flutter. This is verified at the dispatcher and SSR/SSG generator levels.

## See Also

- [Getting Started](./getting-started.md) — first steps
- [Document Model](./document-model.md) — the tree in detail
- [Server](./server.md) — SSR delivery in practice
- [Flutter Widgets](./flutter-widgets.md) — the widget surface
- [Security](./security.md) — threat model and guarantees
