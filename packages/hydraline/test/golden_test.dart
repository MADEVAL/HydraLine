@Tags(['golden'])
library;

import 'dart:io';

import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  test('product card (hybrid) golden - deterministic HTML', () {
    final html = const HtmlSerializer().serialize(_productCard());
    _expectGolden('product_card.html', html);
  });

  test('HTMX fragment golden - no document shell', () {
    final fragment = const HtmlSerializer().serializeFragment(
      _reviewsFragment(),
    );
    expect(fragment, isNot(contains('<!DOCTYPE')));
    expect(fragment, isNot(contains('<html')));
    expect(fragment, isNot(contains('<head')));
    _expectGolden('reviews_fragment.html', fragment);
  });
}

SectionNode _reviewsFragment() => const SectionNode(
  role: SectionRole.section,
  children: [
    HeadingNode(level: 2, children: [TextNode('Reviews')]),
    ListNode(
      ordered: false,
      items: [
        ListItemNode(children: [TextNode('Great phone & value')]),
        ListItemNode(children: [TextNode('Fast <shipping>')]),
      ],
    ),
  ],
);

/// Compares [actual] against `test/goldens/[name]`, normalising line endings to
/// `\n`. Regenerate with `UPDATE_GOLDENS=1` in the environment.
void _expectGolden(String name, String actual) {
  final file = File('test/goldens/$name');
  final normalized = actual.replaceAll('\r\n', '\n');
  if (Platform.environment['UPDATE_GOLDENS'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(normalized);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing golden $name; run with UPDATE_GOLDENS=1 to create it.',
  );
  final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
  expect(normalized, expected);
}

DocumentRootNode _productCard() => DocumentRootNode(
  head: HeadNode(
    children: [
      const MetaNode(charset: 'utf-8'),
      const TitleNode('iPhone 15 - Store'),
      const MetaNode(name: 'description', content: 'Apple iPhone 15, 128 GB'),
      const MetaNode(property: 'og:title', content: 'iPhone 15'),
      const MetaNode(property: 'og:image', content: '/img/iphone15.jpg'),
      LinkNode(
        rel: 'canonical',
        href: SafeUrl.parse('https://store.example/iphone15'),
      ),
    ],
  ),
  body: [
    SectionNode(
      role: SectionRole.main,
      children: [
        const HeadingNode(level: 1, children: [TextNode('iPhone 15')]),
        const ParagraphNode(
          children: [TextNode('A powerful phone with "quotes" & symbols.')],
        ),
        ImageNode(
          src: SafeUrl.parse('/img/iphone15.jpg'),
          alt: 'iPhone 15',
          width: 640,
          height: 480,
        ),
        const ListNode(
          ordered: false,
          items: [
            ListItemNode(children: [TextNode('128 GB')]),
            ListItemNode(children: [TextNode('USB-C')]),
          ],
        ),
        const IslandPlaceholderNode(
          id: 'calculator',
          directive: HydrationDirective.onVisible,
          size: IslandSize(width: 640, height: 480),
          state: {'price': 89990, 'currency': 'RUB'},
          fallback: [
            ParagraphNode(children: [TextNode('Calculator loading…')]),
          ],
        ),
        const HtmxIslandNode(
          id: 'reviews',
          endpoint: '/api/reviews/iphone15',
          fallback: [
            ParagraphNode(children: [TextNode('Loading reviews…')]),
          ],
        ),
      ],
    ),
  ],
);
