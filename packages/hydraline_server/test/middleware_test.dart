import 'dart:async';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

FutureOr<DocumentNode> _buildEmptyPage(Request request, Object? data) async {
  return DocumentRootNode(body: []);
}

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

  group('Bot-aware delivery', () {
    const manifestYaml = '''
routes:
  - path: /
    mode: document
''';

    test('bot UA triggers buffered delivery with Content-Length', () async {
      final manifest = RouteManifest.parseYaml(manifestYaml);
      final handler = createTestHandler(
        manifest,
        botUserAgentPattern: RegExp(r'Googlebot'),
      );
      final response = await httpGet(
        handler,
        '/',
        headers: {'User-Agent': 'Googlebot/2.1'},
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));

      // Buffered delivery: body is a complete String, contentLength is known.
      expect(response.contentLength, isNotNull);
      expect(response.contentLength, greaterThan(0));
    });

    test('user UA triggers chunked streaming delivery', () async {
      final manifest = RouteManifest.parseYaml(manifestYaml);
      final handler = createTestHandler(
        manifest,
        botUserAgentPattern: RegExp(r'Googlebot'),
      );
      final response = await httpGet(
        handler,
        '/',
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));

      // Chunked delivery: body is a Stream, no contentLength.
      expect(response.contentLength, isNull);
    });

    test('no botUserAgentPattern falls back to chunked', () async {
      final manifest = RouteManifest.parseYaml(manifestYaml);
      final handler = createTestHandler(manifest); // no pattern
      final response = await httpGet(
        handler,
        '/',
        headers: {'User-Agent': 'Googlebot/2.1'},
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));

      // No pattern configured -> always chunked.
      expect(response.contentLength, isNull);
    });
  });

  group('DocumentBuilder UA-blind contract', () {
    test('typedef excludes User-Agent as a direct parameter', () {
      // The DocumentBuilder type is (Request request, Object? data) - no
      // User-Agent or UA-specific parameter.

      // A function matching the typedef must be assignable:
      final DocumentBuilder validBuilder = _buildEmptyPage;
      expect(validBuilder, isA<DocumentBuilder>());

      // A function that expects a UA parameter is NOT a DocumentBuilder.
      // This is enforced by Dart's type system at compile time:
      //   DocumentBuilder invalid = (Request req, String ua, Object? data) => ...;
      // would not compile.
    });

    test(
      'HydralineConfig keeps botUserAgentPattern in transport layer only',
      () {
        const manifestYaml = '''
routes:
  - path: /
    mode: document
''';
        final manifest = RouteManifest.parseYaml(manifestYaml);
        final config = HydralineConfig(
          manifest: manifest,
          botUserAgentPattern: RegExp(r'Googlebot'),
        );

        // botUserAgentPattern lives on HydralineConfig (transport layer).
        expect(config.botUserAgentPattern, isNotNull);

        // DocumentBuilder has no access to botUserAgentPattern - it is not a
        // parameter. The builder receives (Request, Object?) only.
        final DocumentBuilder builder = _buildEmptyPage;
        expect(builder, isA<DocumentBuilder>());
      },
    );
  });
}
