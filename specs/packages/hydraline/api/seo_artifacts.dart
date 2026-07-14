// Hydraline — API-контракт (L4) · packages/hydraline/api/seo_artifacts.dart
//
// sitemap.xml, robots.txt, SEO-валидаторы, CLI-аудит. Реализация — PHASE_1
// (P1-13, P1-14, P1-18, P1-19, P1-20). ARCHITECTURE.md §7.3/§2.1.
// Покрывает SEO-5, SEO-6, C-6, C-10, C-11.
//
// ignore_for_file: unused_element

import 'escaping.dart' show SafeUrl;

// ── Sitemap ────────────────────────────────────────────────────────────────────

enum ChangeFreq { always, hourly, daily, weekly, monthly, yearly, never }

class SitemapEntry {
  const SitemapEntry({
    required this.loc,
    this.lastmod,
    this.changefreq,
    this.priority,
    this.alternates = const [],
  });
  final SafeUrl loc;
  final DateTime? lastmod;
  final ChangeFreq? changefreq;
  final double? priority; // 0.0..1.0
  final List<({String hreflang, SafeUrl href})> alternates;
}

/// Источник URL для sitemap: (a) из route-манифеста, (b) async-провайдер (БД).
abstract interface class SitemapSource {
  Stream<SitemapEntry> entries();
}

/// Результат генерации: один файл ИЛИ индекс + шарды (автосплит SM1).
class SitemapOutput {
  const SitemapOutput({required this.files, required this.isIndex});
  final Map<String, String> files; // имя → xml-содержимое
  final bool isIndex; // true при >50k URL или >50MB
}

abstract final class Sitemap {
  /// SM1: автосплит в sitemap-index при >50 000 URL или >50 MB на файл.
  static Future<SitemapOutput> generate(SitemapSource source, {required SafeUrl baseUrl}) =>
      throw UnimplementedError();
}

// ── robots.txt ─────────────────────────────────────────────────────────────────

class RobotsRule {
  const RobotsRule({required this.userAgent, this.allow = const [], this.disallow = const []});
  final String userAgent;
  final List<String> allow;
  final List<String> disallow;
}

abstract final class Robots {
  static String generate({required List<RobotsRule> rules, List<SafeUrl> sitemaps = const []}) =>
      throw UnimplementedError();
}

// ── SEO-валидаторы (C-10) ──────────────────────────────────────────────────────

enum ValidationSeverity { info, warning, error }

class ValidationIssue {
  const ValidationIssue({required this.severity, required this.code, required this.message, this.location});
  final ValidationSeverity severity;
  final String code;
  final String message;
  final String? location; // маршрут/узел
}

abstract interface class SeoValidator {
  /// Длины title/description, обязательность alt, дубли canonical, битые hreflang.
  List<ValidationIssue> validate(Object target);
}

// ── CLI-аудит (C-11) ────────────────────────────────────────────────────────────

class AuditReport {
  const AuditReport({required this.issues, required this.exitCode});
  final List<ValidationIssue> issues;
  final int exitCode; // 0 = ок; ≠0 = проблемы (для CI)
}

abstract final class Audit {
  /// C-11(a) standalone: view-source, метаданные/OG/JSON-LD, валидаторы. (A1/A2)
  static Future<AuditReport> standalone(String url) => throw UnimplementedError();

  /// C-11(b) server-integration: инвариант A8 —
  /// `bytes(buffered для UA=Googlebot) == bytes(concat(chunks для обычного UA))`.
  static Future<AuditReport> serverIntegration(String url) => throw UnimplementedError();
}
