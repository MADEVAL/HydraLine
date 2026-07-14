# Hydraline — JS/DOM Runtime Contract (L4)

| Field | Value |
|---|---|
| Package | `hydraline_flutter/web/` |
| Purpose | Frozen client runtime contract: HTML elements, attributes, events, global JS API |

> The client runtime is the single custom JS layer (level 2). This contract
> freezes the "HTML ↔ browser runtime" boundary before implementation. Size budgets
> (min+gzip): Custom Element ≤ 2 KB, dispatcher ≤ 2 KB, Service Worker ≤ 2 KB,
> virtual ≤ 2 KB.

---

## 1. Custom Element `<hydraline-island>`

### 1.1 Markup (emitted by the serializer for `IslandType.flutter`)

```html
<hydraline-island
  id="calculator"
  data-directive="hydrateOnVisible"
  data-render-mode="ssr"                       <!-- ssr | skeletonOnly -->
  data-style-mode="shadow"                      <!-- shadow | scoped -->
  data-state='{"price":89990,"currency":"RUB"}' <!-- JSON, HTML-escaped, ≤10 KB -->
  data-hydration="pending"                      <!-- set by runtime -->
  role="region" aria-busy="true" aria-label="Calculator, loading">
  <template shadowrootmode="open">
    <style>:host{display:block;contain:layout style paint}
           .host{width:640px;height:480px}</style>
    <div class="host"><slot>
      <!-- SSR-fallback / skeleton (visible without JS) -->
    </slot></div>
  </template>
</hydraline-island>
```

