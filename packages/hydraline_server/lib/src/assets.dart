/// Static asset handlers and Flutter-asset injection.
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
        UnsafeHtmlNode,
        htmxGlueJs,
        vanillaIslandsJs;
import 'package:shelf/shelf.dart';

/// Asset endpoints and Flutter-asset inlining.
abstract final class Assets {
  /// Serves `robots.txt`, `sitemap.xml` and the L0–L1 core JS assets
  /// (`vanilla-islands.js`, `htmx-glue.js`) — first-party, CSP-compatible.
  ///
  /// [sitemapXml] and [robotsTxt] override the served content; without a
  /// [sitemapXml] the `sitemap.xml` endpoint responds 404.
  static Handler serveCoreAssets({String? sitemapXml, String? robotsTxt}) =>
      (Request request) {
        var path = request.url.path;
        const prefix = 'assets/hydraline/';
        if (path.startsWith(prefix)) {
          path = path.substring(prefix.length);
        }
        switch (path) {
          case 'robots.txt':
            return Response.ok(
              robotsTxt ?? Robots.generate(rules: [RobotsRule(userAgent: '*')]),
              headers: {'Content-Type': 'text/plain; charset=utf-8'},
            );
          case 'sitemap.xml':
            if (sitemapXml == null) {
              return Response.notFound('sitemap not configured');
            }
            return Response.ok(
              sitemapXml,
              headers: {'Content-Type': 'application/xml; charset=utf-8'},
            );
          case 'vanilla-islands.js':
            return Response.ok(
              vanillaIslandsJs,
              headers: {'Content-Type': 'text/javascript; charset=utf-8'},
            );
          case 'htmx-glue.js':
            return Response.ok(
              htmxGlueJs,
              headers: {'Content-Type': 'text/javascript; charset=utf-8'},
            );
          default:
            return Response.notFound('');
        }
      };

  /// Injects Flutter-asset `<script>` tags (pointing at the Flutter Web SDK
  /// entry-points) into [root] before `</body>`. Uses [baseHref] so paths
  /// are always absolute regardless of the current route.
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
/// is configured in the manifest.
///
/// - `app` routes default to `noindex` and are excluded from the sitemap.
/// - `document`/`hybrid` routes have no robots restrictions by default.
SeoMeta defaultMetadataForRoute(RouteEntry route) {
  final noindex = route.mode == RouteMode.app;
  return SeoMeta(
    title: route.path,
    robots: RobotsDirectives(noindex: noindex || (route.noindex ?? false)),
  );
}
