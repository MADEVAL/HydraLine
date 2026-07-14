import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('UnsafeHtmlNode (S3)', () {
    test('stores raw HTML, is a leaf, sanitizer null by default', () {
      const node = UnsafeHtmlNode('<b>x</b>');
      expect(node.rawHtml, '<b>x</b>');
      expect(node.sanitizer, isNull);
      expect(node.children, isEmpty);
    });

    test('sanitize() returns raw HTML when no sanitizer is given', () {
      const node = UnsafeHtmlNode('<b>x</b>');
      expect(node.sanitize(), '<b>x</b>');
    });

    test('sanitize() applies the provided sanitizer', () {
      final node = UnsafeHtmlNode(
        '<script>x</script>',
        sanitizer: (raw) => raw.replaceAll(RegExp('</?script>'), ''),
      );
      expect(node.sanitize(), 'x');
    });
  });

  group('SeoValidator — unsafe HTML warning (S3)', () {
    test('warns on an UnsafeHtmlNode without a sanitizer', () {
      const root = DocumentRootNode(body: [UnsafeHtmlNode('<b>x</b>')]);
      final issues = const SeoValidator().validate(root);
      expect(
        issues.map((i) => i.code),
        contains('unsafe_html_without_sanitizer'),
      );
      expect(
        issues
            .firstWhere((i) => i.code == 'unsafe_html_without_sanitizer')
            .severity,
        IssueSeverity.warning,
      );
    });

    test('does not warn when a sanitizer is provided', () {
      final root = DocumentRootNode(
        body: [UnsafeHtmlNode('<b>x</b>', sanitizer: (raw) => raw)],
      );
      final issues = const SeoValidator().validate(root);
      expect(
        issues.map((i) => i.code),
        isNot(contains('unsafe_html_without_sanitizer')),
      );
    });
  });
}
