import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  const s = HtmlSerializer();

  final root = DocumentRootNode(
    head: const HeadNode(children: [TitleNode('T')]),
    body: [
      const HeadingNode(level: 1, children: [TextNode('A & B')]),
      const ParagraphNode(children: [TextNode('one')]),
      AnchorNode(href: SafeUrl.parse('/x'), children: const [TextNode('two')]),
    ],
  );

  test('concat(serializeToStream) == serialize', () async {
    final chunks = await s.serializeToStream(root).toList();
    expect(chunks.join(), s.serialize(root));
  });

  test('streams progressively and in order (>1 chunk, shell first)', () async {
    final chunks = await s.serializeToStream(root).toList();
    expect(chunks.length, greaterThan(1));
    expect(chunks.first, startsWith('<!DOCTYPE html><html><head>'));
    expect(chunks.first, contains('<body>'));
    expect(chunks.last, '</body></html>');
    // In-order: the heading chunk precedes the paragraph chunk.
    final headingIndex = chunks.indexWhere((c) => c.contains('<h1>'));
    final paragraphIndex = chunks.indexWhere((c) => c.contains('<p>'));
    expect(headingIndex, lessThan(paragraphIndex));
  });

  test('holds for a non-root fragment node', () async {
    const node = ParagraphNode(children: [TextNode('x & y')]);
    final chunks = await s.serializeToStream(node).toList();
    expect(chunks.join(), s.serializeFragment(node));
  });
}
