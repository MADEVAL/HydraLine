// Hydraline server example: a working shelf server with SSR, streaming,
// bot-aware delivery, caching and an HTMX fragment endpoint.
//
// Run with: dart run example/main.dart
// Then:     curl -N http://localhost:8080/            (chunked streaming)
//           curl -A Googlebot http://localhost:8080/  (buffered, same bytes)
//           curl http://localhost:8080/api/faq        (HTMX fragment)
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// ── Builders (UA-blind: no User-Agent parameter, no cloaking) ──────────────

DocumentNode buildHome(Request request, Object? data) => DocumentRootNode(
  lang: 'en',
  head: buildHead(
    const SeoMeta(
      title: 'Hydraline SSR demo',
      description: 'Server-rendered semantic HTML for Flutter Web.',
    ),
  ),
  body: [
    SectionNode(
      role: SectionRole.main,
      children: [
        const HeadingNode(level: 1, children: [TextNode('Hello from SSR')]),
        const ParagraphNode(
          children: [TextNode('This page is rendered on a Dart server.')],
        ),
        const HtmxIslandNode(
          id: 'faq',
          endpoint: '/api/faq',
          fallback: [
            ParagraphNode(children: [TextNode('Loading FAQ…')]),
          ],
        ),
      ],
    ),
  ],
);

DocumentNode buildProduct(Request request, Object? data) {
  final id = request.url.pathSegments.last;
  return DocumentRootNode(
    head: buildHead(SeoMeta(title: 'Product $id')),
    body: [
      HeadingNode(level: 1, children: [TextNode('Product $id')]),
      const IslandPlaceholderNode(
        id: 'calculator',
        directive: HydrationDirective.onVisible,
        size: IslandSize(width: 640, height: 480),
        state: {'price': 249},
      ),
    ],
  );
}

// ── HTMX endpoint: responds with an HTML fragment, no <html>/<head> ────────

Response faqEndpoint(Request request) {
  const fragment = SectionNode(
    role: SectionRole.section,
    children: [
      DetailsNode(
        summary: SummaryNode(children: [TextNode('What is Hydraline?')]),
        children: [
          ParagraphNode(
            children: [TextNode('SEO / SSR / islands for Flutter Web.')],
          ),
        ],
      ),
      DetailsNode(
        summary: SummaryNode(children: [TextNode('Is it a framework?')]),
        children: [
          ParagraphNode(children: [TextNode('No - a set of libraries.')]),
        ],
      ),
    ],
  );
  return Htmx.response(
    const HtmlSerializer().serializeFragment(fragment),
    triggers: {'faq-loaded': 'ok'},
  );
}

Future<void> main() async {
  final manifest = RouteManifest.builder()
      .route(const RouteEntry(path: '/', mode: RouteMode.document))
      .route(const RouteEntry(path: '/product/:id', mode: RouteMode.hybrid))
      .route(const RouteEntry(path: '/app/dashboard', mode: RouteMode.app))
      .build();

  final config = HydralineConfig(
    manifest: manifest,
    builders: {'/': buildHome, '/product/:id': buildProduct},
    // Transport-only bot detection: bots get buffered delivery, users get
    // chunked streaming - the body bytes are identical either way.
    botUserAgentPattern: RegExp(
      r'Googlebot|bingbot|Twitterbot|facebookexternalhit',
    ),
    cache: HydralineCache.inMemory(maxSize: 100),
    cacheTtl: const Duration(minutes: 5),
  );

  final handler = const Pipeline()
      .addMiddleware(hydralineMiddleware(config))
      .addHandler((request) {
        // Non-manifest endpoints (HTMX fragments, APIs) are matched here via
        // an `app` route or a dedicated cascade in front of the middleware.
        return Response.ok('app shell');
      });

  final assets = Assets.serveCoreAssets();
  final server = await io.serve(
    (Request request) {
      final path = request.url.path;
      if (path == 'api/faq') return faqEndpoint(request);
      if (path == 'robots.txt' ||
          path == 'sitemap.xml' ||
          path.endsWith('.js')) {
        return assets(request);
      }
      return handler(request);
    },
    'localhost',
    8080,
  );

  // ignore: avoid_print
  print('Serving on http://${server.address.host}:${server.port}');
}
