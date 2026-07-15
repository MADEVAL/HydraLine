# Hydraline - Pre-Production Repository Review

Reviewer: automated deep code review (read-only, no code changed)
Date: 2026-07-15
Scope: full monorepo (`hydraline`, `hydraline_server`, `hydraline_flutter`, `example`, `tool`, `docs`)
Method: full read of all 105 Dart files + assets + docs, cross-checked against a
fresh run of every verification gate. Every finding below was independently
verified against the actual code; speculative agent findings that did not hold
up are listed in the "False alarms" section so they are not mistaken for real
defects.

---

## 1. Executive summary

Hydraline is a well-engineered, disciplined codebase that is genuinely close to
production quality for its stated niche. It solves a real and current problem
(Flutter Web renders into a `<canvas>`, so crawlers and social bots see an empty
shell). The architecture - a pure-Dart document model that both streams from a
server and compiles to static HTML, with optional Flutter "islands" - is sound,
and the security posture (type-enforced `SafeUrl`, context-aware escaping, a
million-input XSS fuzz suite) is above average for a pre-1.0 project.

All blocking gates are green on a fresh run:

| Gate | Result |
|---|---|
| `melos run analyze` (`--fatal-infos --fatal-warnings`) | No issues found |
| `melos run format:check` | 105 files, 0 changed |
| Core tests (`dart test`) | 212 passed |
| Server tests | all passed (~93) |
| Flutter tests (`flutter test`) | 133 passed |
| `melos run boundaries` (I1 import rules) | OK, no forbidden imports |
| `melos run audit` (SSG build + SEO audit of example) | 0 errors, 0 warnings |

The codebase is small and honest: ~5.5k lines of production Dart against ~5.4k
lines of tests (roughly 1:1), clean package boundaries enforced by tooling, and
documentation that largely matches the code.

The main reservations are not about code hygiene but about maturity and honesty
of the top-level marketing claims:

1. The **Flutter L2 island runtime is unproven in a real browser.** All tests
   are Dart-side widget/unit tests. There is no e2e/browser harness (the repo
   even acknowledges "E2E (Playwright) в репозитории нет"). The most novel and
   fragile part of the product (multi-view engine hosting N islands, JS
   dispatcher, service worker, Declarative Shadow DOM hydration) is validated
   only by asserting on Dart strings, never by loading a page.
2. A **real semantic gap in the Flutter widget surface**: `Seo.section` and
   `Seo.list` silently discard their structural role and emit flat paragraphs
   (details in 3.1). The pure-Dart core does the right thing; the Flutter
   surface does not.
3. Several **"automatic" behaviors advertised in the README are conditional**
   in practice (bot-aware transport is disabled whenever a cache is configured;
   `DocumentBuilder` never receives route data).

Overall grade: **B+ / solid pre-1.0.** Utility and relevance are high; the core
is trustworthy; the Flutter island layer needs real-browser validation before
any "production" claim, and a handful of surface-level inconsistencies should be
closed.

---

## 2. Utility, usefulness, relevance

- **Problem relevance: high and current.** Flutter Web SEO is a genuine,
  unsolved pain point in 2026. The "real HTML in the first response + hydrate
  islands" approach is the correct architectural answer, and the anti-cloaking
  stance (builders cannot see the `User-Agent`) is a real differentiator.
- **Design quality: high.** Single document model feeding SSR and SSG; hard
  package boundaries (core is pure Dart, no `flutter`/`dart:ui`/`dart:html`),
  enforced by `tool/check_boundaries.dart` and CI. Sealed node hierarchy with a
  single-pass serializer. This is idiomatic, testable, and maintainable.
- **Security-by-construction: strong.** `SafeUrl` has no public constructor;
  URLs must pass a scheme allowlist at construction. Two separate escapers
  (text vs attribute) prevent context confusion. JSON-LD is `\uXXXX`-escaped to
  prevent `</script>` breakout. Backed by a 1e6-input fuzz suite that passes.
