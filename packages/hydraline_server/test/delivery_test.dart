import 'dart:convert';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:test/test.dart';

void main() {
  const serializer = HtmlSerializer();
  const root = DocumentRootNode(
    body: [
      ParagraphNode(children: [TextNode('Hello')]),
    ],
  );

  group('ResponseDelivery', () {
    final delivery = const ResponseDelivery();

    test('buffered returns a single complete HTML response', () async {
      final response = delivery.buffered(root);
      expect(response.statusCode, 200);
      final body = await response.read().toList();
      final html = utf8.decode(body.expand((c) => c).toList());
      expect(html, serializer.serialize(root));
    });

    test('chunked returns a streaming response', () async {
      final response = delivery.chunked(root);
      expect(response.statusCode, 200);
      final chunks = <String>[];
      await for (final chunk in response.read().transform(utf8.decoder)) {
        chunks.add(chunk);
      }
      expect(chunks.join(), serializer.serialize(root));
    });

    test('SER4/I3: bytes(buffered) == bytes(concat(chunks))', () async {
      final bufferedBody = utf8.decode(
        (await delivery.buffered(root).read().expand((c) => c).toList()),
      );
      final chunkedBody = <int>[];
      await for (final chunk in delivery.chunked(root).read()) {
        chunkedBody.addAll(chunk);
      }
      expect(utf8.decode(chunkedBody), bufferedBody); // I3 proof
    });
  });

  group('HTMX helpers', () {
    test('renderFragment returns HTML fragment without doctype', () async {
      const node = ParagraphNode(children: [TextNode('x')]);
      final response = Htmx.renderFragment(node);
      final body = utf8.decode(
        (await response.read().expand((c) => c).toList()),
      );
      expect(body, '<p>x</p>');
      expect(body, isNot(contains('<!DOCTYPE')));
    });

    test('HtmxResponse carries trigger/retarget/reswap headers', () {
      const response = HtmxResponse(
        body: ParagraphNode(children: []),
        trigger: HtmxTrigger('showMessage'),
        retarget: '#target',
        reswap: 'outerHTML',
      );
      expect(response.trigger!.value, 'showMessage');
      expect(response.retarget, '#target');
      expect(response.reswap, 'outerHTML');
    });
  });
}
