/// Route metadata: Open Graph, Twitter Card, hreflang and `<head>` rendering
/// (ARCHITECTURE.md §7.1; SEO-1/2/3/8).
library;

import 'document_node.dart';
import 'escaping.dart' show SafeUrl;
import 'structured_data.dart' show JsonLdSchema;

/// Robots directives for a route.
class RobotsDirectives {
  const RobotsDirectives({this.noindex = false, this.nofollow = false});

  final bool noindex;
  final bool nofollow;

  /// The `content` value, or `null` when both flags are false (omit the tag).
  String? get content {
    if (!noindex && !nofollow) {
      return null;
    }
    return [if (noindex) 'noindex', if (nofollow) 'nofollow'].join(', ');
  }
}

/// Open Graph metadata (full set).
class OpenGraph {
  const OpenGraph({
    this.title,
    this.description,
    this.type,
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

/// Twitter Card type.
enum TwitterCardType {
  summary,
  summaryLargeImage;

  /// The `twitter:card` attribute value.
  String get value => switch (this) {
    TwitterCardType.summary => 'summary',
    TwitterCardType.summaryLargeImage => 'summary_large_image',
  };
}

/// Twitter Card metadata.
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

/// An hreflang alternate (`en`, `ru`, `x-default`, …).
class HreflangAlternate {
  const HreflangAlternate({required this.hreflang, required this.href});

  final String hreflang;
  final SafeUrl href;
}

/// The full metadata model of a route.
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

  final String title;
  final String? description;
  final SafeUrl? canonical;
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

/// Builds a deterministic `<head>` from [meta] (SER2).
///
/// Order: charset, title, viewport, description, robots, canonical, Open Graph,
/// Twitter Card, hreflang alternates, extra `<meta>`, extra `<link>`,
/// structured-data scripts.
HeadNode buildHead(
  SeoMeta meta, {
  List<JsonLdSchema> structuredData = const [],
}) {
  final children = <DocumentNode>[
    MetaNode(charset: meta.charset),
    TitleNode(meta.title),
    MetaNode(name: 'viewport', content: meta.viewport),
  ];

  final description = meta.description;
  if (description != null) {
    children.add(MetaNode(name: 'description', content: description));
  }

  final robots = meta.robots.content;
  if (robots != null) {
    children.add(MetaNode(name: 'robots', content: robots));
  }

  final canonical = meta.canonical;
  if (canonical != null) {
    children.add(LinkNode(rel: 'canonical', href: canonical));
  }

  final openGraph = meta.openGraph;
  if (openGraph != null) {
    _addOpenGraph(openGraph, children);
  }

  final twitter = meta.twitter;
  if (twitter != null) {
    _addTwitter(twitter, children);
  }

  for (final alternate in meta.hreflang) {
    children.add(
      LinkNode(
        rel: 'alternate',
        href: alternate.href,
        hreflang: alternate.hreflang,
      ),
    );
  }

  for (final extra in meta.extraMeta) {
    children.add(MetaNode(name: extra.name, content: extra.content));
  }

  for (final extra in meta.extraLinks) {
    children.add(LinkNode(rel: extra.rel, href: extra.href));
  }

  for (final schema in structuredData) {
    children.add(JsonLdNode(schema.toJson()));
  }

  return HeadNode(children: children);
}

void _addOpenGraph(OpenGraph og, List<DocumentNode> out) {
  void property(String property, String? content) {
    if (content != null) {
      out.add(MetaNode(property: property, content: content));
    }
  }

  property('og:title', og.title);
  property('og:description', og.description);
  property('og:type', og.type);
  property('og:url', og.url?.value);
  property('og:image', og.image?.value);
  property('og:image:alt', og.imageAlt);
  property('og:image:width', og.imageWidth?.toString());
  property('og:image:height', og.imageHeight?.toString());
  property('og:image:secure_url', og.imageSecureUrl?.value);
  property('og:locale', og.locale);
  property('og:site_name', og.siteName);
}

void _addTwitter(TwitterCard twitter, List<DocumentNode> out) {
  void meta(String name, String? content) {
    if (content != null) {
      out.add(MetaNode(name: name, content: content));
    }
  }

  meta('twitter:card', twitter.card.value);
  meta('twitter:title', twitter.title);
  meta('twitter:description', twitter.description);
  meta('twitter:image', twitter.image?.value);
  meta('twitter:site', twitter.site);
  meta('twitter:creator', twitter.creator);
}
