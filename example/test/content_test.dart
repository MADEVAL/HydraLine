import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_example/content.dart';

void main() {
  const serializer = HtmlSerializer();

  group('homePage', () {
    final html = serializer.serialize(homePage());

    test('carries a title, description and canonical', () {
      expect(html, contains('<title>Hydraline Demo Shop</title>'));
      expect(html, contains('name="description"'));
      expect(html, contains('rel="canonical"'));
    });

    test('carries Open Graph tags (audit-clean)', () {
      expect(html, contains('property="og:title"'));
      expect(html, contains('property="og:image"'));
    });

    test('has an h1 and product links', () {
      expect(html, contains('<h1>Hydraline Demo Shop</h1>'));
      expect(html, contains('href="/product/espresso"'));
      expect(html, contains('href="/product/grinder"'));
    });

    test('passes the SEO audit with no errors and no warnings', () {
      final report = Audit.auditHtml(html);
      expect(report.exitCode, 0, reason: report.issues.join('\n'));
      expect(report.issues, isEmpty, reason: report.issues.join('\n'));
    });
  });

  group('productPage', () {
    final html = serializer.serialize(productPage('espresso'));

    test('renders the product heading and image', () {
      expect(html, contains('<h1>Product: espresso</h1>'));
      expect(html, contains('alt="Photo of espresso"'));
    });

    test('contains the Flutter island with reserved size', () {
      expect(html, contains('<hydraline-island id="calculator-espresso"'));
      expect(html, contains('data-size="640,320"'));
    });

    test('contains a working vanilla accordion island', () {
      expect(html, contains('data-island="accordion"'));
      expect(html, contains('<details>'));
    });

    test('passes the SEO audit with no errors and no warnings', () {
      final report = Audit.auditHtml(html);
      expect(report.exitCode, 0, reason: report.issues.join('\n'));
      expect(report.issues, isEmpty, reason: report.issues.join('\n'));
    });
  });
}
