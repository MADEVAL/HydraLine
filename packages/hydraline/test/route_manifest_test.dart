import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

const _yaml = '''
version: "1.0"
base_url: https://x.example
routes:
  - path: /
    mode: document
    content_source: widget
    metadata:
      title: Home
      description: Welcome home
      canonical: https://x.example/
      lang: en
  - path: /blog/:slug
    mode: document
    content_source: dart_builder:BlogPostBuilder.new
    dynamic_segments:
      slug: [post-1, post-2]
  - path: /app/dashboard
    mode: app
''';

void main() {
  group('RouteManifest.parseYaml (RM1/C-8)', () {
    test('parses routes, modes and content sources', () {
      final manifest = RouteManifest.parseYaml(_yaml);
      expect(manifest.routes, hasLength(3));

      final home = manifest.routes[0];
      expect(home.path, '/');
      expect(home.mode, RouteMode.document);
      expect(home.contentSource, isA<WidgetContent>());
      expect((home.contentSource! as WidgetContent).pageBuilderId, isNull);
      expect(home.metadata!.title, 'Home');
      expect(home.metadata!.description, 'Welcome home');
      expect(home.metadata!.canonical!.value, 'https://x.example/');
      expect(home.metadata!.lang, 'en');

      final blog = manifest.routes[1];
      expect(blog.path, '/blog/:slug');
      expect(blog.contentSource, isA<DartBuilderContent>());
      expect(
        (blog.contentSource! as DartBuilderContent).builderId,
        'BlogPostBuilder.new',
      );
      expect(blog.dynamicSegments, {
        'slug': ['post-1', 'post-2'],
      });

      final app = manifest.routes[2];
      expect(app.mode, RouteMode.app);
      expect(app.contentSource, isNull);
    });

    test('rejects a route without a path or mode', () {
      expect(
        () => RouteManifest.parseYaml('routes:\n  - mode: document\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RM1 round-trip (YAML <-> model)', () {
    test('toYaml output is stable across a re-parse', () {
      final once = RouteManifest.parseYaml(_yaml).toYaml();
      final twice = RouteManifest.parseYaml(once).toYaml();
      expect(twice, once);
    });

    test('preserves paths, modes and content sources', () {
      final reparsed = RouteManifest.parseYaml(
        RouteManifest.parseYaml(_yaml).toYaml(),
      );
      expect(reparsed.routes.map((r) => r.path), [
        '/',
        '/blog/:slug',
        '/app/dashboard',
      ]);
      expect(reparsed.routes[1].dynamicSegments['slug'], ['post-1', 'post-2']);
    });
  });

  group('RouteManifest.builder', () {
    test('builds a manifest that round-trips through YAML', () {
      final manifest =
          (RouteManifest.builder()
                ..route(
                  const RouteEntry(
                    path: '/',
                    mode: RouteMode.document,
                    contentSource: WidgetContent(),
                  ),
                )
                ..route(const RouteEntry(path: '/app', mode: RouteMode.app)))
              .build();
      final parsed = RouteManifest.parseYaml(manifest.toYaml());
      expect(parsed.routes.map((r) => r.path), ['/', '/app']);
      expect(parsed.routes[0].contentSource, isA<WidgetContent>());
    });
  });
}
