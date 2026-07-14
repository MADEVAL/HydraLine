import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  group('additional middleware coverage', () {
    test('returns HTML for document mode with no builder', () async {
      const manifestYaml = '''
routes:
  - path: /empty
    mode: document
''';
      final handler = createTestHandler(RouteManifest.parseYaml(manifestYaml));
      final response = await httpGet(handler, '/empty');
      expect(response.statusCode, 200);
      expect(await bodyOf(response), contains('<!DOCTYPE html>'));
    });

    test('prefix match on deep path picks a matching route', () async {
      const manifestYaml = '''
routes:
  - path: /blog/:year/:slug
    mode: document
''';
      final handler = createTestHandler(RouteManifest.parseYaml(manifestYaml));
      final response = await httpGet(handler, '/blog/2026/post');
      expect(response.statusCode, 200);
    });
  });

  group('Http edge cases', () {
    test('notFound with custom body returns 404', () {
      final root = DocumentRootNode(
        body: [
          ParagraphNode(children: [TextNode('not found')]),
        ],
      );
      final response = Http.notFound(body: root);
      expect(response.statusCode, 404);
    });
  });
}
