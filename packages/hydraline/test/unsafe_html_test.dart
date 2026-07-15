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

    test('UnsafeHtmlNode.trusted documents trusted intent', () {
      const node = UnsafeHtmlNode.trusted('<base href="/">');
      expect(node.sanitizer, isNull);
      expect(node.sanitize(), '<base href="/">');
    });
  });

  group('sanitizeHtml', () {
    test('strips script tags including their content', () {
      expect(sanitizeHtml('<script>alert(1)</script>'), '');
      expect(sanitizeHtml('<SCRIPT src="x.js"></SCRIPT>'), '');
      expect(sanitizeHtml('a<script>alert(1)</script>b'), 'ab');
    });

    test('strips inline event-handler attributes', () {
      expect(sanitizeHtml('<div onclick="alert(1)">x</div>'), '<div>x</div>');
      expect(sanitizeHtml("<div onload='alert(1)'>x</div>"), '<div>x</div>');
    });

    test('leaves safe HTML untouched', () {
      expect(sanitizeHtml('<b>x</b>'), '<b>x</b>');
      expect(sanitizeHtml('<base href="/">'), '<base href="/">');
    });
  });
}
