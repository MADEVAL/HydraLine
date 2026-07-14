import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('scoped style mode', () {
    test('declarative shadow DOM includes style handling', () {
      expect(jsCustomElement, contains('shadow'));
      expect(jsCustomElement, contains('style'));
    });
  });

  group('DevTools', () {
    test('SsgResult carries pagesWritten and assetsCopied', () {
      const result = SsgResult(pagesWritten: 5, assetsCopied: true);
      expect(result.pagesWritten, 5);
      expect(result.assetsCopied, isTrue);
    });
  });

  group('virtual views JS', () {
    test('virtual views module references hydraline-island-segment', () {
      expect(jsVirtualViews, contains('hydraline-island-segment'));
    });

    test('size is under 4 KB (pretty, unminified)', () {
      expect(jsVirtualViews.codeUnits.length, lessThan(4096));
    });
  });

  group('zero-overhead', () {
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

  group('hosting recipes', () {
    test('hosting docs exist and are non-empty', () {
      expect(hostingFirebase, isNotEmpty);
      expect(hostingNetlify, isNotEmpty);
    });
  });
}
