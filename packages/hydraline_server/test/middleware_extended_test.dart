import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  late Handler handler;

  setUp(() async {
    const manifestYaml = '''
routes:
  - path: /
    mode: document
  - path: /blog/:slug
    mode: hybrid
  - path: /deep/nested
    mode: document
  - path: /app
    mode: app
''';
    handler = createTestHandler(RouteManifest.parseYaml(manifestYaml));
  });

  group('middleware branch coverage', () {
    test('exact path match on nested route', () async {
      final response = await httpGet(handler, '/deep/nested');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));
    });

    test('dynamic segment prefix match', () async {
      final response = await httpGet(handler, '/blog/post-1');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));
    });

    test('path with trailing slash is matched via normalisation', () async {
      final response = await httpGet(handler, '/deep/nested/');
      // '/deep/nested/' canonicalizes to '/deep/nested' (exact match).
      expect(response.statusCode, 200);
    });

    test('trailing slash never matches a dynamic segment as empty', () async {
      final response = await httpGet(handler, '/blog/');
      // '/blog/' canonicalizes to '/blog'; there is no '/blog' route and an
      // empty ':slug' segment must not match.
      expect(response.statusCode, 404);
    });

    test('app route passes through, returning inner handler content', () async {
      final response = await httpGet(handler, '/app');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), 'app-shell');
    });

    test('not-found returns 404', () async {
      final response = await httpGet(handler, '/no-such');
      expect(response.statusCode, 404);
    });
  });

  group('Http unit', () {
    test('withRobots with noindex only', () {
      final base = Response.ok('');
      final tagged = Http.withRobots(base, noindex: true);
      expect(tagged.headers['x-robots-tag'], 'noindex');
    });

    test('canonicalizePath handles leading double slashes', () {
      expect(Http.canonicalizePath('//a//b'), '/a/b');
    });

    test('canonicalizePath adds leading slash', () {
      expect(Http.canonicalizePath('blog'), '/blog');
    });
  });
}