### 1.2 Behavioral contract (MUST)
- **CE1.** Uses the **existing** Shadow Root from DSD (does not call `attachShadow` again → no FOUC).
- **CE2.** Host dimensions — fixed px (from `IslandSize`, anti-CLS).
- **CE3.** On mount, passes explicit `viewConstraints` with `min==max` to `addView()` (workaround for #185034).
- **CE4.** `ResizeObserver`-corrector: recalculates pinned constraints only on committed resize; coalesces all views into one `requestAnimationFrame`; debounce; **no-op on Flutter 3.41.x**.
- **CE5.** `scoped` mode (`data-style-mode="scoped"`): styles extracted 1× into `<head>`, islands receive a scope attribute.

### 1.3 Virtual segments (tall islands)
```html
<hydraline-island-segment data-virtual="calc" data-offset="0"    data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
<hydraline-island-segment data-virtual="calc" data-offset="4000" data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
```
- **VS1.** Segments in viewport (+`rootMargin`) → `addView()`; exited → `removeView()`.
- **VS2.** Activates only when `IslandType.flutter` above threshold (~4000px); otherwise zero overhead.

---

## 2. Dispatcher `window.hydraline`

### 2.1 Global API
```ts
interface HydralineGlobal {
  hydrate(id: string): Promise<void>;   // manual hydration of one island
  hydrateAll(): Promise<void>;          // all islands with directive=manual
  readonly version: string;
}
declare const hydraline: HydralineGlobal; // window.hydraline
```
- **DP1.** Works on `document`/`hybrid` pages where `MaterialApp` is NOT running (for `hydrateManual`).
- **DP2.** One `IntersectionObserver` for all `hydrateOnVisible`; one `requestIdleCallback` for all `hydrateOnIdle`; one delegated `click`/`focusin` for `hydrateOnInteraction`; `matchMedia` for `hydrateOnMedia`.
- **DP3.** Flutter engine is loaded **only** on the first trigger of any island.
- **DP4.** Hydration order — top-down (parent before nested).

### 2.2 Directives (`data-directive` values)
| Value | Trigger | Browser API |
|---|---|---|
| `hydrateOnLoad` | immediately on DOMContentLoaded | `DOMContentLoaded` |
| `hydrateOnIdle` | idle (default) | `requestIdleCallback` (+fallback) |
| `hydrateOnVisible` | viewport | `IntersectionObserver` |
| `hydrateOnInteraction` | first interaction | global delegation |
| `hydrateOnMedia` | media-query match | `matchMedia` (`data-media`) |
| `hydrateManual` | `window.hydraline.hydrate(id)` | — |

### 2.3 Lifecycle (`data-hydration`)
```
pending → hydrating → hydrated
                    ↘ failed   (timeout / engine or deferred chunk load error)
```
- **DP5.** On terminal failure: fallback/skeleton **remains visible**; `data-hydration="failed"` is set; `aria-busy` is removed.
- **DP6.** Limited retry with timeout on engine load and per-island chunk.

### 2.4 Error event
```ts
// dispatchEvent on the host element, bubbles
new CustomEvent('hydraline:island-error', { bubbles: true, detail: { id: string, reason: string } })
```

### 2.5 Hand-off to Flutter (JS→Dart boundary)
```ts
// initialData carries id → IslandHost (Dart) maps to factory
flutterApp.addView({
  hostElement,
  viewConstraints: { minWidth: w, maxWidth: w, minHeight: h, maxHeight: h },
  initialData: { id, state /* JSON.parse(data-state) */, directive },
});
```
- **DP7.** `data-state` is parsed only via `JSON.parse`. `eval`/`Function`/`DOMParser` are forbidden.

---

## 3. Vanilla islands (level 1, assets from core)

### 3.1 Markup
```html
<div class="hydraline-island" data-island="accordion" data-island-level="vanilla">
  <details><summary>…</summary><p>…</p></details>
</div>
```
### 3.2 Types and no-JS fallback
| `data-island` | Action | Fallback without JS |
|---|---|---|
| `accordion` | animation + aria over `<details>` | `<details>` works |
| `tabs` | panel switching | `:target` via anchors |
| `carousel` | slide carousel | static strip |
| `theme` | `data-theme` toggle | `prefers-color-scheme` |
| `copy-button` | clipboard copy | regular button |
| `lazy-image` | lazy loading | `<img loading="lazy">` |

- **VA1.** Mount on `DOMContentLoaded`; do not depend on the Flutter engine.
- **VA2.** The `hydraline_flutter` package **reuses** this bundle from core, without duplication.

---

## 4. HTMX islands (level 1)

### 4.1 Markup
```html
<div class="hydraline-island" data-island="htmx" data-island-level="htmx"
     hx-get="/api/reviews/iphone15" hx-trigger="load" hx-swap="innerHTML">
  <div class="skeleton">Loading reviews...</div>
</div>
```
- **HX1.** HTMX script (~14 KB) is vendored as first-party (CSP-compatible with `script-src 'self'`), loaded only when HTMX islands are present.
- **HX2.** The server responds with an HTML fragment (`serializeFragment`) — without `<html>/<head>`, without the Flutter engine.

---

## 5. Service Worker

- **SW1.** Caches `main.dart.js` + `canvaskit.wasm`.
- **SW2.** Preheats via `WebAssembly.instantiateStreaming()` + `<link rel="preload">`/`modulepreload`.
- **SW3.** Warm repeat visit: TTI ~1 s.

---

## 6. Zero-overhead invariant

- **ZO1.** If a page has no `IslandType.flutter` → `flutter_bootstrap.js` is **not inserted**, and the base L2 JS (Custom Element/dispatcher/SW) is not loaded.
- **ZO2.** Levels 0–1 (static, vanilla, HTMX) work without Flutter entirely.
- **ZO3.** Verification — at the SSR/SSG generator and dispatcher level.

---

## 7. DOM Contract Summary (frozen)

**Elements:** `<hydraline-island>`, `<hydraline-island-segment>`.
**Attributes:** `data-directive`, `data-render-mode`, `data-style-mode`, `data-state`,
`data-hydration`, `data-media`, `data-island`, `data-island-level`, `data-virtual`,
`data-offset`, `data-height`.
**Events:** `hydraline:island-error`.
**Global:** `window.hydraline.hydrate(id)`, `window.hydraline.hydrateAll()`, `window.hydraline.version`.

---

*L4 complete across all three packages + JS runtime. Contract changes — only via
versioning and synchronization with the main specification.*
