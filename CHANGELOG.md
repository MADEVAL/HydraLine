# Changelog

All notable changes to the Hydraline monorepo. Per-package details live in
each package's own changelog:
[hydraline](packages/hydraline/CHANGELOG.md) ·
[hydraline_server](packages/hydraline_server/CHANGELOG.md) ·
[hydraline_flutter](packages/hydraline_flutter/CHANGELOG.md).

## 0.0.3

Second-pass review polish - every remaining finding from the follow-up review
fixed and regression-tested.

- `hydraline` - `RouteManifestBuilder.version/baseUrl` setters; island
  `data-state` validated via `IslandStateCodec`; `VanillaIslandNode.config`
  serialized as `data-config`; sitemap `'` escaped as `&#39;`; `issue_tracker`
  metadata.
- `hydraline_server` - trailing-slash route patterns match; `Http.redirect`
  preserves 303/307/308; app routes emit `nofollow`; cache key normalises
  query order; explicit 64-bit ETag mask; dead `delivery` parameter removed.
- `hydraline_flutter` - `Seo.image` skips the network fetch during SSG
  extraction; `SsgRunner`/`runSsgCli` adapter is optional; island runtime JS
  written only for actual flutter islands; `dehydrate` simplified.

## 0.0.2

- `hydraline_server` - dynamic-route builders are now invoked (pattern-keyed
  lookup), cache keys include the query string, request paths are
  canonicalised, 64-bit ETag with RFC 9110 `If-None-Match` handling,
  `Vary` header, cache API cleanup.
- `hydraline` - strict island spec validation, XML attribute escaping in
  sitemaps, robots.txt line-break validation, `data-size` island attribute,
  `RouteManifest.baseUrl`, audit CLI timeouts + non-2xx failures,
  dead `SerializerOptions` removed.
- `hydraline_flutter` - `Island` gained `kind`/`endpoint`, `Seo.link`
  navigates and exposes link semantics, `Seo.image` renders an image,
  multi-segment dynamic route expansion, sitemap uses the manifest
  `base_url`, runtime JS fixes (DSD fallback adoption, `:host` sizing,
  dehydrate race guard, re-wire guard), new pure-Dart
  `package:hydraline_flutter/build.dart` surface.
- Example - shared pure-Dart content builders feed both SSR and SSG;
  `dart run hydraline_example:build` emits full, audit-clean pages.
- Tooling - boundary scanner catches conditional import URIs; `melos run
  precommit` now includes the end-to-end SSG audit.

## 0.0.1

- Initial release
- `hydraline` - pure-Dart core: DocumentNode model, HTML serializer,
  SafeUrl escaping, SEO metadata, JSON-LD, sitemap, robots,
  route/island manifests, audit CLI, L0-L1 web assets
- `hydraline_server` - pure-Dart server: shelf/Dart Frog middleware,
  SSR streaming, bot-aware delivery, caching with ETag/304, automatic
  X-Robots-Tag, HTMX helpers, asset serving
- `hydraline_flutter` - Flutter package: Seo.* widgets, Island,
  HydraApp, IslandHost + IslandViewRegistry, SSG runner + CLI,
  DevTools, web runtime assets
