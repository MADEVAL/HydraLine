import 'dart:io';

import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

class _TestAdapter implements RouteAdapter {
  _TestAdapter(List<RouteInfo> routes) : _routes = routes;
  final List<RouteInfo> _routes;
  @override
  List<RouteInfo> get routes => _routes;
  @override
  Future<void> navigateToForExtraction(RouteInfo route) async {}
}

void main() {
  group('SSG runner', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('writes HTML files for each route', () async {
      final adapter = _TestAdapter([const RouteInfo(path: '/')]);
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        routeAdapter: adapter,
        islandFactories: {},
      );
      await runner.run(outputDir: tmpDir.path);
      final indexFile = File('${tmpDir.path}/index.html');
      expect(await indexFile.exists(), isTrue);
      final content = await indexFile.readAsString();
      expect(content, contains('<!DOCTYPE html>'));
    });

    test('generates sitemap.xml and robots.txt in output', () async {
      final adapter = _TestAdapter([const RouteInfo(path: '/')]);
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        routeAdapter: adapter,
        islandFactories: {},
      );
      await runner.run(outputDir: tmpDir.path);
      final sitemap = File('${tmpDir.path}/sitemap.xml');
      final robots = File('${tmpDir.path}/robots.txt');
      expect(await sitemap.exists(), isTrue);
      expect(await robots.exists(), isTrue);
    });

    test('renders body content from a registered pure-Dart builder', () async {
      final adapter = _TestAdapter([const RouteInfo(path: '/')]);
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        routeAdapter: adapter,
        islandFactories: {},
        builders: {
          '/': (path) => DocumentRootNode(
            head: buildHead(const SeoMeta(title: 'Built Home')),
            body: const [
              HeadingNode(level: 1, children: [TextNode('Hello from B')]),
            ],
          ),
        },
      );
      await runner.run(outputDir: tmpDir.path);
      final html = await File('${tmpDir.path}/index.html').readAsString();
      expect(html, contains('<title>Built Home</title>'));
      expect(html, contains('<h1>Hello from B</h1>'));
    });

    test('builder receives each expanded dynamic path', () async {
      final adapter = _TestAdapter([]);
      final manifest = RouteManifest.builder()
          .route(
            const RouteEntry(
              path: '/blog/:slug',
              mode: RouteMode.document,
              dynamicSegments: {
                'slug': ['a', 'b'],
              },
            ),
          )
          .build();
      final seen = <String>[];
      final runner = SsgRunner(
        routeManifest: manifest,
        routeAdapter: adapter,
        islandFactories: {},
        builders: {
          '/blog/:slug': (path) {
            seen.add(path);
            return DocumentRootNode(
              body: [
                ParagraphNode(children: [TextNode('page $path')]),
              ],
            );
          },
        },
      );
      final result = await runner.run(outputDir: tmpDir.path);
      expect(result.pagesWritten, 2);
      expect(seen, ['/blog/a', '/blog/b']);
      final pageA = await File('${tmpDir.path}/blog/a.html').readAsString();
      expect(pageA, contains('page /blog/a'));
    });
  });

  group('Dynamic segments', () {
    test('expands a pattern into concrete paths', () {
      const segments = {
        'slug': ['post-1', 'post-2'],
      };
      final expanded = DynamicSegments.expand({'/blog/:slug': segments});
      expect(expanded, contains('/blog/post-1'));
      expect(expanded, contains('/blog/post-2'));
      expect(expanded, hasLength(2));
    });

    test('expands multiple segments as a cartesian product', () {
      const segments = {
        'category': ['tech', 'life'],
        'slug': ['a', 'b'],
      };
      final expanded = DynamicSegments.expand({
        '/blog/:category/:slug': segments,
      });
      expect(expanded, [
        '/blog/tech/a',
        '/blog/tech/b',
        '/blog/life/a',
        '/blog/life/b',
      ]);
    });

    test('correlates values with their segment names', () {
      const segments = {
        'slug': ['about'],
        'lang': ['en', 'de'],
      };
      final expanded = DynamicSegments.expand({'/:lang/:slug': segments});
      expect(expanded, ['/en/about', '/de/about']);
    });

    test('throws when a named segment has no values', () {
      expect(
        () => DynamicSegments.expand({
          '/blog/:category/:slug': {
            'category': ['tech'],
          },
        }),
        throwsArgumentError,
      );
    });
  });

  group('SSG runner sitemap base URL', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('uses the manifest base_url for every sitemap entry', () async {
      const manifestYaml = '''
base_url: https://demo.example
routes:
  - path: /
    mode: document
  - path: /blog/:slug
    mode: document
    dynamic_segments:
      slug: [first]
''';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        routeAdapter: _TestAdapter([]),
        islandFactories: {},
      );
      await runner.run(outputDir: tmpDir.path);
      final xml = await File('${tmpDir.path}/sitemap.xml').readAsString();
      expect(xml, contains('<loc>https://demo.example/</loc>'));
      expect(xml, contains('<loc>https://demo.example/blog/first</loc>'));
      expect(xml, isNot(contains('localhost')));
    });
  });

  group('SsgResult', () {
    test('carries pagesWritten and assetsCopied', () {
      const result = SsgResult(pagesWritten: 5, assetsCopied: true);
      expect(result.pagesWritten, 5);
      expect(result.assetsCopied, isTrue);
    });
  });

  group('SsgRunner construction', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('runs without an explicit route adapter', () async {
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        islandFactories: {},
      );
      final result = await runner.run(outputDir: tmpDir.path);
      expect(result.pagesWritten, 1);
    });
  });

  group('SSG runner asset copying by island type', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'does not copy Flutter runtime for a vanilla-only factory map',
      () async {
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/',
                mode: RouteMode.hybrid,
                contentSource: WidgetContent(),
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          islandFactories: {'faq': IslandType.vanilla},
        );
        final result = await runner.run(outputDir: tmpDir.path);
        expect(result.assetsCopied, isFalse);
        expect(
          await File('${tmpDir.path}/hydraline-island.js').exists(),
          isFalse,
        );
      },
    );

    test(
      'copies Flutter runtime when a flutter island type is present',
      () async {
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/',
                mode: RouteMode.hybrid,
                contentSource: WidgetContent(),
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          islandFactories: {
            'faq': IslandType.vanilla,
            'calc': IslandType.flutter,
          },
        );
        final result = await runner.run(outputDir: tmpDir.path);
        expect(result.assetsCopied, isTrue);
        expect(
          await File('${tmpDir.path}/hydraline-island.js').exists(),
          isTrue,
        );
      },
    );
  });

  group('SSG runner asset copying', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'copies Flutter web assets when island factories are present',
      () async {
        final adapter = _TestAdapter([const RouteInfo(path: '/')]);
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/',
                mode: RouteMode.hybrid,
                contentSource: WidgetContent(),
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          routeAdapter: adapter,
          islandFactories: {'my-island': IslandType.flutter},
        );
        final result = await runner.run(outputDir: tmpDir.path);
        expect(result.assetsCopied, isTrue);
        expect(
          await File('${tmpDir.path}/hydraline-island.js').exists(),
          isTrue,
        );
        expect(
          await File('${tmpDir.path}/hydraline-dispatcher.js').exists(),
          isTrue,
        );
        expect(await File('${tmpDir.path}/service-worker.js').exists(), isTrue);
      },
    );

    test('does not copy Flutter assets and marks assetsCopied false '
        'when no islands are present', () async {
      final adapter = _TestAdapter([const RouteInfo(path: '/about')]);
      const manifestYaml = 'routes:\n  - path: /about\n    mode: document\n';
      final runner = SsgRunner(
        routeManifest: RouteManifest.parseYaml(manifestYaml),
        routeAdapter: adapter,
        islandFactories: {},
      );
      final result = await runner.run(outputDir: tmpDir.path);
      expect(result.assetsCopied, isFalse);
      expect(
        await File('${tmpDir.path}/hydraline-island.js').exists(),
        isFalse,
      );
      expect(
        await File('${tmpDir.path}/flutter_bootstrap.js').exists(),
        isFalse,
      );
    });

    test('writes runtime assets even when no web/ dir exists', () async {
      final adapter = _TestAdapter([const RouteInfo(path: '/')]);
      final webDir = Directory('web');
      final renamed = Directory('web_tmp');
      if (await webDir.exists()) {
        await webDir.rename(renamed.path);
      }
      try {
        final manifest = RouteManifest.builder()
          ..route(
            const RouteEntry(
              path: '/',
              mode: RouteMode.hybrid,
              contentSource: WidgetContent(),
            ),
          );
        final runner = SsgRunner(
          routeManifest: manifest.build(),
          routeAdapter: adapter,
          islandFactories: {'my-island': IslandType.flutter},
        );
        await runner.run(outputDir: tmpDir.path);
        expect(
          await File('${tmpDir.path}/hydraline-island.js').exists(),
          isTrue,
        );
      } finally {
        if (await renamed.exists()) {
          await renamed.rename(webDir.path);
        }
      }
    });

    test('never copies app web/ host files over generated pages', () async {
      // Simulate an application project: the cwd has a web/ dir with an
      // index.html host page and a custom bootstrap.
      final appDir = Directory.systemTemp.createTempSync('hydraline_app_');
      Directory('${appDir.path}/web').createSync();
      File(
        '${appDir.path}/web/index.html',
      ).writeAsStringSync('<html>host page</html>');
      File(
        '${appDir.path}/web/flutter_bootstrap.js',
      ).writeAsStringSync('// app bootstrap');
      final previous = Directory.current;
      Directory.current = appDir;
      try {
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/',
                mode: RouteMode.hybrid,
                contentSource: WidgetContent(),
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          routeAdapter: _TestAdapter([]),
          islandFactories: {'my-island': IslandType.flutter},
        );
        await runner.run(outputDir: tmpDir.path);
      } finally {
        Directory.current = previous;
        appDir.deleteSync(recursive: true);
      }

      final html = File('${tmpDir.path}/index.html').readAsStringSync();
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, isNot(contains('host page')));
      expect(
        File('${tmpDir.path}/flutter_bootstrap.js').existsSync(),
        isFalse,
        reason: 'app host files are not runtime assets',
      );
      expect(
        File('${tmpDir.path}/hydraline-island.js').existsSync(),
        isTrue,
        reason: 'runtime assets come from the hydraline_flutter package',
      );
    });
  });

  group('SSG runner dynamic segments integration', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_ssg_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'expands dynamic routes and generates HTML for each segment value',
      () async {
        final adapter = _TestAdapter([
          const RouteInfo(path: '/blog/post-1'),
          const RouteInfo(path: '/blog/post-2'),
        ]);
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/blog/:slug',
                mode: RouteMode.document,
                dynamicSegments: {
                  'slug': ['post-1', 'post-2'],
                },
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          routeAdapter: adapter,
          islandFactories: {},
        );
        final result = await runner.run(outputDir: tmpDir.path);
        expect(result.pagesWritten, 2);
        final post1 = File('${tmpDir.path}/blog/post-1.html');
        final post2 = File('${tmpDir.path}/blog/post-2.html');
        expect(await post1.exists(), isTrue);
        expect(await post2.exists(), isTrue);
        final post1Content = await post1.readAsString();
        expect(post1Content, contains('<!DOCTYPE html>'));
        final post2Content = await post2.readAsString();
        expect(post2Content, contains('<!DOCTYPE html>'));
      },
    );

    test(
      'skips route pattern path when dynamic segments are expanded',
      () async {
        final adapter = _TestAdapter([const RouteInfo(path: '/blog/post-1')]);
        final manifest = RouteManifest.builder()
            .route(
              const RouteEntry(
                path: '/blog/:slug',
                mode: RouteMode.document,
                dynamicSegments: {
                  'slug': ['post-1'],
                },
              ),
            )
            .build();
        final runner = SsgRunner(
          routeManifest: manifest,
          routeAdapter: adapter,
          islandFactories: {},
        );
        await runner.run(outputDir: tmpDir.path);
        expect(
          await File('${tmpDir.path}/blog/-slug.html').exists(),
          isFalse,
          reason: 'the pattern path should not be written',
        );
      },
    );
  });
}
