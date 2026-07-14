# Changelog

All notable changes to the Hydraline monorepo. Per-package details live in
each package's own changelog:
[hydraline](packages/hydraline/CHANGELOG.md) ·
[hydraline_server](packages/hydraline_server/CHANGELOG.md) ·
[hydraline_flutter](packages/hydraline_flutter/CHANGELOG.md).

## 0.0.1

- Initial release
- `hydraline` — pure-Dart core: DocumentNode model, HTML serializer,
  SafeUrl escaping, SEO metadata, JSON-LD, sitemap, robots,
  route/island manifests, audit CLI, L0–L1 web assets
- `hydraline_server` — pure-Dart server: shelf/Dart Frog middleware,
  SSR streaming, bot-aware delivery, caching with ETag/304, automatic
  X-Robots-Tag, HTMX helpers, asset serving
- `hydraline_flutter` — Flutter package: Seo.* widgets, Island,
  HydraApp, IslandHost + IslandViewRegistry, SSG runner + CLI,
  DevTools, web runtime assets
