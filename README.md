<div align="center">

```
    __  __          __           __    _          
   / / / /_  ______/ /________ _/ /   (_)___  ___ 
  / /_/ / / / / __  / ___/ __ `/ /   / / __ \/ _ \
 / __  / /_/ / /_/ / /  / /_/ / /___/ / / / /  __/
/_/ /_/\__, /\__,_/_/   \__,_/_____/_/_/ /_/\___/ 
      /____/                                      
```

**Real, crawlable HTML for Flutter Web - without giving up Flutter.**

SEO · SSR · SSG · Islands

[Quick Start](#quick-start) · [How It Works](#how-it-works) · [Docs](docs/) · [Showcase](example/) · [Contributing](CONTRIBUTING.md)

</div>

---

Flutter Web paints your app into a `<canvas>`. Crawlers and social bots see an
empty shell: no title, no description, no preview card, no content. Runtime
meta-tag injectors don't survive `view-source`, and UA-sniffing prerender
hacks are cloaking.

**Hydraline fixes this at the root: your pages become real semantic HTML in
the very first HTTP response - and Flutter hydrates interactive islands on
top.** No new framework. No rewrite. One route at a time.

## Why Hydraline

- **Real HTML, first response.** Headings, paragraphs, images with `alt`,
  `og:*`/`twitter:*` tags, JSON-LD - all present in `view-source`, no
  JavaScript required.
- **Three interactivity levels.** Static HTML (no JS) → vanilla + HTMX
  islands (~8-14 KB, no Flutter engine) → full Flutter islands (engine loads
  only when an island actually triggers). ~80% of content-page interactivity
  never needs the engine at all.
- **Zero cloaking, by architecture.** Content builders physically cannot see
  the `User-Agent` - bots and users get byte-identical bodies, only the
  transport differs (buffered vs streamed). Verifiable with one CLI command.
- **Safe by the type system.** All text is contextually escaped; URLs must
  pass the `SafeUrl` scheme allowlist (`javascript:`/`data:` rejected at
  construction - no node can hold an unchecked URL); raw HTML requires an
  explicit `UnsafeHtmlNode` opt-in. Backed by a million-input XSS fuzz suite.
- **Zero layout shift.** Islands reserve exact pixel dimensions with
  Declarative Shadow DOM skeletons - CLS ≈ 0.
- **SSR and SSG from one model.** The same `DocumentNode` tree streams from a
  shelf/Dart Frog server or compiles to a static `dist/` for any hosting.
- **SEO toolchain included.** sitemap.xml (auto-split at 50k URLs),
  robots.txt, hreflang, canonical, JSON-LD builders, and a CI-ready audit CLI.
- **Not a framework.** Doesn't own `main()`, doesn't replace `MaterialApp`,
  doesn't dictate a router. Plug it into an existing app additively.

## Quick Start

```yaml
# pubspec.yaml
dependencies:
  hydraline: ^0.0.4           # core - pure Dart
  hydraline_server: ^0.0.4    # SSR - pure Dart (shelf / Dart Frog)
  hydraline_flutter: ^0.0.4   # widgets + SSG + web runtime
```

Build a page in pure Dart:

```dart
import 'package:hydraline/hydraline.dart';

final page = DocumentRootNode(
  head: buildHead(SeoMeta(
    title: 'Espresso Machine - Barista Shop',
    description: 'Compact 15-bar espresso machine.',
    openGraph: OpenGraph(type: 'product',
      image: SafeUrl.parse('https://shop.example/og.jpg')),
  )),
  body: [
    HeadingNode(level: 1, children: [TextNode('Espresso Machine')]),
    ParagraphNode(children: [TextNode('Real HTML. Real rankings.')]),
    IslandPlaceholderNode(               // Flutter hydrates this on scroll
      id: 'calculator',
      directive: HydrationDirective.onVisible,
      size: IslandSize(width: 640, height: 320),
      state: {'price': 249},
    ),
  ],
);
```

Serve it (streaming SSR, bot-aware, cached):

```dart
import 'package:hydraline_server/hydraline_server.dart';

final handler = const Pipeline()
    .addMiddleware(hydralineMiddleware(HydralineConfig(
      manifest: manifest,
      builders: {'/': (req, data) => page},
      botUserAgentPattern: RegExp(r'Googlebot|bingbot'),
      cache: HydralineCache.inMemory(),
    )))
    .addHandler((req) => Response.ok('app shell'));
```

Or ship it static - a tiny `bin/build.dart` registers the same builders for
the SSG pipeline (full version: [example/bin/build.dart](example/bin/build.dart)):

```dart
import 'package:hydraline_flutter/build.dart'; // pure-Dart build surface

void main(List<String> args) async {
  await runSsgCli(
    manifestPath: 'hydraline.routes.yaml',
    outputDir: 'dist',
    islandFactories: {'calculator': IslandType.flutter},
    builders: {'/': (path) => page},
  );
}
```

```bash
dart run your_app:build
# dist/: HTML pages + sitemap.xml + robots.txt - ready for any static host.
# (dart run hydraline_flutter:build <manifest> <dist> renders metadata-only
#  shells when you have no builders yet.)
```

And prove there's no cloaking:

```bash
dart run hydraline:audit --server-integration https://your-site.example
```

**Full walkthrough:** [Getting Started](docs/getting-started.md) ·
**Runnable demo:** [example/](example/README.md)

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

An **island** is an isolated interactive zone with a hydration directive
(`onVisible`, `onIdle`, `onInteraction`, `onMedia`, `manual`). Props cross the
server → client boundary as JSON in `data-state`; one Flutter engine instance
hosts N islands in N views. Pages without Flutter islands never load the
engine - that's the zero-overhead guarantee.

Deep dive: [Architecture](docs/architecture.md).

## Packages

| Package | Purpose | Flutter? |
|---|---|---|
| [`hydraline`](packages/hydraline/) | DocumentNode model, HTML serializer, escaping/SafeUrl, SEO metadata, JSON-LD, sitemap/robots, audit CLI | no |
| [`hydraline_server`](packages/hydraline_server/) | shelf/Dart Frog middleware, streaming SSR, bot-aware delivery, caching + ETag, HTMX helpers | no |
| [`hydraline_flutter`](packages/hydraline_flutter/) | `Seo.*` widgets, `Island`, `HydraApp`, `IslandHost`, SSG runner + CLI, L2 web runtime | yes |

## Documentation

Everything lives in [`docs/`](docs/):
[Getting Started](docs/getting-started.md) ·
[Architecture](docs/architecture.md) ·
[Document Model](docs/document-model.md) ·
[Server](docs/server.md) ·
[Flutter Widgets](docs/flutter-widgets.md) ·
[Configuration](docs/configuration.md) ·
[Security](docs/security.md)

## Requirements

Dart ≥ 3.9 · Flutter ≥ 3.35 (only for `hydraline_flutter`) · MIT licensed.

## Community

- **Contribute** - see the [Contributing Guide](CONTRIBUTING.md) and the
  [PR template](.github/PULL_REQUEST_TEMPLATE/pull_request_template.md)
- **Found a bug?** - open a [bug report](.github/ISSUE_TEMPLATE/bug_report.md)
- **Have an idea?** - open a [feature request](.github/ISSUE_TEMPLATE/feature_request.md)
- **Security issue?** - follow the [Security Policy](SECURITY.md) (private advisory, please)
- **Be kind** - we follow the [Code of Conduct](CODE_OF_CONDUCT.md)

## License

[MIT](LICENSE) - [Yevhen Leonidov](https://leonidov.dev) / [Globus Studio](https://globus.studio)
