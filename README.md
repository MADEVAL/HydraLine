<div align="center">

```
    __  __          __           __    _          
   / / / /_  ______/ /________ _/ /   (_)___  ___ 
  / /_/ / / / / __  / ___/ __ `/ /   / / __ \/ _ \
 / __  / /_/ / /_/ / /  / /_/ / /___/ / / / /  __/
/_/ /_/\__, /\__,_/_/   \__,_/_____/_/_/ /_/\___/ 
      /____/                                      
```

**Real, crawlable HTML for Flutter Web. No rewrite. One route at a time.**

[![tests](https://img.shields.io/badge/tests-486%20passed-brightgreen)](#)
[![e2e](https://img.shields.io/badge/e2e-Chrome%2026%20passed-brightgreen)](#)
[![CLS](https://img.shields.io/badge/CLS-≈%200-blue)](#)
[![XSS](https://img.shields.io/badge/XSS%20fuzz-1e6%20inputs%20passed-brightgreen)](#)

SEO · SSR · SSG · Islands

[Docs](docs/) · [Quick Start](#quick-start) · [Showcase](example/) · [vs. Alternatives](#vs-alternatives)

</div>

---

Flutter Web paints your app into a `<canvas>`. Crawlers and social bots see an
empty shell. **Hydraline fixes this at the root: your pages become real semantic
HTML in the very first HTTP response** — and Flutter hydrates interactive islands
on top. No new framework. No rewrite. **Works with ANY existing Flutter Web app
— additively, one route at a time.**

## vs. Alternatives

| Approach | Crawlable? | No Cloaking? | Islands? |
|---|---|---|---|
| **Hydraline** | Real HTML in `view-source` | Builders can't see `User-Agent` | L0/L1/L2 per route |
| Runtime `<meta>` injectors | No — JS-only, `view-source` is empty | Yes, but tags don't survive | No |
| UA-sniff prerender | Yes | **No** — different content per UA (risk) | No |
| Next.js / Nuxt (rewrite) | Yes | Yes | Needed, but **new framework** |

## Why Hydraline

- **Additive, not replacement.** Doesn't own `main()`, doesn't replace
  `MaterialApp`, doesn't dictate a router. Add SEO to one route, then another.
  Your existing Flutter code never changes.
- **Three interactivity levels per page.** L0: static HTML (no JS). L1: vanilla
  + HTMX islands (~8-14 KB, no Flutter engine). L2: full Flutter islands
  (engine loads only when an island triggers). ~80% of content interactivity
  never needs the engine.
- **Zero cloaking, by architecture.** Builders physically cannot see the
  `User-Agent` — bots and users get byte-identical bodies. Verified by CI test.
- **Zero layout shift.** Islands reserve exact pixel dimensions with Declarative
  Shadow DOM — CLS ≈ 0. Verified by CI test in real Chrome.
- **Safe by construction.** `SafeUrl` rejects `javascript:`/`data:` at type
  level; context-aware escaping (text vs attribute); inline event handlers get
  auto-stripped by `sanitizeHtml()`. SRI (`integrity`/`crossorigin`) on runtime
  scripts. Backed by a 1e6-input XSS fuzz suite.
- **SEO toolchain included.** Sitemap (auto-split at 50k URLs), robots.txt,
  canonical, hreflang, 9 JSON-LD types, audit CLI. Full Open Graph and Twitter
  Card with image dimensions.
- **SSR + SSG from one model.** The same `DocumentNode` tree streams from a
  shelf/Dart Frog server or compiles to a static `dist/` for any hosting.
- **Proven.** 486 unit/widget tests, 26 Playwright e2e tests in real Chrome
  (including genuine Flutter engine hydration), server-level SSR invariants,
  and a CI-ready SEO audit.

## Install

**You almost never need all three packages.** Pick based on what you're building:

| You want to... | Add this | |
|---|---|---|
| Build static HTML pages (SSG) with pure Dart | `hydraline` + `hydraline_flutter` | [![pub](https://img.shields.io/pub/v/hydraline)](https://pub.dev/packages/hydraline) [![pub](https://img.shields.io/pub/v/hydraline_flutter)](https://pub.dev/packages/hydraline_flutter) |
| Serve pages with SSR (shelf / Dart Frog) | `hydraline` + `hydraline_server` | [![pub](https://img.shields.io/pub/v/hydraline)](https://pub.dev/packages/hydraline) [![pub](https://img.shields.io/pub/v/hydraline_server)](https://pub.dev/packages/hydraline_server) |
| Full stack (SSR + SSG + Flutter widgets) | All three | |
| Only need the SEO data model (serializer, sitemap, audit) | `hydraline` only | |

```bash
dart pub add hydraline              # always needed
dart pub add hydraline_server       # for SSR / HTMX
flutter pub add hydraline_flutter   # for widgets / SSG / islands
```

`hydraline_flutter` re-exports the entire `hydraline` core — one import, full API:

```dart
import 'package:hydraline_flutter/hydraline_flutter.dart'; // everything
import 'package:hydraline/hydraline.dart';                  // core only
import 'package:hydraline_server/hydraline_server.dart';    // server
```

## Quick Start

### Option A — Pure-Dart builders (no Flutter widget changes)

```dart
import 'package:hydraline/hydraline.dart';

