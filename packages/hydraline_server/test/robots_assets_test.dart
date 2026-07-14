import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

Handler _handler(String manifestYaml) => hydralineMiddleware(
  HydralineConfig(manifest: RouteManifest.parseYaml(manifestYaml)),
)((_) async => Response.ok('app-shell'));

void main() {
  group('automatic X-Robots-Tag', () {
    test('document route with noindex: true carries the header', () async {
      final handler = _handler('''
routes:
  - path: /hidden
    mode: document
    noindex: true
''');
      final response = await httpGet(handler, '/hidden');
      expect(response.headers['x-robots-tag'], 'noindex');
    });

    test('document route with metadata robots noindex carries it', () async {
      final handler = _handler('''
routes:
  - path: /meta-hidden
    mode: document
    metadata:
      title: Hidden
      robots:
        noindex: true
        nofollow: true
''');
      final response = await httpGet(handler, '/meta-hidden');
      expect(response.headers['x-robots-tag'], 'noindex, nofollow');
    });

    test('plain document route has no X-Robots-Tag', () async {
      final handler = _handler('''
routes:
  - path: /
    mode: document
''');
      final response = await httpGet(handler, '/');
      expect(response.headers.containsKey('x-robots-tag'), isFalse);
    });

    test('app route defaults to noindex', () async {
      final handler = _handler('''
routes:
  - path: /app
    mode: app
''');
      final response = await httpGet(handler, '/app');
      expect(response.headers['x-robots-tag'], 'noindex');
    });

    test('app route with explicit noindex: false has no header', () async {
      final handler = _handler('''
routes:
  - path: /app
    mode: app
    noindex: false
''');
      final response = await httpGet(handler, '/app');
      expect(response.headers.containsKey('x-robots-tag'), isFalse);
    });

    test('app route emits nofollow from metadata robots', () async {
      final handler = _handler('''
routes:
  - path: /app
    mode: app
    noindex: false
    metadata:
      title: App
      robots:
        nofollow: true
''');
      final response = await httpGet(handler, '/app');
      expect(response.headers['x-robots-tag'], 'nofollow');
    });
  });

  group('Assets.serveCoreAssets - L0/L1 JS', () {
    test('serves the vanilla islands bundle', () async {
      final handler = Assets.serveCoreAssets();
      final response = await httpGet(handler, '/vanilla-islands.js');
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('javascript'));
      expect(await bodyOf(response), vanillaIslandsJs);
    });

    test('serves the HTMX glue script', () async {
      final handler = Assets.serveCoreAssets();
      final response = await httpGet(handler, '/htmx-glue.js');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), htmxGlueJs);
    });

    test('serves assets under the assets/hydraline/ prefix too', () async {
      final handler = Assets.serveCoreAssets();
      final response = await httpGet(
        handler,
        '/assets/hydraline/vanilla-islands.js',
      );
      expect(response.statusCode, 200);
    });

    test('serves a configured sitemap.xml', () async {
      final handler = Assets.serveCoreAssets(
        sitemapXml: '<?xml version="1.0"?><urlset></urlset>',
      );
      final response = await httpGet(handler, '/sitemap.xml');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<urlset>'));
    });

    test('serves a custom robots.txt override', () async {
      final handler = Assets.serveCoreAssets(
        robotsTxt: 'User-agent: *\nDisallow: /private\n',
      );
      final response = await httpGet(handler, '/robots.txt');
      expect(await bodyOf(response), contains('Disallow: /private'));
    });

    test('serves a default robots.txt when no override is given', () async {
      final handler = Assets.serveCoreAssets();
      final response = await httpGet(handler, '/robots.txt');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('User-agent'));
    });

    test('sitemap.xml responds 404 when not configured', () async {
      final handler = Assets.serveCoreAssets();
      final response = await httpGet(handler, '/sitemap.xml');
      expect(response.statusCode, 404);
    });
  });

  group('Assets.injectFlutterAssets', () {
    test('appends the engine scripts before </body>', () {
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

    test('uses the provided baseHref for absolute paths', () {
      final root =
          Assets.injectFlutterAssets(
                const DocumentRootNode(body: []),
                baseHref: '/app/',
              )
              as DocumentRootNode;
      final html = const HtmlSerializer().serialize(root);
      expect(html, contains('/app/main.dart.js'));
    });
  });
}
