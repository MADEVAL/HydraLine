import 'dart:convert';

import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('JsonLd builders', () {
    test('article', () {
      final json = JsonLd.article(
        headline: 'Hello',
        author: 'Jane',
        datePublished: DateTime.utc(2026, 7, 14),
      ).toJson();
      expect(json['@context'], 'https://schema.org');
      expect(json['@type'], 'Article');
      expect(json['headline'], 'Hello');
      expect((json['author']! as Map)['name'], 'Jane');
      expect(json['datePublished'], '2026-07-14T00:00:00.000Z');
    });

    test('product with offer', () {
      final json = JsonLd.product(
        name: 'iPhone',
        price: 999,
        currency: 'USD',
        sku: 'IP15',
      ).toJson();
      expect(json['@type'], 'Product');
      expect(json['name'], 'iPhone');
      expect(json['sku'], 'IP15');
      final offers = json['offers']! as Map;
      expect(offers['@type'], 'Offer');
      expect(offers['price'], 999);
      expect(offers['priceCurrency'], 'USD');
    });

    test('breadcrumbList positions items', () {
      final json = JsonLd.breadcrumbList([
        (name: 'Home', url: SafeUrl.parse('https://x/')),
        (name: 'Blog', url: SafeUrl.parse('https://x/blog')),
      ]).toJson();
      expect(json['@type'], 'BreadcrumbList');
      final items = json['itemListElement']! as List;
      expect(items, hasLength(2));
      expect((items[0] as Map)['position'], 1);
      expect((items[1] as Map)['position'], 2);
      expect((items[1] as Map)['name'], 'Blog');
    });

    test('faq maps questions to answers', () {
      final json = JsonLd.faq([(question: 'Q1?', answer: 'A1')]).toJson();
      expect(json['@type'], 'FAQPage');
      final entities = json['mainEntity']! as List;
      expect((entities[0] as Map)['@type'], 'Question');
      expect((entities[0] as Map)['name'], 'Q1?');
      expect(((entities[0] as Map)['acceptedAnswer'] as Map)['text'], 'A1');
    });

    test('review with rating', () {
      final json = JsonLd.review(
        itemName: 'iPhone',
        rating: 4.5,
        bestRating: 5,
        author: 'Jane',
      ).toJson();
      expect(json['@type'], 'Review');
      expect((json['reviewRating']! as Map)['ratingValue'], 4.5);
      expect((json['reviewRating']! as Map)['bestRating'], 5);
    });

    test('raw returns the given map', () {
      final json = JsonLd.raw({'@type': 'Thing', 'name': 'X'}).toJson();
      expect(json['@type'], 'Thing');
      expect(json['name'], 'X');
    });
  });

  group('JsonLdNode serialization (XSS-safe)', () {
    test('emits an ld+json script', () {
      final node = JsonLdNode(JsonLd.webPage(name: 'Home').toJson());
      final html = const HtmlSerializer().serializeFragment(node);
      expect(html, startsWith('<script type="application/ld+json">'));
      expect(html, endsWith('</script>'));
      final jsonText = html
          .replaceFirst('<script type="application/ld+json">', '')
          .replaceFirst('</script>', '');
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;
      expect(decoded['@type'], 'WebPage');
    });

    test('escapes < > & to prevent </script> breakout', () {
      final node = JsonLdNode(
        JsonLd.raw({
          'name': '</script><script>alert(1)</script> & more',
        }).toJson(),
      );
      final html = const HtmlSerializer().serializeFragment(node);
      expect(html, isNot(contains('</script><script>')));
      expect(html, contains(r'\u003c'));
      // The single trailing </script> is the real closing tag.
      expect('</script>'.allMatches(html).length, 1);
    });
  });

  test('buildHead appends structured data scripts', () {
    final head = buildHead(
      const SeoMeta(title: 'Home'),
      structuredData: [JsonLd.webPage(name: 'Home')],
    );
    final html = const HtmlSerializer().serializeFragment(head);
    expect(html, contains('<script type="application/ld+json">'));
    expect(html, contains('"WebPage"'));
  });
}
