import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  group('InMemoryCache (P2-06/S-8)', () {
    test('stores and retrieves an entry', () async {
      final cache = InMemoryCache();
      await cache.set('k', 'v');
      expect(await cache.get('k'), 'v');
    });

    test('returns null on miss', () async {
      final cache = InMemoryCache();
      expect(await cache.get('nonexistent'), isNull);
    });
  });

  group('Assets (P2-08/S-9)', () {
    test('robots.txt endpoint returns 200', () async {
      final handler = Assets.serveCoreAssets();
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/robots.txt')),
      );
      expect(response.statusCode, 200);
      final body = await bodyOf(response);
      expect(body, contains('User-agent'));
    });

    test(
      'sitemap.xml returns 404 when no source configured (graceful)',
      () async {
        final handler = Assets.serveCoreAssets();
        final response = await handler(
          Request('GET', Uri.parse('http://localhost/sitemap.xml')),
        );
        expect(response.statusCode, 404);
      },
    );
  });

  group('injectFlutterAssets (P2-09/S-10)', () {
    test('injects flutter bundle scripts after </body>', () {
      var root = DocumentRootNode(
        body: [
          ParagraphNode(children: [TextNode('x')]),
        ],
      );
      root = Assets.injectFlutterAssets(root) as DocumentRootNode;
      final html = const HtmlSerializer().serialize(root);
      expect(html, contains('/main.dart.js'));
      expect(html, contains('/flutter_bootstrap.js'));
      expect(html, contains('<p>x</p>'));
    });

    test('uses provided baseHref for absolute paths', () {
      final root =
          Assets.injectFlutterAssets(
                DocumentRootNode(body: []),
                baseHref: '/app/',
              )
              as DocumentRootNode;
      final html = const HtmlSerializer().serialize(root);
      expect(html, contains('/app/main.dart.js'));
    });
  });

  group('Dart Frog adapter (P2-10)', () {
    test('middleware produces a valid shelf handler', () {
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final handler = DartFrogAdapter.middleware(
        HydralineConfig(manifest: RouteManifest.parseYaml(manifestYaml)),
      );
      expect(handler, isA<Function>());
    });
  });

  group('app route defaults (P2-11)', () {
    test('app route auto-noindex', () {
      final meta = defaultMetadataForRoute(
        const RouteEntry(path: '/app', mode: RouteMode.app),
      );
      expect(meta.robots.noindex, isTrue);
    });

    test('document route does not auto-noindex', () {
      final meta = defaultMetadataForRoute(
        const RouteEntry(path: '/', mode: RouteMode.document),
      );
      expect(meta.robots.noindex, isFalse);
    });
  });
}
