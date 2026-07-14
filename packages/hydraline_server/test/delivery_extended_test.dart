import 'dart:convert';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:test/test.dart';

void main() {
  group('delivery status codes + headers', () {
    final delivery = const ResponseDelivery();
    const root = DocumentRootNode(body: []);

    test('buffered accepts a custom status code', () async {
      final response = delivery.buffered(root, status: 201);
      expect(response.statusCode, 201);
    });

    test('buffered accepts extra headers', () async {
      final response = delivery.buffered(root, headers: {'X-Custom': 'v'});
      expect(response.headers['x-custom'], 'v');
    });

    test('chunked accepts extra headers', () async {
      final response = delivery.chunked(root, headers: {'X-Custom': 'v2'});
      expect(response.headers['x-custom'], 'v2');
    });
  });

  group('HtmxResponse.toResponse', () {
    test('emits HX-Trigger and HX-Retarget headers', () async {
      final response = const HtmxResponse(
        body: ParagraphNode(children: [TextNode('x')]),
        trigger: HtmxTrigger('event'),
        retarget: '#box',
      ).toResponse();
      expect(response.headers['hx-trigger'], 'event');
      expect(response.headers['hx-retarget'], '#box');
      final body = utf8.decode(
        (await response.read().expand((c) => c).toList()),
      );
      expect(body, '<p>x</p>');
    });

    test('omits headers when options are null', () {
      final response = const HtmxResponse(
        body: ParagraphNode(children: []),
      ).toResponse();
      expect(response.headers['hx-trigger'], isNull);
      expect(response.headers['hx-retarget'], isNull);
    });
  });
}
