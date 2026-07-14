/// SEO / safety validators over [SeoMeta] and [DocumentNode] trees.
library;

import 'document_node.dart';
import 'metadata.dart';

/// Severity of a validation issue.
enum ValidationSeverity { info, warning, error }

/// A single validation finding.
class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.location,
  });

  final ValidationSeverity severity;
  final String code;
  final String message;

  /// Route or node the issue relates to.
  final String? location;

  @override
  String toString() =>
      '[${severity.name}] $code: $message${location == null ? '' : ' ($location)'}';
}

/// Validates SEO/safety rules: title/description lengths, required alt text,
/// duplicate canonical links, malformed hreflang, unsafe HTML.
abstract interface class SeoValidator {
  const factory SeoValidator() = _SeoValidator;

  /// Validates a [SeoMeta] or a [DocumentNode] tree.
  List<ValidationIssue> validate(Object target);
}

class _SeoValidator implements SeoValidator {
  const _SeoValidator();

  static const int _titleMaxLength = 70;
  static const int _descriptionMaxLength = 160;

  @override
  List<ValidationIssue> validate(Object target) => switch (target) {
    final SeoMeta meta => _validateMeta(meta),
    final DocumentNode node => _validateNode(node),
    _ => throw ArgumentError.value(
      target,
      'target',
      'expected SeoMeta or DocumentNode',
    ),
  };

  List<ValidationIssue> _validateMeta(SeoMeta meta) {
    final issues = <ValidationIssue>[];

    if (meta.title.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'title_empty',
          message: 'title must not be empty.',
        ),
      );
    } else if (meta.title.length > _titleMaxLength) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'title_too_long',
          message:
              'title is ${meta.title.length} chars; keep it under '
              '$_titleMaxLength.',
        ),
      );
    }

    final description = meta.description;
    if (description == null || description.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'description_missing',
          message: 'a meta description improves search snippets.',
        ),
      );
    } else if (description.length > _descriptionMaxLength) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'description_too_long',
          message:
              'description is ${description.length} chars; keep it under '
              '$_descriptionMaxLength.',
        ),
      );
    }

    final seenHreflang = <String>{};
    for (final alternate in meta.hreflang) {
      if (!seenHreflang.add(alternate.hreflang)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'duplicate_hreflang',
            message: 'duplicate hreflang "${alternate.hreflang}".',
          ),
        );
      }
    }

    return issues;
  }

  List<ValidationIssue> _validateNode(DocumentNode root) {
    final issues = <ValidationIssue>[];
    var canonicalCount = 0;
    for (final node in _walk(root)) {
      switch (node) {
        case ImageNode(:final alt) when alt.trim().isEmpty:
          issues.add(
            const ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'image_missing_alt',
              message: 'images require non-empty alt text.',
            ),
          );
        case LinkNode(:final rel) when rel == 'canonical':
          canonicalCount++;
        case UnsafeHtmlNode(:final sanitizer) when sanitizer == null:
          issues.add(
            const ValidationIssue(
              severity: ValidationSeverity.warning,
              code: 'unsafe_html_without_sanitizer',
              message: 'UnsafeHtmlNode used without a sanitizer.',
            ),
          );
        default:
          break;
      }
    }
    if (canonicalCount > 1) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_canonical',
          message: 'found $canonicalCount canonical links; expected at most 1.',
        ),
      );
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
