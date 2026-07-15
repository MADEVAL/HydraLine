import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

const _manifestYaml = '''
routes:
  - path: /
    mode: document
  - path: /product/:id
    mode: hybrid
''';

Handler _handler({Pattern? botPattern}) {
  final manifest = RouteManifest.parseYaml(_manifestYaml);
  return hydralineMiddleware(
    HydralineConfig(
      manifest: manifest,
      botUserAgentPattern: botPattern,
      cache: HydralineCache.inMemory(),
    ),
  )((_) async => Response.ok('inner'));
}

void main() {
  group('SSR anti-cloaking', () {
    test('bot and human receive byte-identical bodies', () async {
      final handler = _handler(botPattern: RegExp(r'Googlebot|bingbot'));

      final bot = await httpGet(
        handler,
        '/',
        headers: {'user-agent': 'Googlebot'},
      );
      final human = await httpGet(handler, '/');

      final botBody = await bodyOf(bot);
      final humanBody = await bodyOf(human);

      expect(bot.statusCode, 200);
      expect(human.statusCode, 200);
      expect(botBody, humanBody);
      expect(botBody, contains('<!DOCTYPE html>'));
    });

    test('cached response carries etag and supports if-none-match', () async {
      final handler = _handler();

      final warm = await httpGet(handler, '/');
      expect(warm.statusCode, 200);
      final etag = warm.headers['etag'];
      expect(etag, matches(r'^"[0-9a-f]{16}"$'));

      final reval = await httpGet(
        handler,
        '/',
        headers: {'if-none-match': etag!},
      );
      expect(reval.statusCode, 304);
    });

    test('HEAD returns same headers as GET without a body', () async {
      final handler = _handler();
      final uri = Uri.parse('http://localhost/');

      final get = await handler(Request('GET', uri));
      final head = await handler(Request('HEAD', uri));

      expect(head.statusCode, get.statusCode);
      expect(head.headers['content-type'], contains('text/html'));
      final headBytes = await head.read().expand((c) => c).toList();
      expect(headBytes, isEmpty);
    });

    test('query-ordered cache keys normalise', () async {
      final handler = _handler();
      final uriA = Uri.parse('http://localhost/?b=2&a=1');
      final uriB = Uri.parse('http://localhost/?a=1&b=2');

      final a = await handler(Request('GET', uriA));
      final b = await handler(Request('GET', uriB));

      final aBody = await bodyOf(a);
      final bBody = await bodyOf(b);

      expect(a.statusCode, 200);
      expect(b.statusCode, 200);
      expect(aBody, bBody);
    });
  });
}
