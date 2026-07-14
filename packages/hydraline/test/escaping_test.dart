import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('escapeHtmlText', () {
    test('escapes &, < and >', () {
      expect(escapeHtmlText('A & <B>'), 'A &amp; &lt;B&gt;');
    });

    test('escapes ampersand before other entities', () {
      expect(escapeHtmlText('&lt;'), '&amp;lt;');
    });

    test('leaves quotes untouched in text context', () {
      expect(escapeHtmlText('"x\''), '"x\'');
    });

    test('is a no-op for plain text', () {
      expect(escapeHtmlText('hello world'), 'hello world');
    });
  });

  group('escapeHtmlAttribute', () {
    test('escapes double/single quotes, angle brackets and ampersand', () {
      expect(
        escapeHtmlAttribute('a"b\'c<d>&e'),
        'a&quot;b&#39;c&lt;d&gt;&amp;e',
      );
    });
  });

  group('SafeUrl allowlist (S1/N3)', () {
    test('accepts http/https/mailto/tel', () {
      expect(
        SafeUrl.parse('https://example.com/x').value,
        'https://example.com/x',
      );
      expect(SafeUrl.parse('http://example.com').value, 'http://example.com');
      expect(SafeUrl.parse('mailto:a@b.com').value, 'mailto:a@b.com');
      expect(SafeUrl.parse('tel:+123').value, 'tel:+123');
    });

    test('accepts relative URLs', () {
      for (final r in ['/a/b', './a', '../a', '#frag', '?q=1', 'page.html']) {
        expect(SafeUrl.tryParse(r), isNotNull, reason: r);
      }
    });

    test('rejects javascript/data/vbscript', () {
      expect(SafeUrl.tryParse('javascript:alert(1)'), isNull);
      expect(SafeUrl.tryParse('data:text/html,<script>'), isNull);
      expect(SafeUrl.tryParse('vbscript:msgbox'), isNull);
    });

    test('rejects unknown schemes (allowlist, not blocklist)', () {
      expect(SafeUrl.tryParse('ftp://host/x'), isNull);
      expect(SafeUrl.tryParse('file:///etc/passwd'), isNull);
    });

    test('is case-insensitive on the scheme', () {
      expect(SafeUrl.tryParse('JavaScript:alert(1)'), isNull);
      expect(SafeUrl.tryParse('HTTPS://ok.com'), isNotNull);
    });

    test('defeats whitespace/control-char obfuscation', () {
      expect(SafeUrl.tryParse('  javascript:alert(1)'), isNull);
      expect(SafeUrl.tryParse('java\tscript:alert(1)'), isNull);
      expect(SafeUrl.tryParse('java\nscript:alert(1)'), isNull);
      expect(SafeUrl.tryParse('java\u0000script:alert(1)'), isNull);
    });

    test('parse throws UnsafeUrlException carrying the raw input', () {
      expect(
        () => SafeUrl.parse('javascript:alert(1)'),
        throwsA(
          isA<UnsafeUrlException>().having(
            (e) => e.raw,
            'raw',
            'javascript:alert(1)',
          ),
        ),
      );
    });
  });

  group('Csp (S5)', () {
    test('recommends self + wasm-unsafe-eval and forbids unsafe-inline', () {
      final value = Csp.recommendedHeaderValue();
      expect(value, contains("script-src 'self' 'wasm-unsafe-eval'"));
      expect(value, isNot(contains('unsafe-inline')));
    });

    test('metaTag wraps an escaped policy', () {
      expect(
        Csp.metaTag(),
        startsWith('<meta http-equiv="Content-Security-Policy" content="'),
      );
    });

    test('appends extra directives', () {
      expect(
        Csp.recommendedHeaderValue(extraDirectives: ["img-src 'self' data:"]),
        contains("img-src 'self' data:"),
      );
    });
  });
}
