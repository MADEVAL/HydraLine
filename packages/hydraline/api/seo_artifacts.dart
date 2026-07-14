// Hydraline — API contract (L4) · packages/hydraline/api/seo_artifacts.dart
//
// sitemap.xml, robots.txt, SEO validators, and CLI audit.
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

/// URL source for sitemap: (a) from route manifest, (b) async provider (DB).
abstract interface class SitemapSource {
  Stream<SitemapEntry> entries();
}

/// Generation result: one file OR index + shards (auto-split).
class SitemapOutput {
  const SitemapOutput({required this.files, required this.isIndex});
  final Map<String, String> files; // name → xml content
  final bool isIndex; // true when >50k URLs or >50MB
}

abstract final class Sitemap {
  /// Auto-splits into sitemap-index at >50 000 URLs or >50 MB per file.
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

// ── SEO validators ─────────────────────────────────────────────────────────────

enum ValidationSeverity { info, warning, error }

class ValidationIssue {
  const ValidationIssue({required this.severity, required this.code, required this.message, this.location});
  final ValidationSeverity severity;
  final String code;
  final String message;
  final String? location; // route/node
}

abstract interface class SeoValidator {
  /// Validates title/description lengths, alt required, duplicate canonical, broken hreflang.
  List<ValidationIssue> validate(Object target);
}

// ── CLI audit ──────────────────────────────────────────────────────────────────

class AuditReport {
  const AuditReport({required this.issues, required this.exitCode});
  final List<ValidationIssue> issues;
  final int exitCode; // 0 = ok; non-zero = problems (for CI)
}

abstract final class Audit {
  /// Standalone audit: view-source, metadata/OG/JSON-LD, validators.
  static Future<AuditReport> standalone(String url) => throw UnimplementedError();

  /// Server-integration audit: verifies that
  /// `bytes(buffered for UA=Googlebot) == bytes(concat(chunks for normal UA))`.
  static Future<AuditReport> serverIntegration(String url) => throw UnimplementedError();
}
