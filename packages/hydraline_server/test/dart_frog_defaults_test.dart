import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:test/test.dart';

void main() {
  group('DartFrogAdapter', () {
    test('middleware produces a valid shelf handler', () {
      const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
      final handler = DartFrogAdapter.middleware(
        HydralineConfig(manifest: RouteManifest.parseYaml(manifestYaml)),
      );
      expect(handler, isA<Function>());
    });
  });

  group('defaultMetadataForRoute', () {
    test('app routes auto-noindex', () {
      final meta = defaultMetadataForRoute(
        const RouteEntry(path: '/app', mode: RouteMode.app),
      );
      expect(meta.robots.noindex, isTrue);
    });

    test('document routes do not auto-noindex', () {
      final meta = defaultMetadataForRoute(
        const RouteEntry(path: '/', mode: RouteMode.document),
      );
      expect(meta.robots.noindex, isFalse);
    });

    test('explicit noindex override is respected', () {
      final meta = defaultMetadataForRoute(
        const RouteEntry(path: '/x', mode: RouteMode.document, noindex: true),
      );
      expect(meta.robots.noindex, isTrue);
    });
  });
}
