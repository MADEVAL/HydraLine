import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

Handler _handlerFor(String path, DocumentBuilder builder) =>
    hydralineMiddleware(
      HydralineConfig(
        manifest: RouteManifest.parseYaml(
          'routes:\n  - path: $path\n    mode: document\n',
        ),
        builders: {path: builder},
      ),
    )((_) async => Response.ok('fallback'));

void main() {
  group('RedirectException status handling', () {
    test('410 produces a 410 Gone response', () async {
      final handler = _handlerFor(
        '/gone',
        (_, _) => throw const RedirectException.gone(),
      );
      final response = await httpGet(handler, '/gone');
      expect(response.statusCode, 410);
    });

    test('RedirectException with explicit 410 status produces 410', () async {
      final handler = _handlerFor(
        '/gone',
        (_, _) => throw const RedirectException('', status: 410),
      );
      final response = await httpGet(handler, '/gone');
      expect(response.statusCode, 410);
    });

    test('other 3xx statuses carry the Location header', () async {
      final handler = _handlerFor(
        '/perm',
        (_, _) => throw const RedirectException('/new', status: 308),
      );
      final response = await httpGet(handler, '/perm');
      expect(response.statusCode, 308);
      expect(response.headers['location'], '/new');
    });

    test('303 See Other carries status and Location', () async {
      final handler = _handlerFor(
        '/old',
        (_, _) => throw const RedirectException('/new', status: 303),
      );
      final response = await httpGet(handler, '/old');
      expect(response.statusCode, 303);
      expect(response.headers['location'], '/new');
    });
  });
}
