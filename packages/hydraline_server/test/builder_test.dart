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
