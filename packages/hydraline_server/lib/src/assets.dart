/// Static asset handlers and Flutter-asset injection
/// (ARCHITECTURE.md §10; S-9, S-10).
library;

import 'package:hydraline/hydraline.dart'
    show
        DocumentNode,
        DocumentRootNode,
        Robots,
        RobotsDirectives,
        RobotsRule,
        RouteEntry,
        RouteMode,
        SeoMeta,
        UnsafeHtmlNode;
import 'package:shelf/shelf.dart';

/// Asset endpoints and Flutter-asset inlining.
abstract final class Assets {
  /// Serves `robots.txt` and `sitemap.xml` + L0-L1 core assets
  /// (vanilla JS, self-hosted HTMX) (S-9).
  static Handler serveCoreAssets() => (Request request) {
    final path = request.url.path;
    if (path == 'robots.txt') {
      return Response.ok(
        Robots.generate(rules: [RobotsRule(userAgent: '*')]),
        headers: {'Content-Type': 'text/plain; charset=utf-8'},
      );
    }
    if (path == 'sitemap.xml') {
      return Response.notFound('sitemap not configured');
    }
    return Response.notFound('');
  };

  /// Injects Flutter-asset `<script>` tags (pointing at the Flutter Web SDK
  /// entry-points) into [root] before `</body>`. Uses [baseHref] so paths
  /// are always absolute regardless of the current route (S-10).
  /// Only for routes that have `IslandType.flutter` islands.
  static DocumentNode injectFlutterAssets(
    DocumentNode root, {
    String baseHref = '/',
  }) {
    if (root is! DocumentRootNode) {
      return root;
    }
    final base = baseHref.endsWith('/') ? baseHref : '$baseHref/';
    final scripts = <DocumentNode>[
      UnsafeHtmlNode(
        '<script src="${base}flutter_bootstrap.js" defer></script>',
      ),
      UnsafeHtmlNode(
        '<script src="${base}main.dart.js" type="module" defer></script>',
      ),
    ];
    return DocumentRootNode(
      head: root.head,
      body: [...root.body, ...scripts],
      lang: root.lang,
    );
  }
}

/// Generates the default [SeoMeta] for a route when no explicit metadata
/// is configured in the manifest (P2-11).
///
/// - `app` routes default to `noindex` and are excluded from sitemap (§4.1).
/// - `document`/`hybrid` routes have no robots restrictions by default.
SeoMeta defaultMetadataForRoute(RouteEntry route) {
  final noindex = route.mode == RouteMode.app;
  return SeoMeta(
    title: route.path,
    robots: RobotsDirectives(noindex: noindex || (route.noindex ?? false)),
  );
}
