// Hydraline showcase — the SSR server (pure Dart, no Flutter).
//
// Run with: dart run bin/server.dart
// Try:      curl -N http://localhost:8080/                (chunked streaming)
//           curl -A Googlebot http://localhost:8080/      (buffered, same bytes)
//           curl http://localhost:8080/product/espresso   (hybrid page)
//           curl http://localhost:8080/robots.txt
import 'dart:io';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

DocumentNode buildHome(Request request, Object? data) => DocumentRootNode(
  lang: 'en',
  head: buildHead(
    const SeoMeta(
      title: 'Hydraline Demo Shop',
      description: 'A Flutter Web shop with real, crawlable HTML.',
    ),
  ),
  body: [
    SectionNode(
      role: SectionRole.main,
      children: [
        const HeadingNode(
          level: 1,
          children: [TextNode('Hydraline Demo Shop')],
        ),
        const ParagraphNode(
          children: [
            TextNode('Static HTML loads instantly; islands hydrate on demand.'),
          ],
        ),
        AnchorNode(
          href: SafeUrl.parse('/product/espresso'),
          children: const [TextNode('Espresso')],
        ),
      ],
    ),
  ],
);

DocumentNode buildProduct(Request request, Object? data) {
  final id = request.url.pathSegments.last;
  return DocumentRootNode(
    lang: 'en',
    head: buildHead(
      SeoMeta(title: 'Product — $id'),
      structuredData: [JsonLd.product(name: id, price: 249, currency: 'EUR')],
    ),
    body: [
      HeadingNode(level: 1, children: [TextNode('Product: $id')]),
      IslandPlaceholderNode(
        id: 'calculator-$id',
        directive: HydrationDirective.onVisible,
        size: const IslandSize(width: 640, height: 320),
        state: const {'price': 249},
      ),
    ],
  );
}

Future<void> main() async {
  final manifestYaml = await File('hydraline.routes.yaml').readAsString();

  final config = HydralineConfig(
    manifest: RouteManifest.parseYaml(manifestYaml),
    builders: {'/': buildHome, '/product/:id': buildProduct},
    botUserAgentPattern: RegExp(r'Googlebot|bingbot|Twitterbot'),
    cache: HydralineCache.inMemory(maxSize: 100),
    cacheTtl: const Duration(minutes: 5),
  );

  final pages = const Pipeline()
      .addMiddleware(hydralineMiddleware(config))
      .addHandler((request) => Response.ok('flutter app shell'));

  final assets = Assets.serveCoreAssets();

  final server = await io.serve(
    (Request request) {
      final path = request.url.path;
      if (path == 'robots.txt' ||
          path == 'sitemap.xml' ||
          path.endsWith('.js')) {
        return assets(request);
      }
      return pages(request);
    },
    'localhost',
    8080,
  );

  stdout.writeln('Serving on http://${server.address.host}:${server.port}');
}
