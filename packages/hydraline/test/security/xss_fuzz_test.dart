@Tags(['security'])
library;

import 'dart:math';

import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

/// Inverse of the escapers, for round-trip verification.
String _unescape(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

const _owaspVectors = [
  '<script>alert(1)</script>',
  '"><script>alert(1)</script>',
  "'><img src=x onerror=alert(1)>",
  '<img src=x onerror="alert(1)">',
  '<svg/onload=alert(1)>',
  '<a href="javascript:alert(1)">x</a>',
  '"onmouseover="alert(1)',
  '</title><script>alert(1)</script>',
  '<body onload=alert(1)>',
  '&lt;script&gt;',
  '\u0000<script>',
  '<scr\tipt>alert(1)</script>',
];

const _dangerousUrls = [
  'javascript:alert(1)',
  'JavaScript:alert(1)',
  '  javascript:alert(1)',
  'java\tscript:alert(1)',
  'java\nscript:alert(1)',
  'java\u0000script:alert(1)',
  'data:text/html,<script>alert(1)</script>',
  'vbscript:msgbox(1)',
  'jAvAsCrIpT:alert(1)',
];

String _randomString(Random rng) {
  final length = rng.nextInt(24);
  return String.fromCharCodes([
    for (var i = 0; i < length; i++) rng.nextInt(0x2100),
  ]);
}

void main() {
  const serializer = HtmlSerializer();

  group('escapeHtmlText (S2/S4/I2)', () {
    test('OWASP vectors leave no tag delimiters and round-trip', () {
      for (final vector in _owaspVectors) {
        final escaped = escapeHtmlText(vector);
        expect(escaped, isNot(contains('<')), reason: vector);
        expect(escaped, isNot(contains('>')), reason: vector);
        expect(_unescape(escaped), vector, reason: vector);
      }
    });

    test('1e6 generated inputs never emit < or > and round-trip', () {
      final rng = Random(0x5EED);
      for (var i = 0; i < 1000000; i++) {
        final input = _randomString(rng);
        final escaped = escapeHtmlText(input);
        if (escaped.contains('<') || escaped.contains('>')) {
          fail('unescaped delimiter for input: ${input.codeUnits}');
        }
        if (_unescape(escaped) != input) {
          fail('text round-trip failed for: ${input.codeUnits}');
        }
      }
    });
  });

  group('escapeHtmlAttribute (S2/S4/I2)', () {
    test('1e6 generated inputs cannot break out of a quoted attribute', () {
      final rng = Random(0xC0FFEE);
      for (var i = 0; i < 1000000; i++) {
        final input = _randomString(rng);
        final escaped = escapeHtmlAttribute(input);
        if (escaped.contains('<') ||
            escaped.contains('>') ||
            escaped.contains('"') ||
            escaped.contains("'")) {
          fail('attribute breakout for input: ${input.codeUnits}');
        }
        if (_unescape(escaped) != input) {
          fail('attribute round-trip failed for: ${input.codeUnits}');
        }
      }
    });
  });

  group('SafeUrl allowlist (S1/S4)', () {
    test('rejects every dangerous URL vector', () {
      for (final url in _dangerousUrls) {
        expect(SafeUrl.tryParse(url), isNull, reason: url);
      }
    });
  });

  group('serializer (I2)', () {
    test('attacker-controlled text/alt never inject markup', () {
      final rng = Random(0xBADF00D);
      for (var i = 0; i < 100000; i++) {
        final payload = _randomString(rng);
        final root = DocumentRootNode(
          head: HeadNode(children: [TitleNode(payload)]),
          body: [
            ParagraphNode(children: [TextNode(payload)]),
            ImageNode(src: SafeUrl.parse('/i.png'), alt: payload),
          ],
        );
        final html = serializer.serialize(root);
        if (html.contains('<script') && !payload.contains('script')) {
          fail('injected <script for payload: ${payload.codeUnits}');
        }
        // The paragraph body must contain no raw delimiters from the payload.
        final body = html.substring(
          html.indexOf('<p>') + 3,
          html.indexOf('</p>'),
        );
        if (body.contains('<') || body.contains('>')) {
          fail('paragraph breakout for payload: ${payload.codeUnits}');
        }
      }
    });
  });
}
