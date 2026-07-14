/// Pure-Dart page content (surface B), shared by the SSR server
/// (`bin/server.dart`) and the static build (`bin/build.dart`).
///
/// One source of truth per page: the same [DocumentNode] trees stream from
/// the server at request time and compile to static HTML at build time.
library;

import 'package:hydraline/hydraline.dart';

const String origin = 'https://demo.example';

/// `/` - the shop landing page.
DocumentNode homePage() => DocumentRootNode(
  lang: 'en',
  head: buildHead(
    SeoMeta(
      title: 'Hydraline Demo Shop',
      description: 'A Flutter Web shop with real, crawlable HTML.',
      canonical: SafeUrl.parse('$origin/'),
      openGraph: OpenGraph(
        title: 'Hydraline Demo Shop',
        type: 'website',
        image: SafeUrl.parse('$origin/img/espresso.jpg'),
      ),
    ),
  ),
  body: [
    SectionNode(
      role: SectionRole.main,
      children: [
        const HeadingNode(
          level: 1,
          children: [TextNode('Hydraline Demo Shop')],
        ),
        const ParagraphNode(
          children: [
            TextNode('Static HTML loads instantly; islands hydrate on demand.'),
          ],
        ),
        AnchorNode(
          href: SafeUrl.parse('/product/espresso'),
          children: const [TextNode('Espresso')],
        ),
        AnchorNode(
          href: SafeUrl.parse('/product/grinder'),
          children: const [TextNode('Grinder')],
        ),
      ],
    ),
  ],
);

/// `/product/:id` - a hybrid product page with a Flutter island and a
/// vanilla FAQ accordion.
DocumentNode productPage(String id) => DocumentRootNode(
  lang: 'en',
  head: buildHead(
    SeoMeta(
      title: 'Product - $id',
      description: 'The $id, part of the Hydraline demo shop.',
      canonical: SafeUrl.parse('$origin/product/$id'),
      openGraph: OpenGraph(
        title: 'Product - $id',
        type: 'product',
        image: SafeUrl.parse('$origin/img/$id.jpg'),
      ),
    ),
    structuredData: [JsonLd.product(name: id, price: 249, currency: 'EUR')],
  ),
  body: [
    SectionNode(
      role: SectionRole.main,
      children: [
        HeadingNode(level: 1, children: [TextNode('Product: $id')]),
        ImageNode(
          src: SafeUrl.parse('/img/$id.jpg'),
          alt: 'Photo of $id',
          width: 800,
          height: 600,
        ),
        // Level 2: Flutter island, engine loads when scrolled into view.
        IslandPlaceholderNode(
          id: 'calculator-$id',
          directive: HydrationDirective.onVisible,
          size: const IslandSize(width: 640, height: 320),
          state: const {'price': 249},
        ),
        // Level 1: vanilla accordion, no Flutter engine involved.
        VanillaIslandNode(
          id: 'faq-$id',
          kind: 'accordion',
          children: const [
            DetailsNode(
              summary: SummaryNode(children: [TextNode('Is shipping free?')]),
              children: [
                ParagraphNode(children: [TextNode('Yes, worldwide.')]),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
