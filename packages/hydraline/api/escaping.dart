// Hydraline — API contract (L4) · packages/hydraline/api/escaping.dart
//
// Security contract for HTML escaping, URL sanitization, and CSP helpers.
//
// ignore_for_file: unused_element

/// Escapes text content: `<` `>` `&` → HTML entities.
String escapeHtmlText(String input) => throw UnimplementedError();

/// Escapes attribute values: `"` `'` `<` `>` `&` → HTML entities.
String escapeHtmlAttribute(String input) => throw UnimplementedError();

/// A sanitized URL. No public constructor — instances can only be created
/// via static [SafeUrl.parse]/[SafeUrl.tryParse]. This makes it impossible
/// to construct a node with an unverified URL at the type level.
abstract interface class SafeUrl {
  /// The sanitized string value.
  String get value;

  /// Allowlisted schemes: http, https, mailto, tel, relative (`/`, `./`).
  /// Blocked: javascript:, data:, vbscript:. Returns null on rejection.
  static SafeUrl? tryParse(String raw) => throw UnimplementedError();

  /// Like [tryParse], but throws [UnsafeUrlException] on a disallowed scheme.
  static SafeUrl parse(String raw) => throw UnimplementedError();
}

class UnsafeUrlException implements Exception {
  const UnsafeUrlException(this.raw, this.reason);
  final String raw;
  final String reason;
}

/// Helper for recommended CSP: `script-src 'self' 'wasm-unsafe-eval'`
/// (no `unsafe-inline`; `wasm-unsafe-eval` is needed for CanvasKit).
abstract final class Csp {
  /// Value of the `Content-Security-Policy` header.
  static String recommendedHeaderValue({List<String> extraDirectives = const []}) =>
      throw UnimplementedError();

  /// `<meta http-equiv="Content-Security-Policy" content="...">`.
  static String metaTag({List<String> extraDirectives = const []}) =>
      throw UnimplementedError();
}
