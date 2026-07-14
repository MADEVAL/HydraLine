import 'package:hydraline/hydraline.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('P4-03: scoped style mode', () {
    test('declarative shadow DOM includes style handling', () {
      expect(jsCustomElement, contains('shadow'));
      expect(jsCustomElement, contains('style'));
    });
  });

  group('P4-11/12: DevTools', () {
    test('SsgResult carries pagesWritten and assetsCopied', () {
      const result = SsgResult(pagesWritten: 5, assetsCopied: true);
      expect(result.pagesWritten, 5);
      expect(result.assetsCopied, isTrue);
    });
  });

  group('P4-13: virtual views JS', () {
    test('virtual views module references hydraline-island-segment', () {
      expect(jsVirtualViews, contains('hydraline-island-segment'));
    });

    test('size is under 2 KB', () {
      expect(jsVirtualViews.codeUnits.length, lessThan(2048));
    });
  });

  group('P4-14: zero-overhead (I6/AS1)', () {
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

  group('P4-10: hosting recipes', () {
    test('hosting docs exist and are non-empty', () {
      expect(hostingFirebase, isNotEmpty);
      expect(hostingNetlify, isNotEmpty);
    });
  });
}
