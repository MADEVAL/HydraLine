import 'dart:io';

import 'package:hydraline/hydraline.dart';
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
  group('SSG runner (P4-07/SSG1-SSG3)', () {
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
  });

  group('Dynamic segments (P4-09/W-15)', () {
    test('expands a pattern into concrete paths', () {
      const segments = {
        'slug': ['post-1', 'post-2'],
      };
      final expanded = DynamicSegments.expand({'/blog/:slug': segments});
      expect(expanded, contains('/blog/post-1'));
      expect(expanded, contains('/blog/post-2'));
      expect(expanded, hasLength(2));
    });
  });
}
