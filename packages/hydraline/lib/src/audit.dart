/// CLI audit: "what the crawler sees" (standalone) and the buffered↔chunked
/// body-identity comparator (server-integration).
library;

import 'package:html/parser.dart' as html;

import 'validators.dart';

/// The result of an audit: findings plus a process exit code (0 = ok).
class AuditReport {
  const AuditReport({required this.issues, required this.exitCode});

  final List<ValidationIssue> issues;
  final int exitCode;
}

/// CLI audit entry points.
abstract final class Audit {
  static const int _titleMaxLength = 70;
  static const int _descriptionMaxLength = 160;

  /// Standalone: audits the raw HTML a crawler would see — title,
  /// meta description, Open Graph, canonical, headings and image alt.
  static AuditReport auditHtml(String source) {
    final document = html.parse(source);
    final issues = <ValidationIssue>[];

    final title = document.querySelector('title')?.text.trim();
    if (title == null || title.isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'title_missing',
          message: '<title> is missing or empty.',
        ),
      );
    } else if (title.length > _titleMaxLength) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'title_too_long',
          message: '<title> exceeds $_titleMaxLength characters.',
        ),
      );
    }

    final description = document
        .querySelector('meta[name="description"]')
        ?.attributes['content'];
    if (description == null || description.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'description_missing',
          message: 'meta description is missing.',
        ),
      );
    } else if (description.length > _descriptionMaxLength) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'description_too_long',
          message:
              'meta description exceeds $_descriptionMaxLength characters.',
        ),
      );
    }

    final hasOgTitle =
        document.querySelector('meta[property="og:title"]') != null;
    final hasOgImage =
        document.querySelector('meta[property="og:image"]') != null;
    if (!hasOgTitle || !hasOgImage) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'og_missing',
          message: 'Open Graph og:title/og:image are recommended.',
        ),
      );
    }

    if (document.querySelector('h1') == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'h1_missing',
          message: 'no <h1> found.',
        ),
      );
    }

    for (final img in document.querySelectorAll('img')) {
      final alt = img.attributes['alt'];
      if (alt == null || alt.trim().isEmpty) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'image_missing_alt',
            message: 'an <img> is missing alt text.',
          ),
        );
      }
    }

    final canonicals = document.querySelectorAll('link[rel="canonical"]');
    if (canonicals.length > 1) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_canonical',
          message:
              'found ${canonicals.length} canonical links; expected at most 1.',
        ),
      );
    }

    return AuditReport(issues: issues, exitCode: _exitCode(issues));
  }

  /// Server-integration comparator: the document body served buffered (to bots)
  /// must be byte-identical to the concatenation of the streamed chunks (to
  /// users).
  static AuditReport compareBodies(String buffered, List<String> chunks) {
    final concatenated = chunks.join();
    if (buffered == concatenated) {
      return const AuditReport(issues: [], exitCode: 0);
    }
    final issues = [
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'body_mismatch',
        message:
            'buffered body differs from concatenated chunks — cloaking risk.',
      ),
    ];
    return AuditReport(issues: issues, exitCode: _exitCode(issues));
  }

  static int _exitCode(List<ValidationIssue> issues) =>
      issues.any((i) => i.severity == ValidationSeverity.error) ? 1 : 0;
}
