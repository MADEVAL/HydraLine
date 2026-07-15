import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Handler _handler({
  required Map<String, DocumentBuilder> builders,
  String path = '/',
  String mode = 'document',
}) => hydralineMiddleware(
  HydralineConfig(
    manifest: RouteManifest.parseYaml(
      'routes:\n  - path: $path\n    mode: $mode\n',
    ),
    builders: builders,
  ),
)((_) async => Response.ok('inner'));

void main() {
  group('HEAD requests', () {
    test(
      'HEAD on a document route returns headers with an empty body',
      () async {
        final handler = _handler(
          builders: {
            '/': (req, data) => const DocumentRootNode(
              body: [
                ParagraphNode(children: [TextNode('hello')]),
              ],
            ),
          },
        );
        final response = await handler(
          Request('HEAD', Uri.parse('http://localhost/')),
        );
        expect(response.statusCode, 200);
        final body = await response.read().expand((c) => c).toList();
        expect(body, isEmpty);
      },
    );
  });

  group('DocumentBuilder data', () {
    test('builder receives the matched RouteEntry as data', () async {
      Object? received = 'untouched';
      final handler = _handler(
        path: '/p',
        builders: {
          '/p': (req, data) {
            received = data;
            return const DocumentRootNode(body: []);
          },
        },
      );
      await handler(Request('GET', Uri.parse('http://localhost/p')));
      expect(received, isA<RouteEntry>());
      expect((received! as RouteEntry).path, '/p');
    });
  });
}
