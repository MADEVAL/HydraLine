# Hydraline - Post-Review Fixes & Future Roadmap

Companion to `REVIEW.md`. This documents what was fixed in the pre-production
review follow-up (all TDD, regression-tested) and what is worth adding next to
make the project better.

Date: 2026-07-15
Method: red-green-refactor per finding; no production code without a failing
test first. Final gate below is green on a fresh run.

---

## 1. Verification (fresh run)

| Gate | Result |
|---|---|
| `melos run analyze` (`--fatal-infos --fatal-warnings`) | No issues found |
| `melos run format:check` | 106 files, 0 changed |
| `hydraline` tests | 222 passed |
| `hydraline_server` tests | 103 passed |
| `hydraline_flutter` tests | 139 passed |
| `example` tests | 11 passed |
| `melos run boundaries` (I1) | OK, no forbidden imports |
| `melos run audit` (SSG + SEO audit) | 0 errors, 0 warnings |
| `melos run precommit` (full superset) | SUCCESS |

Net new tests added: +10 core, +10 server, +6 flutter (each watched fail first).

---

## 2. What was fixed (every confirmed REVIEW.md finding)

Each item lists the fix and the guarding test.

### hydraline (core)

- **3.1 enabler - nested semantic sectioning.** Added
  `SsgCollector.beginSection(role)`, `beginList(ordered)` and
  `SsgListScope.beginItem()`. Child scopes register a live `SectionNode` /
  `ListNode`/`ListItemNode`, keep their own dedup namespace, and forward
  `addMeta` to the document root.
  *Tests:* `collector_test.dart` "nested sectioning" group.
- **3.5 - hardened vanilla island JS.** `Carousel` and `CopyButton` guard
  missing controls; the bootstrap loop wraps each handler in `try/catch` so one
  broken island cannot abort the rest of the page.
  *Tests:* `web_assets_test.dart` (guard + isolation assertions).
- **3.11 - `SafeUrl.tryParse` rejects empty/whitespace** (no `href=""`/`src=""`
  self-link footgun), while still allowing `/`, `#`, `?`, `./`.
  *Tests:* `escaping_test.dart`.
- **3.12 - sitemap `lastmod` in UTC** (`_date` converts via `.toUtc()`), fixing
  off-by-one dates for local-time `DateTime`s near midnight.
  *Tests:* `seo_artifacts_test.dart` (verified RED on a +02:00 machine).

### hydraline_server

- **3.7 - HEAD requests** return headers with an empty body (method checked at
  the middleware boundary). *Tests:* `review_fixes_test.dart`.
- **3.8 - `DocumentBuilder` `data`** now carries the matched `RouteEntry`
  instead of a permanent `null`. *Tests:* `review_fixes_test.dart`.
- **3.9 - cache byte cap.** `InMemoryCache(maxEntryBytes:)` skips oversized
  entries, bounding worst-case memory. *Tests:* `cache_middleware_test.dart`.
- **3.10 - unified redirects.** `_redirectResponse` delegates to
  `Http.redirect`/`Http.gone`, so 303/307/308 share one semantic path.
  *Tests:* `redirect_status_test.dart` (303 See Other added).
- **3.16 - lowercase response headers** (`etag`/`vary`/`cache-control`/
  `content-type`) for HTTP/2 friendliness. Covered by existing cache tests.
- **3.17 - CRLF header validation.** `HtmxResponse`/`Htmx.redirect` reject
  `HX-*` values containing CR/LF. `Assets.injectFlutterAssets` escapes
  `baseHref` before embedding it in `<script>` tags.
  *Tests:* `htmx_helpers_test.dart`, `robots_assets_test.dart`.

### hydraline_flutter

- **3.1 - `Seo.section`/`Seo.list` emit real structure.** They now register
  `SectionNode` (with `role` -> `<section>/<main>/<nav>/...`) and `ListNode` +
  `ListItemNode` (`<ol>/<ul>/<li>`) via nested collector scopes, instead of a
  flat paragraph stream. *Tests:* `seo_widgets_test.dart` (rewritten to assert
  real structure).
- **3.3 - service worker.** Switched to stale-while-revalidate and added
  old-cache purge on `activate`, so redeployed engine assets are picked up.
  `web/service-worker.js` and the Dart constant were updated byte-identically.
  *Tests:* `js_runtime_test.dart` (+ the byte-identical sync test still passes).
- **3.4 - `RouteAdapter.navigateToForExtraction` revived.** `GoRouterAdapter`
  drives `go()` on the wrapped router; `Navigator2Adapter` records the current
  route (exposed via `current`). *Tests:* `route_adapter_test.dart`.
- **3.13 - `IslandHost` error handling.** A synchronous factory throw or a
  rejected factory future now renders a fallback instead of crashing.
  *Tests:* `island_host_test.dart`.
- **3.18 - `bin/build.dart`** imports the public
  `package:hydraline_flutter/build.dart` surface instead of `src/`.

### Docs / changelogs

- `docs/flutter-widgets.md` updated to describe the real `Seo.section`/`Seo.list`
  semantics. Root + per-package `CHANGELOG.md` gained an `Unreleased` section.

---

## 3. Deliberately not changed (with rationale)

These REVIEW.md items were re-evaluated and intentionally left as-is; changing
them would trade a real property for a cosmetic one.

- **3.6 - `SsgCollector` silent drop after `seal()`.** This is a *tested,
  documented contract* (`collector_test.dart` "add* is ignored after seal()")
  that protects against Flutter rebuild-after-seal. Throwing here would crash
  legitimate widget rebuilds. `addMeta` "last wins" is likewise the correct
  semantics for a head widget that rebuilds. Kept by design.
