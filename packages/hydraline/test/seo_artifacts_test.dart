import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

class _ListSource implements SitemapSource {
  _ListSource(this._entries);
  final List<SitemapEntry> _entries;
  @override
  Stream<SitemapEntry> entries() => Stream.fromIterable(_entries);
}

void main() {
  final base = SafeUrl.parse('https://x.example');

  group('Sitemap.generate — single file', () {
    test('emits a urlset with loc/lastmod/changefreq/priority', () async {
      final source = _ListSource([
        SitemapEntry(
          loc: SafeUrl.parse('https://x.example/'),
          lastmod: DateTime.utc(2026, 7, 14),
          changefreq: ChangeFreq.daily,
          priority: 0.8,
        ),
      ]);
      final out = await Sitemap.generate(source, baseUrl: base);
      expect(out.isIndex, isFalse);
      expect(out.files.keys, ['sitemap.xml']);
      final xml = out.files['sitemap.xml']!;
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<urlset'));
      expect(xml, contains('<loc>https://x.example/</loc>'));
      expect(xml, contains('<lastmod>2026-07-14</lastmod>'));
      expect(xml, contains('<changefreq>daily</changefreq>'));
      expect(xml, contains('<priority>0.8</priority>'));
    });

    test('XML-escapes ampersands in loc', () async {
      final source = _ListSource([
        SitemapEntry(loc: SafeUrl.parse('https://x.example/s?a=1&b=2')),
      ]);
      final out = await Sitemap.generate(source, baseUrl: base);
      expect(out.files['sitemap.xml']!, contains('a=1&amp;b=2'));
    });

    test(
      'applies default changefreq and priority when entry omits them',
      () async {
        final source = _ListSource([
          SitemapEntry(loc: SafeUrl.parse('https://x.example/a')),
          SitemapEntry(
            loc: SafeUrl.parse('https://x.example/b'),
            changefreq: ChangeFreq.daily,
            priority: 0.9,
          ),
        ]);
        final xml = (await Sitemap.generate(
          source,
          baseUrl: base,
          changefreq: ChangeFreq.weekly,
          defaultPriority: 0.5,
        )).files['sitemap.xml']!;
        // Entry without explicit values falls back to the defaults.
        expect(xml, contains('<changefreq>weekly</changefreq>'));
        expect(xml, contains('<priority>0.5</priority>'));
        // Explicit per-entry values win over the defaults.
        expect(xml, contains('<changefreq>daily</changefreq>'));
        expect(xml, contains('<priority>0.9</priority>'));
      },
    );

    test('renders hreflang alternates as xhtml:link', () async {
      final source = _ListSource([
        SitemapEntry(
          loc: SafeUrl.parse('https://x.example/en'),
          alternates: [
            (hreflang: 'en', href: SafeUrl.parse('https://x.example/en')),
            (hreflang: 'ru', href: SafeUrl.parse('https://x.example/ru')),
          ],
        ),
      ]);
      final xml = (await Sitemap.generate(
        source,
        baseUrl: base,
      )).files['sitemap.xml']!;
      expect(
        xml,
        contains(
          '<xhtml:link rel="alternate" hreflang="en" href="https://x.example/en"/>',
        ),
      );
    });
  });

  group('Sitemap.generate — autosplit', () {
    test('produces an index + shards past the per-file URL limit', () async {
      final entries = [
        for (var i = 0; i < 5; i++)
          SitemapEntry(loc: SafeUrl.parse('https://x.example/p$i')),
      ];
      final out = await Sitemap.generate(
        _ListSource(entries),
        baseUrl: base,
        maxUrlsPerFile: 2,
      );
      expect(out.isIndex, isTrue);
      expect(out.files.containsKey('sitemap.xml'), isTrue);
      expect(out.files['sitemap.xml']!, contains('<sitemapindex'));
      expect(
        out.files['sitemap.xml']!,
        contains('<loc>https://x.example/sitemap-1.xml</loc>'),
      );
      // 5 urls / 2 per file => 3 shards.
      expect(
        out.files.keys.where((k) => k.startsWith('sitemap-')),
        hasLength(3),
      );
    });
  });

  group('Robots.generate', () {
    test('renders user-agent rules and sitemaps', () {
      final txt = Robots.generate(
        rules: const [
          RobotsRule(userAgent: '*', disallow: ['/admin'], allow: ['/public']),
        ],
        sitemaps: [SafeUrl.parse('https://x.example/sitemap.xml')],
      );
      expect(txt, contains('User-agent: *'));
      expect(txt, contains('Disallow: /admin'));
      expect(txt, contains('Allow: /public'));
      expect(txt, contains('Sitemap: https://x.example/sitemap.xml'));
    });

    test('separates multiple rule groups', () {
      final txt = Robots.generate(
        rules: const [
          RobotsRule(userAgent: '*', disallow: ['/']),
          RobotsRule(userAgent: 'Googlebot', allow: ['/']),
        ],
      );
      expect(txt, contains('User-agent: *'));
      expect(txt, contains('User-agent: Googlebot'));
    });
  });
}
