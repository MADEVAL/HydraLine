import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('HeadingNode', () {
    test('keeps level and children', () {
      const h = HeadingNode(level: 2, children: [TextNode('Title')]);
      expect(h.level, 2);
      expect(h.children, hasLength(1));
    });

    test('asserts level in 1..6', () {
      expect(
        () => HeadingNode(level: 7, children: const []),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HeadingNode(level: 0, children: const []),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('TextNode', () {
    test('stores raw text and is a leaf', () {
      const t = TextNode('A & <B>');
      expect(t.text, 'A & <B>');
      expect(t.children, isEmpty);
    });
  });

  test('ParagraphNode exposes children', () {
    const p = ParagraphNode(children: [TextNode('x')]);
    expect(p.children, hasLength(1));
  });

  group('AnchorNode', () {
    test('accepts a SafeUrl href plus optional rel', () {
      final a = AnchorNode(
        href: SafeUrl.parse('/about'),
        rel: 'nofollow',
        children: const [TextNode('About')],
      );
      expect(a.href.value, '/about');
      expect(a.rel, 'nofollow');
      expect(a.children, hasLength(1));
    });
  });

  group('ImageNode', () {
    test('carries SafeUrl src, alt and optional size; is a leaf', () {
      final img = ImageNode(
        src: SafeUrl.parse('/img/a.png'),
        alt: 'A',
        width: 640,
        height: 480,
      );
      expect(img.src.value, '/img/a.png');
      expect(img.alt, 'A');
      expect(img.width, 640);
      expect(img.height, 480);
      expect(img.children, isEmpty);
    });
  });

  group('ListNode / ListItemNode', () {
    test('ordered flag and items are the children', () {
      const items = [
        ListItemNode(children: [TextNode('a')]),
        ListItemNode(children: [TextNode('b')]),
      ];
      const list = ListNode(ordered: true, items: items);
      expect(list.ordered, isTrue);
      expect(list.children, items);
    });
  });

  group('SectionNode', () {
    test('covers all semantic roles', () {
      expect(
        SectionRole.values,
        containsAll(<SectionRole>[
          SectionRole.section,
          SectionRole.article,
          SectionRole.nav,
          SectionRole.header,
          SectionRole.footer,
          SectionRole.main,
        ]),
      );
    });

    test('keeps role and children', () {
      const s = SectionNode(
        role: SectionRole.article,
        children: [TextNode('x')],
      );
      expect(s.role, SectionRole.article);
      expect(s.children, hasLength(1));
    });
  });

  group('BlockquoteNode', () {
    test('optional SafeUrl cite', () {
      final q = BlockquoteNode(
        children: const [TextNode('quote')],
        cite: SafeUrl.parse('https://src.example/quote'),
      );
      expect(q.cite!.value, 'https://src.example/quote');
      expect(const BlockquoteNode(children: []).cite, isNull);
    });
  });

  group('PreNode / CodeNode', () {
    test('PreNode wraps children', () {
      const pre = PreNode(children: [CodeNode('x();')]);
      expect(pre.children, hasLength(1));
    });

    test('CodeNode stores text and optional language; is a leaf', () {
      const code = CodeNode('final x = 1;', language: 'dart');
      expect(code.text, 'final x = 1;');
      expect(code.language, 'dart');
      expect(code.children, isEmpty);
    });
  });

  group('TimeNode', () {
    test('stores ISO-8601 dateTime and children', () {
      const t = TimeNode(
        dateTime: '2026-07-14',
        children: [TextNode('Jul 14')],
      );
      expect(t.dateTime, '2026-07-14');
      expect(t.children, hasLength(1));
    });
  });
}