- **Maturity: early (0.0.3).** The pure-Dart core (document model, serializer,
  SEO artifacts, server middleware) is production-plausible today. The Flutter
  island runtime is ambitious and interesting but effectively unverified
  end-to-end. Treat L0/L1 (static + vanilla/HTMX) as ready; treat L2 (Flutter
  islands) as beta.
- **Bus factor / footprint:** small, focused, one author. That is fine for the
  scope, but the novel JS runtime lacks the browser test coverage that its
  complexity warrants.

Recommendation for adopters: **use it today for document/hybrid pages at L0/L1;
pilot L2 Flutter islands behind real-browser testing before shipping.**

---

## 3. Confirmed findings (verified against code)

Severity legend: CRITICAL (data loss / security) · MAJOR (wrong behavior or
misleading core promise) · MINOR (edge case / robustness) · NIT (cosmetic).

### 3.1 MAJOR - `Seo.section` / `Seo.list` discard their semantic role

`packages/hydraline_flutter/lib/src/seo_widgets.dart:195-219`

```dart
class _SeoSection extends StatelessWidget {
  final SectionRole role;               // stored, never used
  Widget build(...) => Column(children: children);   // no <section>/<main>/<nav>
}
class _SeoList extends StatelessWidget {
  final bool ordered;                   // stored, never used
  Widget build(...) => Column(children: items);       // no <ol>/<ul>/<li>
}
```

The core model fully supports `SectionNode` (emits `<section>/<article>/<nav>/
<header>/<footer>/<main>`) and `ListNode` (emits `<ol>/<ul>`) - see
`html_serializer.dart:103-116`. But the Flutter widget surface deliberately
flattens them: `Seo.section(role: SectionRole.main)` produces **no `<main>`**,
and `Seo.list(ordered: true)` produces **no `<ol>`**. The `role` and `ordered`
parameters are dead for their apparent SEO purpose.

Proof this is intentional and shipped: the test asserts the flattening rather
than catching it (`test/seo_widgets_test.dart:148-150`):

```dart
final body = seal().body;
expect(body, hasLength(1));
expect(body[0], isA<ParagraphNode>());   // NOT a SectionNode
```

Why it matters: semantic sectioning (`<main>`, `<nav>`, `<ol>`) is a core SEO/
accessibility signal - the exact value proposition of this library. A user who
writes `Seo.section(role: main)` reasonably expects `<main>` in `view-source`
and does not get it. The detailed docs (`docs/flutter-widgets.md:93,99`) do
quietly admit "role shapes visual grouping" / "visual hint only", but the
package README still lists these under "register semantic info", and the API
signature strongly implies otherwise. Either wire `role`/`ordered` through to
`SectionNode`/`ListNode`, or remove the parameters so the API stops promising
something it does not deliver.

### 3.2 MAJOR - README "automatic bot-aware transport" is silently disabled when a cache is configured

`packages/hydraline_server/lib/src/middleware.dart:102-131`

When `config.cache != null`, every response goes through `_cachedResponse`,
which always returns a buffered `200` with `Content-Length`. The bot-detection
branch (buffered-for-bots vs chunked-for-humans) at lines 128-131 is only
reachable when `cache == null`. So the two headline features - caching and
bot-aware streaming transport - are mutually exclusive, which no doc states.
Not a correctness bug (bodies are still byte-identical), but a real gap between
the advertised behavior and the implemented behavior.

### 3.3 MAJOR - Service worker cache name never rotates; stale engine served indefinitely

`packages/hydraline_flutter/lib/src/assets/js_service_worker.dart:20,25-56`

```js
var CACHE_NAME = 'hydraline-v1';        // hardcoded, never bumped
var ENGINE_ASSETS = ['main.dart.js', 'canvaskit'];
// install -> skipWaiting(); activate -> clients.claim(); fetch -> cache-first
```

Cache-first on `main.dart.js` (which Flutter does not content-hash by default)
with a fixed cache name and no version invalidation means returning visitors can
be served a stale Flutter engine after a redeploy, with no built-in bust
mechanism. For a library that ships a service worker as a feature, this needs a
version/hash strategy or an explicit "you own cache-busting" warning.

