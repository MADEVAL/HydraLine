import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  const serializer = HtmlSerializer();
  String head(SeoMeta meta) => serializer.serializeFragment(buildHead(meta));

  group('SeoMeta defaults', () {
    test('charset, viewport and robots defaults', () {
      const meta = SeoMeta(title: 'Home');
      expect(meta.charset, 'utf-8');
      expect(meta.viewport, 'width=device-width, initial-scale=1');
      expect(meta.robots.noindex, isFalse);
      expect(meta.robots.nofollow, isFalse);
    });
  });

  group('buildHead — core meta (SEO-1)', () {
    test('minimal head: charset, title, viewport', () {
      expect(
        head(const SeoMeta(title: 'Home')),
        '<head><meta charset="utf-8"><title>Home</title>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '</head>',
      );
    });

    test('title is escaped', () {
      expect(
        head(const SeoMeta(title: 'A & B')),
        contains('<title>A &amp; B</title>'),
      );
    });

    test('description and canonical', () {
      final html = head(
        SeoMeta(
          title: 'T',
          description: 'Desc',
          canonical: SafeUrl.parse('https://x.example/p'),
        ),
      );
      expect(html, contains('<meta name="description" content="Desc">'));
      expect(
        html,
        contains('<link rel="canonical" href="https://x.example/p">'),
      );
    });

    test('robots meta only when noindex/nofollow set (SEO-6)', () {
      expect(head(const SeoMeta(title: 'T')), isNot(contains('name="robots"')));
      expect(
        head(
          const SeoMeta(
            title: 'T',
            robots: RobotsDirectives(noindex: true, nofollow: true),
          ),
        ),
        contains('<meta name="robots" content="noindex, nofollow">'),
      );
      expect(
        head(
          const SeoMeta(title: 'T', robots: RobotsDirectives(noindex: true)),
        ),
        contains('<meta name="robots" content="noindex">'),
      );
    });
  });

  group('buildHead — Open Graph (SEO-2)', () {
    test('emits present og fields in order', () {
      final html = head(
        SeoMeta(
          title: 'T',
          openGraph: OpenGraph(
            title: 'OG Title',
            type: 'product',
            url: SafeUrl.parse('https://x.example/p'),
            image: SafeUrl.parse('https://x.example/i.jpg'),
            imageWidth: 800,
            imageHeight: 600,
            siteName: 'Store',
          ),
        ),
      );
      expect(html, contains('<meta property="og:title" content="OG Title">'));
      expect(html, contains('<meta property="og:type" content="product">'));
      expect(
        html,
        contains('<meta property="og:url" content="https://x.example/p">'),
      );
      expect(
        html,
        contains(
          '<meta property="og:image" content="https://x.example/i.jpg">',
        ),
      );
      expect(html, contains('<meta property="og:image:width" content="800">'));
      expect(html, contains('<meta property="og:image:height" content="600">'));
      expect(html, contains('<meta property="og:site_name" content="Store">'));
    });
  });

  group('buildHead — Twitter Card (SEO-3)', () {
    test('summary_large_image with fields', () {
      final html = head(
        SeoMeta(
          title: 'T',
          twitter: TwitterCard(
            card: TwitterCardType.summaryLargeImage,
            title: 'TW',
            image: SafeUrl.parse('https://x.example/i.jpg'),
            site: '@store',
          ),
        ),
      );
      expect(
        html,
        contains('<meta name="twitter:card" content="summary_large_image">'),
      );
      expect(html, contains('<meta name="twitter:title" content="TW">'));
      expect(html, contains('<meta name="twitter:site" content="@store">'));
    });
  });

  group('buildHead — i18n and extras (SEO-8)', () {
    test('hreflang alternates', () {
      final html = head(
        SeoMeta(
          title: 'T',
          hreflang: [
            HreflangAlternate(
              hreflang: 'en',
              href: SafeUrl.parse('https://x.example/en'),
            ),
            HreflangAlternate(
              hreflang: 'x-default',
              href: SafeUrl.parse('https://x.example/'),
            ),
          ],
        ),
      );
      expect(
        html,
        contains(
          '<link rel="alternate" href="https://x.example/en" hreflang="en">',
        ),
      );
      expect(
        html,
        contains(
          '<link rel="alternate" href="https://x.example/" hreflang="x-default">',
        ),
      );
    });

    test('extra meta and links', () {
      final html = head(
        SeoMeta(
          title: 'T',
          extraMeta: const [(name: 'theme-color', content: '#fff')],
          extraLinks: [
            (rel: 'manifest', href: SafeUrl.parse('/app.webmanifest')),
          ],
        ),
      );
      expect(html, contains('<meta name="theme-color" content="#fff">'));
      expect(html, contains('<link rel="manifest" href="/app.webmanifest">'));
    });
  });

  group('DocumentRootNode lang (SEO-8)', () {
    test('serializes html lang when provided', () {
      const root = DocumentRootNode(lang: 'ru', body: []);
      expect(
        const HtmlSerializer().serialize(root),
        startsWith('<!DOCTYPE html><html lang="ru">'),
      );
    });

    test('omits lang when null', () {
      const root = DocumentRootNode(body: []);
      expect(
        const HtmlSerializer().serialize(root),
        startsWith('<!DOCTYPE html><html>'),
      );
    });
  });
}
