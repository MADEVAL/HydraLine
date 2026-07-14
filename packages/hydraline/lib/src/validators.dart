/// SEO / safety validators over a [DocumentNode] tree (ARCHITECTURE.md §7, C-10).
///
/// Phase 1 seeds the unsafe-HTML warning (S3); SEO checks (title/description
/// lengths, alt, canonical duplicates, hreflang) are added in P1-18.
library;

import 'document_node.dart';

/// Severity of a validation issue.
enum IssueSeverity { warning, error }

/// A single validation finding.
class SeoIssue {
  const SeoIssue({
    required this.severity,
    required this.code,
    required this.message,
  });

  final IssueSeverity severity;
  final String code;
  final String message;

  @override
  String toString() => '[${severity.name}] $code: $message';
}

/// Validates a [DocumentNode] tree and returns the issues found.
class SeoValidator {
  const SeoValidator();

  List<SeoIssue> validate(DocumentNode root) {
    final issues = <SeoIssue>[];
    for (final node in _walk(root)) {
      if (node is UnsafeHtmlNode && node.sanitizer == null) {
        issues.add(
          const SeoIssue(
            severity: IssueSeverity.warning,
            code: 'unsafe_html_without_sanitizer',
            message: 'UnsafeHtmlNode used without a sanitizer (S3).',
          ),
        );
      }
    }
    return issues;
  }
}

Iterable<DocumentNode> _walk(DocumentNode root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _walk(child);
  }
}