### 3.4 MAJOR - Dead interface method `RouteAdapter.navigateToForExtraction`

`packages/hydraline_flutter/lib/src/route_adapter.dart:20,47,61`

Both implementations are empty `async {}`; the SSG runner never calls it (it is
manifest-driven, and only holds `_adapter` as "reserved for widget-based
extraction", `ssg_runner.dart`). The method is documented in
`docs/flutter-widgets.md:365` as part of the public interface. It is dead
surface area that implies a capability (widget-tree navigation for extraction)
that does not exist.

### 3.5 MINOR - Vanilla island JS throws on missing sub-elements (aborts hydration)

`packages/hydraline/lib/src/assets/vanilla_islands.dart:36-37,40-43`

```js
root.querySelector('[data-carousel-prev]').addEventListener(...); // null-deref if absent
...
function CopyButton(root){var btn=$('[data-copy-target]',root)||root.querySelector('button');
var targetId=attr(btn,'data-copy-target'); ...   // attr(null,...) throws before the guard
```

`Carousel` and `CopyButton` dereference `querySelector` results without a null
guard (unlike `Accordion`, `LazyImage`, `Theme`, which do guard). If a carousel
lacks prev/next buttons, or a copy-button lacks both a `[data-copy-target]` and
a `<button>`, hydration throws a `TypeError`. The bootstrap loop
(`vanilla_islands.dart:62-65`) has no `try/catch`, so one broken island can abort
hydration of the remaining islands on the page.

### 3.6 MINOR - `SsgCollector` silently drops data (post-seal writes, meta overwrite)

`packages/hydraline/lib/src/collector.dart:40-43,82-87`

```dart
void _add(DocumentNode node, String? key) {
  if (_sealed != null) return;   // silently discards
  ...
}
void addMeta(SeoMeta meta) {
  if (_sealed != null) return;   // silently discards
  _meta = meta;                  // silently overwrites a previous addMeta
}
```

Deduplication-by-key is intentional and fine, but silently dropping every write
after `seal()` and silently overwriting a second `addMeta` are footguns that
turn programmer errors into hard-to-debug empty/incorrect pages. Prefer a
`StateError` on post-seal mutation and on double `addMeta`.

### 3.7 MINOR - HEAD requests are handled as GET (full body built and returned)

`packages/hydraline_server/lib/src/middleware.dart:75-134`

The handler never inspects `request.method`. A `HEAD` builds the document,
serializes it, (optionally) caches it, and returns a `Response` with the body
attached. `shelf_io` may strip the body on the wire, but the middleware itself
does unnecessary work and does not honor HEAD semantics at the handler level.

### 3.8 MINOR - `DocumentBuilder`'s `data` parameter is always `null`

`packages/hydraline_server/lib/src/middleware.dart:144`

```dart
return builder(request, null);
```

The typedef is `Function(Request, Object? data)`, but nothing is ever passed.
Matched route metadata and dynamic-segment values are not forwarded; builders
must re-parse `request.url.pathSegments` themselves (as the example does). The
second parameter is currently pure ceremony.

### 3.9 MINOR - In-memory cache bounds entry count but not entry size

`packages/hydraline_server/lib/src/cache.dart:19-46`

`maxSize` limits the number of entries (default 500) but not bytes per entry.
500 large pages is unbounded memory in practice. For a shipped cache, a byte
budget (or at least a documented caveat) is warranted. Also note the map
mutations are only safe under the single-isolate shelf model (fine today, but
worth a comment before anyone shares it across isolates).

### 3.10 MINOR - `_redirectResponse` handles 303 inconsistently with `Http.redirect`

`packages/hydraline_server/lib/src/middleware.dart:147-152` vs
`http_semantics.dart:27-34`

`Http.redirect` has an explicit `303 => Response.seeOther(...)` branch;
`_redirectResponse` (used when a builder throws `RedirectException(status:303)`)
falls to the generic `Response(303, headers:{location})`. Two redirect code
paths, two behaviors. Functionally close, but the inconsistency is real.

### 3.11 MINOR - `SafeUrl.tryParse('')` succeeds, yielding `href=""` / `src=""`

`packages/hydraline/lib/src/escaping.dart:71-78`

An empty or whitespace-only string has no scheme, so it bypasses the allowlist
rejection and returns a valid `SafeUrl('')`. In HTML, `href=""`/`src=""` is a
self-reference (re-requests the current page). Not XSS, but a footgun the type
is otherwise designed to prevent.

### 3.12 MINOR - Sitemap `lastmod` uses local-time fields, not UTC

`packages/hydraline/lib/src/sitemap.dart:150-155`

`_date` reads `dt.year/month/day` directly. A `DateTime.now()` (local) near
midnight in a timezone behind UTC can emit a date off by one day. Convert to
`.toUtc()` or document that callers must.

### 3.13 MINOR - `IslandHost` `FutureBuilder` ignores errors

`packages/hydraline_flutter/lib/src/island_host.dart:70-73`

```dart
return FutureBuilder<Widget>(
  future: factory(binding.state),
  builder: (context, snapshot) => snapshot.data ?? const SizedBox.expand(),
);
```

`snapshot.hasError` / `connectionState` are ignored, so a failing island factory
renders as an empty box with no diagnostic. Additionally, a *synchronous* throw
inside `factory(...)` escapes the `FutureBuilder` entirely (the call is made
eagerly on line 71). A failed deferred `loadLibrary()` would surface as a blank
region in production with no signal.

### 3.14 NIT - Naming divergence: widget `props` vs node/spec `state`

`island.dart` exposes `props`; `island_manifest.dart` and `document_node.dart`
use `state`; the emitted attribute is `data-state`. One concept, three names.

### 3.15 NIT - `Seo.text(headingLevel:)` duplicates `Seo.heading(level:)`

`seo_widgets.dart:17-28` - two public entry points produce the same
`HeadingNode`. Minor API redundancy.

### 3.16 NIT - Response header name casing is inconsistent

`middleware.dart:171-177` emits title-case `ETag`/`Vary`/`Cache-Control` while
`x-robots-tag` (lines 162, and `http_semantics.dart:60`) is lowercase. Harmless
under HTTP/1.1 and normalized by HTTP/2, but inconsistent within one file.

### 3.17 NIT - Defense-in-depth gaps in raw string interpolation

- `assets.dart:75-79` interpolates `baseHref` into an inline `<script src="...">`
  via `UnsafeHtmlNode` without escaping. Config-sourced, not user input, so low
  risk, but the one place the codebase steps outside its own escaping discipline.
- `htmx.dart:35-41,91` writes caller strings into `HX-*` headers without CRLF
  validation. In practice `dart:io`'s header layer rejects CRLF, so this is
  largely mitigated at transport; still worth a validating constructor for
  defense in depth.
- `js_custom_element.dart:65-67` concatenates `data-size` parts into a CSS
  string with no JS-side validation (safe today because the Dart serializer only
  ever emits integers, and it is contained in Shadow DOM).

### 3.18 NIT - `bin/build.dart` bypasses the package's own public surface

`packages/hydraline_flutter/bin/build.dart:3-4` imports `package:hydraline_flutter/src/...`
directly instead of the curated `package:hydraline_flutter/build.dart`,
violating the encapsulation the package advertises.

---

## 4. False alarms (claims that did NOT hold up on verification)

These were flagged during review but are **not** real defects - documented here
so they are not "fixed" into regressions.

- **"IslandStateCodec unescape is not a correct inverse" - FALSE.** The
  encode/decode round-trip was tested directly against inputs containing
  `&quot;`, `&amp;quot;`, `&#39;`, `<`, `>`, `"`; all round-trip correctly
  (encode escapes the JSON string as a whole, decode reverses it). No corruption.
- **"`assets/hydraline/` prefix strip is dead code / returns 404" - FALSE.** In
  shelf, `request.url.path` is a *relative* URL with no leading slash, so
  `path.startsWith('assets/hydraline/')` matches as intended. Confirmed by the
  passing test `robots_assets_test.dart` ("serves assets under the
  assets/hydraline/ prefix too").
- **"example/main.dart path comparisons (`'api/faq'`, `'robots.txt'`) never
  match" - FALSE.** Same shelf relative-URL semantics; the comparisons are
  correct.
- **"`'/${request.url.path}'` produces a double slash `//`" - FALSE.** Same
  reason - `request.url.path` has no leading slash, so this correctly produces a
  single leading slash.

The recurrence of the shelf relative-URL misunderstanding is a good reminder:
`Request.url` is relative to the handler mount point and never carries a leading
slash.

---

## 5. Consistency, docs, and tooling notes

- **Docs vs code: mostly consistent.** `docs/document-model.md`,
  `architecture.md`, and `server.md` accurately describe the node set and
  serializer. The notable divergence is the semantic-sectioning gap (3.1): the
  Flutter widget docs quietly downgrade `role` to "visual only", while the
  package README and the pure-Dart docs present sectioning as a first-class SEO
  feature. Align these.
- **Versioning is consistent:** all four packages and the example are pinned to
  `0.0.3`; CHANGELOGs are per-package and coherent.
- **CI/gates are strong:** `analyze` runs with `--fatal-infos --fatal-warnings`,
  boundaries are machine-enforced, and `precommit` even runs an end-to-end SSG
  audit of the example. This is better rigor than most pre-1.0 repos.
- **Testing shape:** excellent breadth on the pure-Dart side (serializer,
  escaping, fuzz, sitemap/robots, route/island manifests, cache/ETag/304,
  redirects). The gap is **no real-browser test** for the JS runtime and L2
  islands - the exact area with the most novel risk. The repo itself notes the
  absence of Playwright. Adding even a minimal headless-browser smoke test for
  hydration would materially raise confidence.
- **`analysis_options.yaml`, `.gitattributes` (golden binary), TEMP ignoring,
  English-only convention:** all present and respected.

---

## 6. Prioritized recommendations

Must-do before a "production" / 1.0 claim:
1. Fix or remove the `Seo.section`/`Seo.list` semantic gap (3.1). This directly
   undercuts the core SEO promise on the Flutter surface.
2. Add a real-browser smoke test for L2 island hydration + the JS dispatcher +
   service worker. The most complex, least-verified code should not ship on
   Dart-string assertions alone.
3. Document (or lift) the cache-vs-bot-aware-transport exclusivity (3.2) and the
   service-worker cache-busting story (3.3).

Should-do:
4. Null-guard the vanilla `Carousel`/`CopyButton` and wrap the hydration
   bootstrap loop in `try/catch` so one bad island cannot abort the page (3.5).
5. Make `SsgCollector` fail loudly on post-seal writes / double meta (3.6).
6. Surface island factory errors in `IslandHost` (3.13).
7. Either use `DocumentBuilder`'s `data` param or drop it (3.8); add a cache
   byte budget (3.9).

Nice-to-have:
8. Reconcile naming (`props`/`state`), header casing, and the `Seo.text`
   heading overlap; remove the dead `RouteAdapter.navigateToForExtraction`
   (3.4) or implement it; empty-`SafeUrl` and UTC sitemap dates (3.11, 3.12).

---

## 7. Verdict

A tight, well-tested, security-conscious codebase addressing a real and current
problem, with clean architecture and enforced boundaries. The pure-Dart core
(`hydraline`, `hydraline_server`) is trustworthy and close to production. The
`hydraline_flutter` island layer is the ambitious, differentiating part - and
also the least proven; it needs real-browser validation and one genuine
semantic fix before the top-line "production-ready Flutter Web SEO" claim is
fully earned. No critical bugs or exploitable security holes were found; the
issues are a mix of one meaningful missing-feature (3.1), a few
advertised-vs-actual behavior gaps, and a normal tail of robustness edge cases.

**Grade: B+ (solid pre-1.0). Ready for L0/L1 use today; pilot L2 with browser
testing.**
