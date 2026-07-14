/// Type-safe JSON-LD builders.
///
/// Each builder returns a [JsonLdSchema] whose [JsonLdSchema.toJson] is a
/// JSON-safe map with `@context`/`@type`, ready for a `JsonLdNode`.
library;

import 'escaping.dart' show SafeUrl;

const String _context = 'https://schema.org';

/// A structured-data schema serialised into `<script type="application/ld+json">`.
abstract interface class JsonLdSchema {
  /// Flat JSON-safe representation.
  Map<String, Object?> toJson();
}

class _MapSchema implements JsonLdSchema {
  const _MapSchema(this._json);

  final Map<String, Object?> _json;

  @override
  Map<String, Object?> toJson() => _json;
}

/// Drops `null` values so optional fields are simply omitted.
Map<String, Object?> _compact(Map<String, Object?> json) {
  json.removeWhere((_, value) => value == null);
  return json;
}

/// Type-safe JSON-LD builders.
abstract final class JsonLd {
  static JsonLdSchema article({
    required String headline,
    required String author,
    DateTime? datePublished,
    SafeUrl? image,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'Article',
      'headline': headline,
      'author': {'@type': 'Person', 'name': author},
      'datePublished': datePublished?.toIso8601String(),
      'image': image?.value,
    }),
  );

  static JsonLdSchema product({
    required String name,
    String? description,
    num? price,
    String? currency,
    SafeUrl? image,
    String? sku,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'Product',
      'name': name,
      'description': description,
      'sku': sku,
      'image': image?.value,
      'offers': price == null
          ? null
          : _compact({
              '@type': 'Offer',
              'price': price,
              'priceCurrency': currency,
            }),
    }),
  );

  static JsonLdSchema breadcrumbList(
    List<({String name, SafeUrl url})> items,
  ) => _MapSchema({
    '@context': _context,
    '@type': 'BreadcrumbList',
    'itemListElement': [
      for (final (index, item) in items.indexed)
        {
          '@type': 'ListItem',
          'position': index + 1,
          'name': item.name,
          'item': item.url.value,
        },
    ],
  });

  static JsonLdSchema webPage({
    required String name,
    SafeUrl? url,
    String? description,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'WebPage',
      'name': name,
      'url': url?.value,
      'description': description,
    }),
  );

  static JsonLdSchema organization({
    required String name,
    SafeUrl? url,
    SafeUrl? logo,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'Organization',
      'name': name,
      'url': url?.value,
      'logo': logo?.value,
    }),
  );

  static JsonLdSchema faq(List<({String question, String answer})> qas) =>
      _MapSchema({
        '@context': _context,
        '@type': 'FAQPage',
        'mainEntity': [
          for (final qa in qas)
            {
              '@type': 'Question',
              'name': qa.question,
              'acceptedAnswer': {'@type': 'Answer', 'text': qa.answer},
            },
        ],
      });

  static JsonLdSchema event({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? location,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'Event',
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'location': location == null
          ? null
          : {'@type': 'Place', 'name': location},
    }),
  );

  static JsonLdSchema recipe({
    required String name,
    List<String> ingredients = const [],
    List<String> steps = const [],
  }) => _MapSchema({
    '@context': _context,
    '@type': 'Recipe',
    'name': name,
    'recipeIngredient': ingredients,
    'recipeInstructions': [
      for (final step in steps) {'@type': 'HowToStep', 'text': step},
    ],
  });

  static JsonLdSchema review({
    required String itemName,
    required num rating,
    num? bestRating,
    String? author,
  }) => _MapSchema(
    _compact({
      '@context': _context,
      '@type': 'Review',
      'itemReviewed': {'@type': 'Thing', 'name': itemName},
      'reviewRating': _compact({
        '@type': 'Rating',
        'ratingValue': rating,
        'bestRating': bestRating,
      }),
      'author': author == null ? null : {'@type': 'Person', 'name': author},
    }),
  );

  /// Arbitrary schema (deliberate escape hatch from type safety).
  static JsonLdSchema raw(Map<String, Object?> json) => _MapSchema(json);
}
