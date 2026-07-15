# Changelog

All notable changes to the Hydraline monorepo. Per-package details live in
each package's own changelog:
[hydraline](packages/hydraline/CHANGELOG.md) ·
[hydraline_server](packages/hydraline_server/CHANGELOG.md) ·
[hydraline_flutter](packages/hydraline_flutter/CHANGELOG.md).

## Unreleased

- E2E expansion: directive coverage (`onVisible`/`onIdle`/`onMedia` +
  multi-island), a vanilla-islands (L1) suite in real Chrome, and a
  real-engine project (`melos run e2e:engine`) that builds the example with
  `flutter build web`, overlays the SSG output and verifies actual island
  hydration, interactivity (via the engine semantics tree) and the
  zero-overhead guarantee for document pages.
- `hydraline` - `web/` mirrors for `vanilla-islands.js`/`htmx-glue.js`
  (byte-identity locked by test); accordion guards a `details` without a
  `summary`.
- Example - hybrid pages now wire the island runtime scripts and a
  `<base href="/">` so nested SSG pages resolve the engine bundle.

## 0.0.4

Pre-production review follow-up: every confirmed finding from `REVIEW.md`
fixed and regression-tested (see per-package changelogs).

- `hydraline` - nested semantic sectioning in `SsgCollector`; `SafeUrl` rejects
  empty input; sitemap `lastmod` in UTC; hardened vanilla island runtime.
- `hydraline_server` - HEAD support; `DocumentBuilder` receives the matched
  route; cache byte cap; HTMX CRLF header validation; escaped Flutter-asset
  injection; unified redirects.
- `hydraline_flutter` - `Seo.section`/`Seo.list` emit real structure;
  `RouteAdapter.navigateToForExtraction` implemented; `IslandHost` error
  fallback; stale-while-revalidate service worker; dispatcher parks the
  bootstrap promise so engine failures never surface as unhandled rejections.
- Tooling - Playwright e2e harness in `e2e/` (`melos run e2e`, CI job): the
  shipped island runtime JS is exercised in real Chrome with a mocked Flutter
  engine (hydration directives, failure path, dehydrate, DSD, anti-CLS sizing,
  virtual views).

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
