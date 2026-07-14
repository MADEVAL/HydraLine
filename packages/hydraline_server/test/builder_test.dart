import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  group('DocumentBuilder integration', () {
    test('document route invokes registered builder', () async {
      const manifestYaml = '''
routes:
  - path: /page
    mode: document
''';
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(manifestYaml),
          builders: {
            '/page': (_, __) => DocumentRootNode(
              body: [
                ParagraphNode(children: [TextNode('Hello')]),
              ],
            ),
          },
        ),
      )((_) async => Response.ok('fallback'));

      final response = await httpGet(handler, '/page');
      expect(await bodyOf(response), contains('<p>Hello</p>'));
    });

    test(
      'builder registered under a pattern runs for a concrete path',
      () async {
        const manifestYaml = '''
routes:
  - path: /product/:id
    mode: document
''';
        final handler = hydralineMiddleware(
          HydralineConfig(
            manifest: RouteManifest.parseYaml(manifestYaml),
            builders: {
              '/product/:id': (request, __) => DocumentRootNode(
                body: [
                  ParagraphNode(
                    children: [TextNode('product ${request.url.path}')],
                  ),
                ],
              ),
            },
          ),
        )((_) async => Response.ok('fallback'));

        final response = await httpGet(handler, '/product/42');
        expect(await bodyOf(response), contains('product product/42'));
      },
    );

    test('pattern builder also runs on the cached code path', () async {
      const manifestYaml = '''
routes:
  - path: /blog/:slug
    mode: document
''';
      var builds = 0;
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(manifestYaml),
          builders: {
            '/blog/:slug': (_, __) {
              builds++;
              return const DocumentRootNode(
                body: [
                  ParagraphNode(children: [TextNode('post body')]),
                ],
              );
            },
          },
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.ok('fallback'));

      final response = await httpGet(handler, '/blog/first-post');
      expect(builds, 1);
      expect(await bodyOf(response), contains('post body'));
    });

    test(
      'builder throwing RedirectException with 301 produces a 301',
      () async {
        const manifestYaml = '''
routes:
  - path: /old
    mode: document
''';
        final handler = hydralineMiddleware(
          HydralineConfig(
            manifest: RouteManifest.parseYaml(manifestYaml),
            builders: {
              '/old': (_, __) =>
                  throw const RedirectException('/new', status: 301),
            },
          ),
        )((_) async => Response.ok('fallback'));

        final response = await httpGet(handler, '/old');
        expect(response.statusCode, 301);
        expect(response.headers['location'], '/new');
      },
    );

    test(
      'builder throwing RedirectException with 302 produces a 302',
      () async {
        const manifestYaml = '''
routes:
  - path: /temporary
    mode: document
''';
        final handler = hydralineMiddleware(
          HydralineConfig(
            manifest: RouteManifest.parseYaml(manifestYaml),
            builders: {
              '/temporary': (_, __) =>
                  throw const RedirectException('/new', status: 302),
            },
          ),
        )((_) async => Response.ok('fallback'));

        final response = await httpGet(handler, '/temporary');
        expect(response.statusCode, 302);
        expect(response.headers['location'], '/new');
      },
    );
  });
}
