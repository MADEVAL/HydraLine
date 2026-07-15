/// Contextual HTML escaping and URL sanitisation.
///
/// Invariants: scheme allowlist, mandatory escaping,
/// zero XSS on fuzzing, CSP helper.
library;

final RegExp _textSpecials = RegExp('[&<>]');
final RegExp _attributeSpecials = RegExp('[&<>"\']');

/// Escapes text content: `&`, `<`, `>` become entities.
///
/// Quotes are intentionally left untouched - text and attribute contexts use
/// different escapers so they can never be confused (see [escapeHtmlAttribute]).
String escapeHtmlText(String input) {
  if (!input.contains(_textSpecials)) {
    return input;
  }
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    switch (unit) {
      case 0x26: // &
        buffer.write('&amp;');
      case 0x3C: // <
        buffer.write('&lt;');
      case 0x3E: // >
        buffer.write('&gt;');
      default:
        buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Escapes an attribute value: `&`, `<`, `>`, `"`, `'` become entities.
String escapeHtmlAttribute(String input) {
  if (!input.contains(_attributeSpecials)) {
    return input;
  }
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    switch (unit) {
      case 0x26: // &
        buffer.write('&amp;');
      case 0x3C: // <
        buffer.write('&lt;');
      case 0x3E: // >
        buffer.write('&gt;');
      case 0x22: // "
        buffer.write('&quot;');
      case 0x27: // '
        buffer.write('&#39;');
      default:
        buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// A URL that has passed scheme sanitisation. There is **no** public
/// constructor: instances come only from [SafeUrl.parse]/[SafeUrl.tryParse],
/// so a node can never be built with an unchecked URL.
abstract interface class SafeUrl {
  /// The sanitised string value.
  String get value;

  /// Parses [raw], returning `null` when its scheme is not allowed.
  ///
  /// Allowlist: `http`, `https`, `mailto`, `tel` and relative URLs
  /// (`/`, `./`, `#`, `?`, bare paths). Blocked: everything else, including
  /// `javascript:`, `data:`, `vbscript:`.
  static SafeUrl? tryParse(String raw) {
    final cleaned = raw.replaceAll(_controlChars, '').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final scheme = _schemePattern.firstMatch(cleaned);
    if (scheme != null &&
        !_allowedSchemes.contains(scheme.group(1)!.toLowerCase())) {
      return null;
    }
    return _SafeUrl(cleaned);
  }

  /// Like [tryParse] but throws [UnsafeUrlException] on a blocked scheme.
  static SafeUrl parse(String raw) {
    final url = tryParse(raw);
    if (url == null) {
      throw UnsafeUrlException(raw, 'scheme is not in the allowlist');
    }
    return url;
  }
}

const Set<String> _allowedSchemes = {'http', 'https', 'mailto', 'tel'};

final RegExp _controlChars = RegExp('[\u0000-\u001F\u007F]');
final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):');

final class _SafeUrl implements SafeUrl {
  const _SafeUrl(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) => other is _SafeUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SafeUrl($value)';
}

/// Thrown by [SafeUrl.parse] when a URL's scheme is not allowed.
class UnsafeUrlException implements Exception {
  const UnsafeUrlException(this.raw, this.reason);

  final String raw;
  final String reason;

  @override
  String toString() => 'UnsafeUrlException: $reason ($raw)';
}

/// Helper for the recommended Content-Security-Policy:
/// `script-src 'self' 'wasm-unsafe-eval'` (no `unsafe-inline`; CanvasKit needs
/// `wasm-unsafe-eval`).
abstract final class Csp {
  static const List<String> _directives = [
    "default-src 'self'",
    "script-src 'self' 'wasm-unsafe-eval'",
    "object-src 'none'",
    "base-uri 'self'",
  ];

  /// Value for the `Content-Security-Policy` header.
  static String recommendedHeaderValue({
    List<String> extraDirectives = const [],
  }) => [..._directives, ...extraDirectives].join('; ');

  /// `<meta http-equiv="Content-Security-Policy" content="...">`.
  static String metaTag({List<String> extraDirectives = const []}) {
    final content = escapeHtmlAttribute(
      recommendedHeaderValue(extraDirectives: extraDirectives),
    );
    return '<meta http-equiv="Content-Security-Policy" content="$content">';
  }
}
