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

    test('article with image', () {
      final json = JsonLd.article(
        headline: 'Hello',
        author: 'Jane',
        image: SafeUrl.parse('https://x/img.jpg'),
      ).toJson();
      expect(json['image'], 'https://x/img.jpg');
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

    test('product with image', () {
      final json = JsonLd.product(
        name: 'Widget',
        image: SafeUrl.parse('https://x/img.jpg'),
      ).toJson();
      expect(json['image'], 'https://x/img.jpg');
      expect(json.containsKey('offers'), isFalse);
    });

    test('product with description', () {
      final json = JsonLd.product(
        name: 'Widget',
        description: 'A great widget',
      ).toJson();
      expect(json['description'], 'A great widget');
    });

    test('webPage with all params', () {
      final json = JsonLd.webPage(
        name: 'Home',
        url: SafeUrl.parse('https://x/'),
        description: 'Home page',
      ).toJson();
      expect(json['@type'], 'WebPage');
      expect(json['name'], 'Home');
      expect(json['url'], 'https://x/');
      expect(json['description'], 'Home page');
    });

    test('organization with logo and url', () {
      final json = JsonLd.organization(
        name: 'Acme',
        url: SafeUrl.parse('https://acme.com'),
        logo: SafeUrl.parse('https://acme.com/logo.png'),
      ).toJson();
      expect(json['@type'], 'Organization');
      expect(json['name'], 'Acme');
      expect(json['url'], 'https://acme.com');
      expect(json['logo'], 'https://acme.com/logo.png');
    });

    test('event', () {
      final json = JsonLd.event(
        name: 'Conference',
        startDate: DateTime.utc(2026, 7, 14),
        endDate: DateTime.utc(2026, 7, 16),
        location: 'Convention Center',
      ).toJson();
      expect(json['@type'], 'Event');
      expect(json['name'], 'Conference');
      expect(json['startDate'], '2026-07-14T00:00:00.000Z');
      expect(json['endDate'], '2026-07-16T00:00:00.000Z');
      expect((json['location']! as Map)['@type'], 'Place');
      expect((json['location']! as Map)['name'], 'Convention Center');
    });

    test('event without optional fields', () {
      final json = JsonLd.event(
        name: 'Meeting',
        startDate: DateTime.utc(2026, 1, 1),
      ).toJson();
      expect(json['@type'], 'Event');
      expect(json.containsKey('endDate'), isFalse);
      expect(json.containsKey('location'), isFalse);
    });

    test('recipe', () {
      final json = JsonLd.recipe(
        name: 'Pancakes',
        ingredients: ['flour', 'milk'],
        steps: ['mix', 'cook'],
      ).toJson();
      expect(json['@type'], 'Recipe');
      expect(json['name'], 'Pancakes');
      expect(json['recipeIngredient'], ['flour', 'milk']);
      final instructions = json['recipeInstructions']! as List;
      expect(instructions, hasLength(2));
      expect((instructions[0] as Map)['@type'], 'HowToStep');
    });

    test('review without bestRating', () {
      final json = JsonLd.review(itemName: 'Product', rating: 4).toJson();
      expect(json['@type'], 'Review');
      expect((json['reviewRating']! as Map)['ratingValue'], 4);
    });

    test('review without author', () {
      final json = JsonLd.review(itemName: 'Product', rating: 3).toJson();
      expect(json['@type'], 'Review');
      expect(json.containsKey('author'), isFalse);
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
