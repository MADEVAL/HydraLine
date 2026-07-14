// Hydraline — API-контракт (L4) · packages/hydraline/api/escaping.dart
//
// Контракт безопасности. Реализация — PHASE_1 (P1-02). ARCHITECTURE.md §5.
// Инварианты: S1 (allowlist схем), S2 (обязательное экранирование),
// S4 (0 XSS/10^6), S5 (CSP-helper).
//
// ignore_for_file: unused_element

/// Экранирование текстового контента: `<` `>` `&` → сущности. (S2)
String escapeHtmlText(String input) => throw UnimplementedError();

/// Экранирование значения атрибута: `"` `'` `<` `>` `&` → сущности. (S2)
String escapeHtmlAttribute(String input) => throw UnimplementedError();

/// URL, прошедший санитайз. Публичного конструктора НЕТ — создать можно ТОЛЬКО
/// через статические [SafeUrl.parse]/[SafeUrl.tryParse] (N3/S1). Это делает
/// невозможным конструирование узла с непроверенным URL на уровне типов.
abstract interface class SafeUrl {
  /// Санитизированное строковое значение.
  String get value;

  /// Allowlist схем: http, https, mailto, tel, относительные (`/`, `./`).
  /// Блок: javascript:, data:, vbscript:. Возвращает null при запрете. (S1)
  static SafeUrl? tryParse(String raw) => throw UnimplementedError();

  /// Как [tryParse], но бросает [UnsafeUrlException] при запрещённой схеме.
  static SafeUrl parse(String raw) => throw UnimplementedError();
}

class UnsafeUrlException implements Exception {
  const UnsafeUrlException(this.raw, this.reason);
  final String raw;
  final String reason;
}

/// Helper рекомендованного CSP (S5): `script-src 'self' 'wasm-unsafe-eval'`
/// (без `unsafe-inline`; `wasm-unsafe-eval` нужен CanvasKit).
abstract final class Csp {
  /// Значение заголовка `Content-Security-Policy`.
  static String recommendedHeaderValue({List<String> extraDirectives = const []}) =>
      throw UnimplementedError();

  /// `<meta http-equiv="Content-Security-Policy" content="...">`.
  static String metaTag({List<String> extraDirectives = const []}) =>
      throw UnimplementedError();
}
