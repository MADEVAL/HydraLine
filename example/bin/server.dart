// Hydraline showcase - the SSR server (pure Dart, no Flutter).
//
// Run with: dart run bin/server.dart
// Try:      curl -N http://localhost:8080/                (chunked streaming)
//           curl -A Googlebot http://localhost:8080/      (buffered, same bytes)
//           curl http://localhost:8080/product/espresso   (hybrid page)
//           curl http://localhost:8080/robots.txt
//
// Page content lives in lib/content.dart - the same pure-Dart builders feed
// the static build (bin/build.dart).
import 'dart:io';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_example/content.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final manifestYaml = await File('hydraline.routes.yaml').readAsString();

  final config = HydralineConfig(
    manifest: RouteManifest.parseYaml(manifestYaml),
    builders: {
      '/': (request, data) => homePage(),
      '/product/:id': (request, data) =>
          productPage(request.url.pathSegments.last),
    },
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
