import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

/// The zero-overhead guarantee: pages without Flutter islands never
/// reference the Flutter engine.
void main() {
  group('zero-overhead guarantee', () {
    test('document without flutter islands omits flutter_bootstrap.js', () {
      final root = DocumentRootNode(
        head: const HeadNode(children: [TitleNode('T')]),
        body: const [
          ParagraphNode(children: [TextNode('x')]),
        ],
      );
      final html = const HtmlSerializer().serialize(root);
      expect(html, isNot(contains('flutter_bootstrap.js')));
    });

    test('hybrid page with a vanilla island also omits flutter JS', () {
      const root = DocumentRootNode(
        body: [
          VanillaIslandNode(
            id: 'tabs1',
            kind: 'tabs',
            children: [TextNode('x')],
          ),
        ],
      );
      final html = const HtmlSerializer().serialize(root);
      expect(html, isNot(contains('flutter_bootstrap')));
    });
  });
}
