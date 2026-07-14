// Hydraline core example: build a semantic document, serialize it three ways
// and generate the SEO artifacts (sitemap.xml, robots.txt, validation).
//
// Run with: dart run example/main.dart
import 'dart:io';

import 'package:hydraline/hydraline.dart';

Future<void> main() async {
  // 1. Build a typed, immutable document tree. Text is stored raw and escaped
  //    only at serialization time; URLs must pass the SafeUrl allowlist.
  final page = DocumentRootNode(
    lang: 'en',
    head: buildHead(
      SeoMeta(
        title: 'Espresso Machine - Barista Shop',
        description: 'Compact 15-bar espresso machine with a milk frother.',
        canonical: SafeUrl.parse('https://shop.example/espresso'),
        openGraph: OpenGraph(
          title: 'Espresso Machine',
          type: 'product',
          image: SafeUrl.parse('https://shop.example/img/espresso-og.jpg'),
        ),
        twitter: const TwitterCard(card: TwitterCardType.summaryLargeImage),
      ),
      structuredData: [
        JsonLd.product(
          name: 'Espresso Machine',
          price: 249,
          currency: 'EUR',
          image: SafeUrl.parse('https://shop.example/img/espresso.jpg'),
        ),
      ],
    ),
    body: [
      SectionNode(
        role: SectionRole.main,
        children: [
          const HeadingNode(level: 1, children: [TextNode('Espresso Machine')]),
          const ParagraphNode(
            children: [
              TextNode('Real HTML for crawlers - <escaped> & safe by default.'),
            ],
          ),
          ImageNode(
            src: SafeUrl.parse('/img/espresso.jpg'),
            alt: 'Espresso machine, front view',
            width: 800,
            height: 600,
          ),
          // A Flutter island (level 2): hydrates when scrolled into view.
          const IslandPlaceholderNode(
            id: 'price-calculator',
            directive: HydrationDirective.onVisible,
            size: IslandSize(width: 640, height: 320),
            state: {'price': 249, 'currency': 'EUR'},
            fallback: [
              ParagraphNode(children: [TextNode('Loading calculator…')]),
            ],
          ),
          // An HTMX island (level 1): the server swaps in an HTML fragment.
          const HtmxIslandNode(
            id: 'reviews',
            endpoint: '/api/reviews/espresso',
            trigger: 'revealed',
            fallback: [
              ParagraphNode(children: [TextNode('Loading reviews…')]),
            ],
          ),
        ],
      ),
    ],
  );

  const serializer = HtmlSerializer();

  // 2a. Buffered - a complete HTML string (bots, SSG files).
  final html = serializer.serialize(page);
  stdout
    ..writeln('--- buffered (${html.length} chars) ---')
    ..writeln(html);

  // 2b. Streaming - same bytes, delivered progressively (SSR).
  final chunks = await serializer.serializeToStream(page).toList();
  assert(chunks.join() == html, 'stream must equal buffered output');
  stdout.writeln('--- streamed as ${chunks.length} chunks, identical bytes');

  // 3. SEO artifacts.
  final sitemap = await Sitemap.generate(
    _Routes(),
    baseUrl: SafeUrl.parse('https://shop.example'),
    changefreq: ChangeFreq.weekly,
    defaultPriority: 0.5,
  );
  stdout
    ..writeln('--- sitemap.xml ---')
    ..writeln(sitemap.files['sitemap.xml']);

  final robots = Robots.generate(
    rules: const [
      RobotsRule(userAgent: '*', disallow: ['/app/']),
    ],
    sitemaps: [SafeUrl.parse('https://shop.example/sitemap.xml')],
  );
  stdout
    ..writeln('--- robots.txt ---')
    ..writeln(robots);

  // 4. Validate the document (missing alt, duplicate canonicals, …).
  final issues = const SeoValidator().validate(page);
  stdout.writeln('--- validation: ${issues.length} issue(s) ---');
  for (final issue in issues) {
    stdout.writeln(issue);
  }
}

class _Routes implements SitemapSource {
  @override
  Stream<SitemapEntry> entries() => Stream.fromIterable([
    SitemapEntry(loc: SafeUrl.parse('https://shop.example/'), priority: 1.0),
    SitemapEntry(loc: SafeUrl.parse('https://shop.example/espresso')),
  ]);
}
