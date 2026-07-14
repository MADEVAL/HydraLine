import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  const validator = SeoValidator();

  List<String> codes(Object target) =>
      validator.validate(target).map((i) => i.code).toList();

  group('ValidationIssue', () {
    test('toString with location includes it', () {
      const issue = ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'test_code',
        message: 'test message',
        location: '/route',
      );
      expect(issue.toString(), contains('(/route)'));
    });

    test('toString without location does not contain empty parens', () {
      const issue = ValidationIssue(
        severity: ValidationSeverity.warning,
        code: 'test_code',
        message: 'test message',
      );
      expect(issue.toString(), isNot(contains('()')));
      expect(issue.toString(), startsWith('[warning]'));
    });
  });

  group('SeoMeta validation', () {
    test('empty title is an error', () {
      final issues = validator.validate(const SeoMeta(title: ''));
      final title = issues.firstWhere((i) => i.code == 'title_empty');
      expect(title.severity, ValidationSeverity.error);
    });

    test('overly long title warns', () {
      expect(codes(SeoMeta(title: 'x' * 71)), contains('title_too_long'));
    });

    test('missing description warns', () {
      expect(
        codes(const SeoMeta(title: 'Home')),
        contains('description_missing'),
      );
    });

    test('overly long description warns', () {
      expect(
        codes(SeoMeta(title: 'Home', description: 'x' * 161)),
        contains('description_too_long'),
      );
    });

    test('duplicate hreflang warns', () {
      final meta = SeoMeta(
        title: 'Home',
        description: 'ok',
        hreflang: [
          HreflangAlternate(hreflang: 'en', href: SafeUrl.parse('/en')),
          HreflangAlternate(hreflang: 'en', href: SafeUrl.parse('/en2')),
        ],
      );
      expect(codes(meta), contains('duplicate_hreflang'));
    });

    test('a well-formed meta yields no errors', () {
      final issues = validator.validate(
        const SeoMeta(title: 'Home', description: 'A short description.'),
      );
      expect(
        issues.where((i) => i.severity == ValidationSeverity.error),
        isEmpty,
      );
    });
  });

  group('DocumentNode validation', () {
    test('image without alt is an error', () {
      final root = DocumentRootNode(
        body: [ImageNode(src: SafeUrl.parse('/i.png'), alt: '')],
      );
      final issue = validator
          .validate(root)
          .firstWhere((i) => i.code == 'image_missing_alt');
      expect(issue.severity, ValidationSeverity.error);
    });

    test('duplicate canonical links is an error', () {
      final root = DocumentRootNode(
        head: HeadNode(
          children: [
            LinkNode(rel: 'canonical', href: SafeUrl.parse('https://x/')),
            LinkNode(rel: 'canonical', href: SafeUrl.parse('https://x/2')),
          ],
        ),
        body: const [],
      );
      expect(codes(root), contains('duplicate_canonical'));
    });

    test('unsafe html without sanitizer warns', () {
      const root = DocumentRootNode(body: [UnsafeHtmlNode('<b>x</b>')]);
      final issue = validator
          .validate(root)
          .firstWhere((i) => i.code == 'unsafe_html_without_sanitizer');
      expect(issue.severity, ValidationSeverity.warning);
    });

    test('sanitized unsafe html does not warn', () {
      final root = DocumentRootNode(
        body: [UnsafeHtmlNode('<b>x</b>', sanitizer: (r) => r)],
      );
      expect(codes(root), isNot(contains('unsafe_html_without_sanitizer')));
    });
  });

  test('validate throws ArgumentError for unsupported type', () {
    expect(
      () => validator.validate('not a valid target'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