final page = DocumentRootNode(
  head: buildHead(SeoMeta(
    title: 'Espresso Machine',
    description: 'Compact 15-bar espresso machine.',
    openGraph: OpenGraph(type: 'product',
      image: SafeUrl.parse('https://shop.example/og.jpg')),
  )),
  body: [
    HeadingNode(level: 1, children: [TextNode('Espresso Machine')]),
    ParagraphNode(children: [TextNode('Real HTML. Real rankings.')]),
    IslandPlaceholderNode(
      id: 'calculator',
      directive: HydrationDirective.onVisible,
      size: IslandSize(width: 640, height: 320),
      state: {'price': 249},
    ),
    // One-liner for the island runtime scripts + engine config:
    ...islandRuntime(),
  ],
);
```

Serve it (streaming SSR, cached, ETag/304):

```dart
import 'package:hydraline_server/hydraline_server.dart';

final handler = const Pipeline()
    .addMiddleware(hydralineMiddleware(HydralineConfig(
      manifest: manifest,
      builders: {'/': (req, data) => page},
      botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
      cache: HydralineCache.inMemory(),
    )))
    .addHandler((req) => Response.ok('app shell')); // your existing Flutter Web
```

### Option B — Seo.* widgets (Flutter-native DX)

```dart
import 'package:hydraline_flutter/hydraline_flutter.dart';

// Inside your existing widget tree:
HydraApp(
  child: Column(children: [
    Seo.head(SeoMeta(title: 'Product')),
    Seo.heading('Espresso Machine', level: 1),
    Seo.text('Rich crema, perfect extraction.'),
    Seo.image('/img/espresso.jpg', alt: 'Espresso machine'),
    Seo.section(role: SectionRole.main, children: [...more widgets...]),
    Island(id: 'calculator', type: IslandType.flutter,
        props: {'price': 249}, width: 640, height: 480),
  ]),
)
```

Both options produce **identical semantic HTML**. Pick the one that fits your
workflow. Full walkthrough: [Getting Started](docs/getting-started.md).

## How It Works

```
Route modes (coexist in one app)
────────────────────────────────
app        CanvasKit as today          dashboards, editors
document   pure semantic HTML          blog, docs, landings
hybrid     HTML + Flutter islands      product page + calculator

Interactivity levels
────────────────────
L0  static HTML             0 KB JS      <details>, :target, loading=lazy
L1  vanilla + HTMX          ~8-14 KB     tabs, forms, search - no engine
L2  Flutter islands         on trigger   charts, configurators, 3D
```

An **island** is an isolated interactive zone. Props cross the server → client
boundary as JSON in `data-state`. One Flutter engine instance hosts N islands in
N views via the multi-view API. Pages without islands never load the engine —
that's the zero-overhead guarantee. Deep dive: [Architecture](docs/architecture.md).

## Packages

| Package | [pub.dev](https://pub.dev) | Purpose |
|---|---|---|
| `hydraline` | [![pub](https://img.shields.io/pub/v/hydraline)](https://pub.dev/packages/hydraline) | Pure-Dart core: DocumentNode, HTML serializer, SafeUrl, sanitizer, SEO metadata, JSON-LD (9 types), sitemap/robots, audit CLI, islandRuntime() |
| `hydraline_server` | [![pub](https://img.shields.io/pub/v/hydraline_server)](https://pub.dev/packages/hydraline_server) | Pure-Dart server: shelf/Dart Frog middleware, streaming SSR, bot-aware delivery, caching + ETag/304, HTMX helpers |
| `hydraline_flutter` | [![pub](https://img.shields.io/pub/v/hydraline_flutter)](https://pub.dev/packages/hydraline_flutter) | Flutter: `Seo.*` widgets, `Island`, `HydraApp`, `IslandHost`, SSG runner + CLI, L2 web runtime (Custom Element, dispatcher, SW) |

Package READMEs: [`hydraline`](packages/hydraline/) · [`hydraline_server`](packages/hydraline_server/) · [`hydraline_flutter`](packages/hydraline_flutter/)

## Requirements

Dart ≥ 3.9 · Flutter ≥ 3.35 (only for `hydraline_flutter`) · MIT licensed.

## Community

- **Contribute** — [Contributing Guide](CONTRIBUTING.md)
- **Bug?** — [bug report](.github/ISSUE_TEMPLATE/bug_report.md)
- **Idea?** — [feature request](.github/ISSUE_TEMPLATE/feature_request.md)
- **Security issue?** — follow [Security Policy](SECURITY.md)
- **Be kind** — [Code of Conduct](CODE_OF_CONDUCT.md)

## License

[MIT](LICENSE) — [Yevhen Leonidov](https://leonidov.dev) / [Globus Studio](https://globus.studio)
