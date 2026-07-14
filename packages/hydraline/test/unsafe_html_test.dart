import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('UnsafeHtmlNode', () {
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
}
