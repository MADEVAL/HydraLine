// Hydraline — API contract (L4) · packages/hydraline/api/metadata.dart
//
// Metadata, Open Graph, Twitter Card, and JSON-LD structured data.
//
// ignore_for_file: unused_element

import 'escaping.dart' show SafeUrl;

/// Robots directives for a specific route.
class RobotsDirectives {
  const RobotsDirectives({this.noindex = false, this.nofollow = false});
  final bool noindex;
  final bool nofollow;
}

class OpenGraph {
  const OpenGraph({
    this.title,
    this.description,
    this.type, // website | article | product | ...
    this.url,
    this.image,
    this.imageAlt,
    this.imageWidth,
    this.imageHeight,
    this.imageSecureUrl,
    this.locale,
    this.siteName,
  });
  final String? title;
  final String? description;
  final String? type;
  final SafeUrl? url;
  final SafeUrl? image;
  final String? imageAlt;
  final int? imageWidth;
  final int? imageHeight;
  final SafeUrl? imageSecureUrl;
  final String? locale;
  final String? siteName;
}

enum TwitterCardType { summary, summaryLargeImage }

class TwitterCard {
  const TwitterCard({
    required this.card,
    this.title,
    this.description,
    this.image,
    this.site,
    this.creator,
  });
  final TwitterCardType card;
  final String? title;
  final String? description;
  final SafeUrl? image;
  final String? site;
  final String? creator;
}

class HreflangAlternate {
  const HreflangAlternate({required this.hreflang, required this.href});
  final String hreflang; // e.g. en, ru, x-default
  final SafeUrl href;
}

/// Complete per-route metadata model.
class SeoMeta {
  const SeoMeta({
    required this.title,
    this.description,
    this.canonical,
    this.robots = const RobotsDirectives(),
    this.openGraph,
    this.twitter,
    this.lang,
    this.charset = 'utf-8',
    this.viewport = 'width=device-width, initial-scale=1',
    this.hreflang = const [],
    this.extraMeta = const [],
    this.extraLinks = const [],
  });
  final String title; // validator: length
  final String? description;
  final SafeUrl? canonical; // absolute URL
  final RobotsDirectives robots;
  final OpenGraph? openGraph;
  final TwitterCard? twitter;
  final String? lang;
  final String charset;
  final String viewport;
  final List<HreflangAlternate> hreflang;
  final List<({String name, String content})> extraMeta;
  final List<({String rel, SafeUrl href})> extraLinks;
}

// ── JSON-LD ────────────────────────────────────────────────────────────────────

/// Base contract for structured data schema → `<script type="application/ld+json">`.
abstract interface class JsonLdSchema {
  /// A flat JSON-safe representation.
  Map<String, Object?> toJson();
}

/// Type-safe builders (signatures shortened to key fields).
abstract final class JsonLd {
  static JsonLdSchema article({required String headline, required String author, DateTime? datePublished, SafeUrl? image}) => throw UnimplementedError();
  static JsonLdSchema product({required String name, String? description, num? price, String? currency, SafeUrl? image, String? sku}) => throw UnimplementedError();
  static JsonLdSchema breadcrumbList(List<({String name, SafeUrl url})> items) => throw UnimplementedError();
  static JsonLdSchema webPage({required String name, SafeUrl? url, String? description}) => throw UnimplementedError();
  static JsonLdSchema organization({required String name, SafeUrl? url, SafeUrl? logo}) => throw UnimplementedError();
  static JsonLdSchema faq(List<({String question, String answer})> qas) => throw UnimplementedError();
  static JsonLdSchema event({required String name, required DateTime startDate, DateTime? endDate, String? location}) => throw UnimplementedError();
  static JsonLdSchema recipe({required String name, List<String> ingredients, List<String> steps}) => throw UnimplementedError();
  static JsonLdSchema review({required String itemName, required num rating, num? bestRating, String? author}) => throw UnimplementedError();

  /// Arbitrary schema (intentional escape hatch from type safety).
  static JsonLdSchema raw(Map<String, Object?> json) => throw UnimplementedError();
}
