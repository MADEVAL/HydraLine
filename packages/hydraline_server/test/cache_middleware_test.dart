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

    test('different query strings are cached separately', () async {
      const manifestYaml = '''
routes:
  - path: /search
    mode: document
''';
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(manifestYaml),
          builders: {
            '/search': (request, _) => DocumentRootNode(
              body: [
                ParagraphNode(
                  children: [TextNode('q=${request.url.queryParameters['q']}')],
                ),
              ],
            ),
          },
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final first = await httpGet(handler, '/search?q=alpha');
      final second = await httpGet(handler, '/search?q=beta');
      expect(await bodyOf(first), contains('q=alpha'));
      expect(await bodyOf(second), contains('q=beta'));
    });

    test('same query params in different order hit one cache entry', () async {
      const manifestYaml = '''
routes:
  - path: /search
    mode: document
''';
      var builds = 0;
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(manifestYaml),
          builders: {
            '/search': (_, _) {
              builds++;
              return const DocumentRootNode(
                body: [
                  ParagraphNode(children: [TextNode('results')]),
                ],
              );
            },
          },
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      await httpGet(handler, '/search?a=1&b=2');
      await httpGet(handler, '/search?b=2&a=1');
      expect(builds, 1);
    });

    test('cacheable responses carry a Vary header', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
          cacheTtl: const Duration(minutes: 5),
        ),
      )((_) async => Response.notFound(''));

      final response = await httpGet(handler, '/');
      expect(response.headers['vary'], 'Accept-Encoding');
    });

    test('If-None-Match with an ETag list returns 304', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final first = await httpGet(handler, '/');
      final etag = first.headers['etag']!;

      final second = await httpGet(
        handler,
        '/',
        headers: {'If-None-Match': '"stale-etag", $etag'},
      );
      expect(second.statusCode, 304);
    });

    test('If-None-Match with a weak validator returns 304', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final first = await httpGet(handler, '/');
      final etag = first.headers['etag']!;

      final second = await httpGet(
        handler,
        '/',
        headers: {'If-None-Match': 'W/$etag'},
      );
      expect(second.statusCode, 304);
    });

    test('ETag is a 64-bit hash (16 hex digits)', () async {
      final handler = hydralineMiddleware(
        HydralineConfig(
          manifest: RouteManifest.parseYaml(_manifestYaml),
          builders: {'/': (_, _) => const DocumentRootNode(body: [])},
          cache: HydralineCache.inMemory(),
        ),
      )((_) async => Response.notFound(''));

      final response = await httpGet(handler, '/');
      expect(response.headers['etag'], matches(r'^"[0-9a-f]{16}"$'));
    });

    test(
      'trailing slash and duplicate slashes hit the same cache entry',
      () async {
        const manifestYaml = '''
routes:
  - path: /page
    mode: document
''';
        var builds = 0;
        final handler = hydralineMiddleware(
          HydralineConfig(
            manifest: RouteManifest.parseYaml(manifestYaml),
            builders: {
              '/page': (_, _) {
                builds++;
                return const DocumentRootNode(
                  body: [
                    ParagraphNode(children: [TextNode('canonical page')]),
                  ],
                );
              },
            },
            cache: HydralineCache.inMemory(),
          ),
        )((_) async => Response.notFound(''));

        final first = await httpGet(handler, '/page/');
        final second = await httpGet(handler, '//page');
        expect(builds, 1);
        expect(await bodyOf(first), contains('canonical page'));
        expect(await bodyOf(second), contains('canonical page'));
      },
    );
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
