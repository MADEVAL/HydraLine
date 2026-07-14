import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentNode contract (N1/N5)', () {
    test('leaf nodes expose an empty, const children list', () {
      expect(const TitleNode('T').children, isEmpty);
      expect(const MetaNode(name: 'x', content: 'y').children, isEmpty);
      expect(
        LinkNode(rel: 'canonical', href: SafeUrl.parse('/a')).children,
        isEmpty,
      );
    });

    test('TitleNode keeps its raw text (escaped only on serialization, N2)',
        () {
      expect(const TitleNode('A & B').text, 'A & B');
    });

    test('MetaNode carries name/property/content/charset', () {
      const meta = MetaNode(property: 'og:title', content: 'Home');
      expect(meta.property, 'og:title');
      expect(meta.content, 'Home');
      expect(meta.name, isNull);
    });

    test('LinkNode only accepts a SafeUrl href (N3)', () {
      final link = LinkNode(
        rel: 'alternate',
        href: SafeUrl.parse('https://example.com/en'),
        hreflang: 'en',
      );
      expect(link.href.value, 'https://example.com/en');
      expect(link.hreflang, 'en');
    });

    test('HeadNode exposes its children', () {
      const head = HeadNode(children: [TitleNode('T')]);
      expect(head.children, hasLength(1));
    });

    test('DocumentRootNode children are head followed by body (order, N4)', () {
      const head = HeadNode(children: [TitleNode('T')]);
      const body = [MetaNode(name: 'x')];
      const root = DocumentRootNode(head: head, body: body);
      expect(root.children, [head, ...body]);
    });

    test('DocumentRootNode without head yields body only', () {
      const body = [MetaNode(name: 'x')];
      const root = DocumentRootNode(body: body);
      expect(root.children, body);
    });

    test('nodes are DocumentNode subtypes (sealed hierarchy)', () {
      expect(const TitleNode('T'), isA<DocumentNode>());
      expect(const DocumentRootNode(body: []), isA<DocumentNode>());
    });
  });
}
