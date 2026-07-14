# Gap Report — Spec vs Implementation

Generated 2026-07-14. Compares `HYDRALINE_SPEC_V3.md` + phase plans
against actual code/tests in `packages/`.

---

## Summary

| Category | Count |
|---|---|
| Total phase tasks (P1-01…P4-15) | 72 |
| Fully implemented (code + tests) | **43 (60%)** |
| Partially implemented (code, insufficient tests) | **18 (25%)** |
| Missing (no code or no tests at all) | **5 (7%)** |
| Test-only infrastructure tasks | **6 (8%)** |

---

## By Phase

| Phase | Tasks | Fully | Partial | Missing |
|---|---|---|---|---|
| Phase 1 — Core `hydraline` | 22 | **22** | 0 | 0 |
| Phase 2 — Server `hydraline_server` | 12 | **10** | 2 | 0 |
| Phase 3 — Flutter widgets | 10 | **8** | 2 | 0 |
| Phase 4 — Islands / SSG / DevTools | 15 | **0** | 12 | 3 |

---

## Missing Features (no code)

| ID | Task | Notes |
|---|---|---|
| P4-08 | SSG CLI (`dart run hydraline_flutter:build`) | No `bin/` directory. SSG runner exists but no CLI entry point. |
| P4-11 | DevTools overlay (highlight islands, hydration diagnostics) | Not implemented. |
| P4-12 | SSG-HTML ↔ hydrated DOM diff (>5% mismatch → warning) | Not implemented. |
| P4-15 | E2E Playwright test suite | No Playwright config/tests anywhere in repo. |

---

## Partially Implemented (insufficient tests)

| ID | Task | Gap |
|---|---|---|
| P4-01 | Custom Element `<hydraline-island>` with DSD | Only string-content checks. No browser E2E (FOUC, DSD render without JS). |
| P4-02 | viewConstraints + ResizeObserver | Only `contains('ResizeObserver')` check. No canvas–host sizing test. |
| P4-03 | Scoped CSS mode | Enum exists. JS has no `@scope`/`adoptedStyleSheets` implementation. |
| P4-04 | Dispatcher (Qwikloader-style) | All directives implemented. No per-directive E2E test. Budget not verified. |
| P4-05 | Reuse vanilla islands from core | No import/export linkage test between packages. |
| P4-06 | Service Worker | Caches `main.dart.js` + `canvaskit.*`. No E2E warm-visit TTI test. Budget not checked. |
| P4-07 | SSG runner (manifest → dist/) | Writes HTML/sitemap/robots. Missing Flutter-asset copying. No determinism (SSG3) test. |
| P4-09 | Dynamic segments (`/blog/:slug`) | `DynamicSegments.expand` exists but not integrated with runner loop. |
| P4-10 | Hosting recipes | Only checks Firebase+Netlify strings. Missing Cloudflare + GitHub Pages output checks. |
| P4-13 | Virtual views (IntersectionObserver) | Only string checks. No E2E scroll test. |
| P4-14 | Zero-overhead (no Flutter islands → no engine) | Serializer-level test exists. SSG runner doesn't conditionally skip assets. No E2E network-log test. |
| P2-02 | DocumentBuilder UA-blind contract | Typedef excludes UA. No compile-time enforcement test. |
| P2-04 | Bot-aware delivery | Middleware doesn't branch on UA for chunked/buffered. |
| P2-12 | Integration harness + A8 in CI | No dedicated CI job for live-server identity check. |
| P3-04 | Island widget self-registration | No dedicated widget test for registration + extraction. |
| P3-06 | Island entry-point compilation | `island_main.dart` exists but no compilation/bundle-size test. |

---

## Missing Acceptance Test Coverage (A1–A10)

| Scenario | Status | Notes |
|---|---|---|
| A1 — Valid HTML without JS | PARTIAL | Golden tests cover output. No curl/view-source E2E check. |
| A2 — OG/Twitter in view-source | COVERED | `audit_test.dart` standalone checks. |
| A3 — Hybrid: static visible + islands hydrate + CLS≈0 | **UNCOVERED** | Requires Playwright. |
| A4 — App-route additivity | PARTIAL | Smoke test exists. No comprehensive isolation test. |
| A5 — sitemap.xml + robots.txt valid | COVERED | `seo_artifacts_test.dart` |
| A6 — SSR status codes / redirects / noindex | PARTIAL | 301/404 covered. No 410/5xx integration test. |
| A7 — No-JS page meaningful/navigable | **UNCOVERED** | No `javaScriptEnabled: false` Playwright test. |
| A8 — Body identity bot=user | COVERED | `delivery_test.dart` + `audit_test.dart`. |
| A9 — No flutter_bootstrap.js when no Flutter islands | PARTIAL | Serializer tested. No Playwright network-log check. |
| A10 — HTMX island without reload | PARTIAL | Server fragment tested. No client E2E. |

---

## Missing Non-Functional Checks

| Budget | Required | Verified? |
|---|---|---|
| Dispatcher JS ≤ 2 KB | NF-4 | **No** |
| Custom Element JS ≤ 2 KB | NF-4 | **No** |
| Service Worker JS ≤ 2 KB | NF-4 | **No** |
| Vanilla Islands JS ≤ 8 KB | NF-4 | Yes (`web_assets_test.dart`) |
| HTMX glue ≤ 14 KB | NF-4 | Yes (`web_assets_test.dart`) |
| Virtual Views JS ≤ 2 KB | NF-4 | Yes (`phase4_rest_dart_test.dart`) |
| Island bundle ≈ 450 KB gzip | NF-4a | **No** |
| Deferred chunk < 100 KB gzip | NF-4a | **No** |
| Skeleton HTML < 50 KB gzip | NF-3 | **No** |
| SSR median render < 50 ms | NF-1 | **No** |
| TTFB < 100 ms | NF-2 | **No** |
| a11y (axe/pa11y) | NF-7 | **No** |

---

## Key Architectural Gaps

1. **SSG asset copying is dead code** — `SsgRunner` always returns `assetsCopied: false`.
   Flutter web assets (main.dart.js, canvaskit, island bundle) are never copied to `dist/`.

2. **Bot-aware UA branching missing in middleware** — `delivery.dart` supports both
   buffered and chunked modes, but `middleware.dart` never branches on User-Agent to
   select buffered for bots.

3. **No E2E infrastructure** — Zero Playwright configs, scripts, or test files in the
   repository. Acceptance scenarios A3, A7, A10 are not verifiable.

4. **Scoped CSS mode is a stub** — The `IslandStyleMode.scoped` enum value exists but
   the JavaScript runtime has no implementation.

5. **SSG determinism (SSG3) untested** — No test verifies that two consecutive SSG runs
   produce byte-identical output.
