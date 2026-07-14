/// `sitemap.xml` generation with hreflang alternates and index auto-split.
library;

import 'escaping.dart' show SafeUrl;

/// `changefreq` values.
enum ChangeFreq { always, hourly, daily, weekly, monthly, yearly, never }

/// A single sitemap URL entry.
class SitemapEntry {
  const SitemapEntry({
    required this.loc,
    this.lastmod,
    this.changefreq,
    this.priority,
    this.alternates = const [],
  });

  final SafeUrl loc;
  final DateTime? lastmod;
  final ChangeFreq? changefreq;
  final double? priority;
  final List<({String hreflang, SafeUrl href})> alternates;
}

/// A source of sitemap entries: route manifest, DB provider, etc.
abstract interface class SitemapSource {
  Stream<SitemapEntry> entries();
}

/// The generation result: one file, or an index plus shards.
class SitemapOutput {
  const SitemapOutput({required this.files, required this.isIndex});

  /// File name → XML content.
  final Map<String, String> files;

  /// `true` when the output was split into an index + shards.
  final bool isIndex;
}

/// Sitemap generator.
abstract final class Sitemap {
  /// Google's hard limits per sitemap file.
  static const int _defaultMaxUrls = 50000;
  static const int _defaultMaxBytes = 50 * 1024 * 1024;

  static const String _header = '<?xml version="1.0" encoding="UTF-8"?>';
  static const String _urlsetOpen =
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
      'xmlns:xhtml="http://www.w3.org/1999/xhtml">';

  /// Auto-splits into a `sitemap-index` when a shard would exceed
  /// [maxUrlsPerFile] URLs or [maxBytesPerFile] bytes.
  static Future<SitemapOutput> generate(
    SitemapSource source, {
    required SafeUrl baseUrl,
    int maxUrlsPerFile = _defaultMaxUrls,
    int maxBytesPerFile = _defaultMaxBytes,
  }) async {
    final shards = <String>[];
    final current = StringBuffer();
    var count = 0;

    void openShard() {
      current
        ..clear()
        ..write(_header)
        ..write(_urlsetOpen);
      count = 0;
    }

    void closeShard() {
      current.write('</urlset>');
      shards.add(current.toString());
    }

    openShard();
    await for (final entry in source.entries()) {
      final url = _url(entry);
      final wouldExceedBytes =
          current.length + url.length + '</urlset>'.length > maxBytesPerFile;
      if (count > 0 && (count >= maxUrlsPerFile || wouldExceedBytes)) {
        closeShard();
        openShard();
      }
      current.write(url);
      count++;
    }
    closeShard();

    if (shards.length == 1) {
      return SitemapOutput(
        files: {'sitemap.xml': shards.first},
        isIndex: false,
      );
    }

    final files = <String, String>{};
    final index = StringBuffer()
      ..write(_header)
      ..write(
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
      );
    for (final (i, shard) in shards.indexed) {
      final name = 'sitemap-${i + 1}.xml';
      files[name] = shard;
      final loc = _joinBase(baseUrl, name);
      index.write('<sitemap><loc>${_escape(loc)}</loc></sitemap>');
    }
    index.write('</sitemapindex>');
    files['sitemap.xml'] = index.toString();
    return SitemapOutput(files: files, isIndex: true);
  }

  static String _url(SitemapEntry entry) {
    final buffer = StringBuffer('<url>')
      ..write('<loc>${_escape(entry.loc.value)}</loc>');
    final lastmod = entry.lastmod;
    if (lastmod != null) {
      buffer.write('<lastmod>${_date(lastmod)}</lastmod>');
    }
    final changefreq = entry.changefreq;
    if (changefreq != null) {
      buffer.write('<changefreq>${changefreq.name}</changefreq>');
    }
    final priority = entry.priority;
    if (priority != null) {
      buffer.write('<priority>${_priority(priority)}</priority>');
    }
    for (final alternate in entry.alternates) {
      buffer.write(
        '<xhtml:link rel="alternate" hreflang="${_escape(alternate.hreflang)}" '
        'href="${_escape(alternate.href.value)}"/>',
      );
    }
    buffer.write('</url>');
    return buffer.toString();
  }

  static String _date(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _priority(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return clamped.toStringAsFixed(1);
  }

  static String _joinBase(SafeUrl base, String name) {
    final b = base.value;
    return b.endsWith('/') ? '$b$name' : '$b/$name';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
