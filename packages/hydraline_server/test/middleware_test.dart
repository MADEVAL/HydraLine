import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  late Handler handler;

  setUpAll(() async {
    const manifestYaml = '''
routes:
  - path: /
    mode: document
  - path: /blog
    mode: hybrid
  - path: /app
    mode: app
''';
    final manifest = RouteManifest.parseYaml(manifestYaml);
    handler = createTestHandler(manifest);
  });

  group('Route matching', () {
    test('document route returns 200 with HTML', () async {
      final response = await httpGet(handler, '/');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));
    });

    test('hybrid route returns 200 with HTML', () async {
      final response = await httpGet(handler, '/blog');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));
    });

    test('app route passes through to inner handler', () async {
      final response = await httpGet(handler, '/app');
      expect(response.statusCode, 200);
      final body = await bodyOf(response);
      expect(body, isNot(contains('<!DOCTYPE')));
      expect(body, contains('app-shell'));
    });

    test('unknown route returns 404', () async {
      final response = await httpGet(handler, '/nonexistent');
      expect(response.statusCode, 404);
    });
  });

  group('HTTP semantics', () {
    test('redirect', () async {
      // Unit-tested via shelf's Response.movedPermanently
      final response = Response.movedPermanently('/target');
      expect(response.statusCode, 301);
      expect(response.headers['location'], '/target');
    });

    test('notFound with custom body', () {
      final response = Http.notFound();
      expect(response.statusCode, 404);
    });

    test('gone (410)', () {
      final response = Http.gone();
      expect(response.statusCode, 410);
    });

    test('X-Robots-Tag is added by withRobots', () {
      final base = Response.ok('');
      final tagged = Http.withRobots(base, noindex: true, nofollow: true);
      expect(tagged.headers['x-robots-tag'], 'noindex, nofollow');
    });

    test('X-Robots-Tag omitted when both flags are false', () {
      final base = Response.ok('');
      final tagged = Http.withRobots(base, noindex: false, nofollow: false);
      expect(tagged.headers.containsKey('x-robots-tag'), isFalse);
    });

    test('canonicalizePath strips trailing slashes and normalises', () {
      expect(Http.canonicalizePath('/blog/'), '/blog');
      expect(Http.canonicalizePath('//blog//'), '/blog');
      expect(Http.canonicalizePath('/'), '/');
    });
  });
}
