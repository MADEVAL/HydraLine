## Documentation Index

- [Getting Started](./getting-started.md) - installation, prerequisites, concepts, adding SEO to an existing app
- [Architecture](./architecture.md) - project structure, subsystems, data flows, dependency rules
- [Document Model](./document-model.md) - DocumentNode hierarchy, all node types, metadata, escaping
- [Server](./server.md) - shelf/Dart Frog setup, SSR, streaming, HTMX, caching, bot-aware delivery
- [Flutter Widgets](./flutter-widgets.md) - Seo.* widgets, Island, HydraApp, IslandHost, SSG runner
- [Configuration](./configuration.md) - route manifest, island manifest, SEO config, budgets
- [Security](./security.md) - SafeUrl, contextual escaping, CSP, XSS prevention, sanitizer, SRI, cloaking guarantee
- [Showcase example](../example/README.md) - runnable full-stack demo (SSR + SSG + Flutter)

## What Hydraline Is Not

Hydraline is **not a framework**. It doesn't own `main()`, doesn't dictate which
router you use, doesn't replace `MaterialApp`. It doesn't automatically convert
arbitrary Flutter widgets to HTML. It doesn't execute Flutter widgets on the
server. It's a set of libraries you plug into an existing project - additively,
one route at a time.

## Proven

- **486 unit/widget tests** (hydraline 229, server 107, flutter 140, example 14)
- **26 Playwright e2e tests** in real Chrome: all hydration directives, vanilla
  islands (accordion/tabs/carousel/theme/lazy/copy), failure paths, re-wire guard
- **Real-engine e2e tests** (`melos run e2e:engine`): flutter build web + SSG
  overlay → Chrome verifies genuine Flutter engine hydration, interactivity via
  semantics tree, service worker caching, CLS < 0.01, zero-overhead document pages
- **Server-level SSR invariants**: byte-identical bot/human bodies, ETag/304,
  HEAD, cache-key normalisation - all CI-gated
- **1e6-input XSS fuzz**: escapeHtmlText, escapeHtmlAttribute, SafeUrl allowlist
- **Single-pass serializer**: O(nodes + text), 10k paragraphs in 29 ms (16.7 MB/s)