- **3.2 - cache implies buffered transport.** Buffered delivery is *required*
  for correct `ETag`/`304` revalidation; streaming cached bodies would drop that
  benefit. This is a correct engineering trade-off, now documented, not a bug.
- **3.14 - `Island.props` vs node `state`.** `props` is idiomatic Flutter widget
  terminology; the `data-state` attribute is a wire-format contract. Renaming
  across widget/spec/node/attribute is a breaking change with no functional
  gain. Kept.
- **3.15 - `Seo.text(headingLevel:)` vs `Seo.heading`.** Minor ergonomic
  overlap; both are used across examples/tests and neither is wrong. Kept.
- **JS document-level listeners / observers (F2.3/F2.4).** Attached to
  `document`, which outlives the page; not a leak for the single-page island
  host. Kept.

---

## 4. Future work - what to add to make Hydraline better

Ordered by impact. None of this is required to ship what exists; it is how the
project grows from "solid pre-1.0" to "confidently production".

### 4.1 Prove the island runtime in a real browser (highest impact)

**Status: baseline delivered.** `e2e/` now hosts a Playwright harness
(`melos run e2e`, CI job `e2e`) that runs the real shipped runtime JS
(`packages/hydraline_flutter/web/*.js`) in system Chrome with a mocked Flutter
engine and asserts, against a real DOM:
- `hydrateOnLoad` mounts one view with `{ islandId, state }` and flips
  `data-hydration` -> `hydrated` / `aria-busy` -> `false`;
- `hydrateOnInteraction` stays cold until a real click, then hydrates once;
- a failing engine bootstrap ends in `failed` + `hydraline:island-error`
  with no uncaught rejection;
- re-evaluating the dispatcher never double-mounts; `dehydrate` removes the
  captured view id and resets to `pending`;
- the custom element reserves `data-size` as `:host` width/height (anti-CLS)
  and keeps the Declarative Shadow DOM fallback;
- virtual views emit `hydraline:segment-enter` for in-viewport segments.

Remaining for full 4.1: swap the engine mock for a real compiled Flutter web
build (`flutter build web`) to cover engine boot + `IslandHost` mounting, add a
CLS measurement, and a service-worker warm-visit scenario (needs a persistent
origin across reloads).

### 4.2 Widget-based extraction pipeline (surface A end-to-end)
`navigateToForExtraction` is now functional but not yet driven by an
end-to-end runner. Add a `flutter test --tags ssg` harness that, per route,
navigates the adapter, pumps the tree, and seals the `SsgCollector` into HTML -
so `Seo.*` widget pages (not just pure-Dart builders) can be statically
generated. This makes the two "surfaces" (A widgets / B pure-Dart) truly
symmetric.

### 4.3 Cache and delivery hardening
- Pluggable distributed cache (Redis/file) behind `HydralineCache`, plus a
  total-byte-budget eviction option in `InMemoryCache`.
- `Vary: Accept-Encoding` on all responses (streamed and buffered), and gzip/
  brotli negotiation for buffered bodies.
- `Last-Modified` + `If-Modified-Since` alongside the existing `ETag`/`304`.

### 4.4 SEO surface completeness
- Sitemap `lastmod` full W3C datetime (time + `Z`), image/news/video sitemap
  extensions, and `<priority>`/`<changefreq>` per-route config.
- First-class `hreflang` cluster validation in the audit CLI (reciprocal links,
  x-default), and Core Web Vitals hints in the audit output.
- JSON-LD schema helpers beyond the current set (BreadcrumbList, FAQPage,
  Product with offers/ratings) with typed builders.

### 4.5 Security depth
- Optional Subresource Integrity (`integrity`/`crossorigin`) on the injected
  engine `<script>` tags and the HTMX runtime.
- A default `UnsafeHtmlNode` sanitizer (allowlist-based) so the opt-in escape
  hatch is safe-by-default, with the raw path behind an explicit
  `UnsafeHtmlNode.trusted`.
- ReDoS-safe bot-UA matching guidance (anchored patterns) and a shipped default
  `botUserAgentPattern`.

### 4.6 Developer experience
- `package:go_router` typed adapter (drop the dynamic reflection once a soft
  dependency is acceptable), and a Navigator 2.0 example.
- A `create` scaffold (`dart run hydraline:new`) that emits a minimal
  document/hybrid app wired for SSR + SSG.
- Coverage reporting in CI against the I9 thresholds (core/server >= 90%,
  flutter >= 80%) with a badge.
- DevTools panel polish: live island hydration timeline and CLS overlay.

### 4.7 Ecosystem / release
- Publish to pub.dev with example-driven API docs; add `dartdoc` CI.
- A benchmark suite (serializer throughput, TTFB for streamed SSR) tracked over
  time to protect the "single-pass, no quadratic concat" invariant.
- Real-world showcase deployment (the `example/`) on a static host + an edge
  SSR host, linked from the README as living proof of "no cloaking".

---

## 5. Bottom line

All confirmed review findings are fixed and guarded by tests; the full
`precommit` gate is green. The core and server are now noticeably tighter
(HEAD, redirects, cache bounds, header safety, UTC dates, empty-URL rejection),
and the Flutter surface finally delivers the semantic sectioning it always
advertised. The remaining path to a confident 1.0 is primarily **real-browser
validation of the island runtime** (4.1) and an **end-to-end widget extraction
pipeline** (4.2) - everything else is incremental polish.
