import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

const _manifestYaml = '''
routes:
  - path: /
    mode: document
''';

void main() {
  group('middleware cache integration', () {
    test('second request is served from cache (builder runs once)', () async {
      var builds = 0;
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {
            '/': (_, _) {
              builds++;
              return const DocumentRootNode(
                body: [
                  ParagraphNode(children: [TextNode('cached page')]),
                ],
              );
            },
          },
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final first = await httpGet(handler, '/');
      final second = await httpGet(handler, '/');
      expect(builds, 1);
      expect(await bodyOf(first), contains('cached page'));
      expect(await bodyOf(second), contains('cached page'));
    });

    test('responses carry an ETag; If-None-Match returns 304', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final first = await httpGet(handler, '/');
      final etag = first.headers['etag'];
      expect(etag, isNotNull);

      final second = await httpGet(
        handler,
        '/',
        headers: {'If-None-Match': etag!},
      );
      expect(second.statusCode, 304);
    });

    test('Cache-Control reflects the configured TTL', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
          cacheTtl: const Duration(minutes: 5),
        ),
      )((_) async => Response.notFound(''));

      final response = await httpGet(handler, '/');
      expect(response.headers['cache-control'], 'public, max-age=300');
    });

    test('no cache configured -> no ETag, streaming as before', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
        ),
      )((_) async => Response.notFound(''));

      final response = await httpGet(handler, '/');
      expect(response.headers.containsKey('etag'), isFalse);
      expect(response.contentLength, isNull);
    });
  });

  group('HydralineCache', () {
    test('inMemory factory returns a working cache', () async {
      final cache = HydralineCache.inMemory();
      await cache.set('k', 'v');
      expect(await cache.get('k'), 'v');
    });

    test('invalidate removes an entry', () async {
      final cache = HydralineCache.inMemory();
      await cache.set('k', 'v');
      await cache.invalidate('k');
      expect(await cache.get('k'), isNull);
    });

    test('maxSize evicts the oldest entry', () async {
      final cache = HydralineCache.inMemory(maxSize: 2);
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.set('c', '3');
      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), '2');
      expect(await cache.get('c'), '3');
    });

    test('entry with an expired TTL is evicted on read', () async {
      final cache = HydralineCache.inMemory();
      await cache.set('k', 'v', ttl: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await cache.get('k'), isNull);
    });

    test('entry with a live TTL is served', () async {
      final cache = HydralineCache.inMemory();
      await cache.set('k', 'v', ttl: const Duration(hours: 1));
      expect(await cache.get('k'), 'v');
    });

    test('returns null on a miss', () async {
      final cache = HydralineCache.inMemory();
      expect(await cache.get('nonexistent'), isNull);
    });
  });
}
