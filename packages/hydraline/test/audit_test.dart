import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

const _goodHtml = '''
<!DOCTYPE html><html lang="en"><head>
<title>Home — Store</title>
<meta name="description" content="A concise, useful description of the page.">
<meta property="og:title" content="Home">
<meta property="og:image" content="/img/og.jpg">
<link rel="canonical" href="https://x.example/">
</head><body>
<main><h1>Home</h1><img src="/a.png" alt="A"></main>
</body></html>
''';

void main() {
  group('Audit.auditHtml (C-11a / A1,A2)', () {
    test('a well-formed page reports no errors and exit code 0', () {
      final report = Audit.auditHtml(_goodHtml);
      expect(
        report.issues.where((i) => i.severity == ValidationSeverity.error),
        isEmpty,
      );
      expect(report.exitCode, 0);
    });

    test('missing title is an error with non-zero exit code', () {
      final report = Audit.auditHtml('<html><head></head><body></body></html>');
      expect(report.issues.map((i) => i.code), contains('title_missing'));
      expect(report.exitCode, isNonZero);
    });

    test('image without alt is an error (SEO-11)', () {
      final report = Audit.auditHtml(
        '<html><head><title>T</title></head><body>'
        '<h1>H</h1><img src="/a.png"></body></html>',
      );
      expect(report.issues.map((i) => i.code), contains('image_missing_alt'));
      expect(report.exitCode, isNonZero);
    });

    test('missing Open Graph tags warn (A2)', () {
      final report = Audit.auditHtml(
        '<html><head><title>T</title>'
        '<meta name="description" content="d"></head>'
        '<body><h1>H</h1></body></html>',
      );
      expect(report.issues.map((i) => i.code), contains('og_missing'));
    });

    test('missing h1 warns', () {
      final report = Audit.auditHtml(
        '<html><head><title>T</title></head><body><p>x</p></body></html>',
      );
      expect(report.issues.map((i) => i.code), contains('h1_missing'));
    });

    test('duplicate canonical is an error', () {
      final report = Audit.auditHtml(
        '<html><head><title>T</title>'
        '<link rel="canonical" href="https://x/">'
        '<link rel="canonical" href="https://x/2"></head>'
        '<body><h1>H</h1></body></html>',
      );
      expect(report.issues.map((i) => i.code), contains('duplicate_canonical'));
    });
  });

  group('Audit.compareBodies (C-11b / A8 scaffold)', () {
    test('identical buffered and concatenated chunks pass', () {
      final report = Audit.compareBodies('<html>x</html>', [
        '<html>',
        'x</html>',
      ]);
      expect(report.exitCode, 0);
      expect(report.issues, isEmpty);
    });

    test('a body mismatch is a cloaking error (I3)', () {
      final report = Audit.compareBodies('<html>a</html>', ['<html>b</html>']);
      expect(report.issues.map((i) => i.code), contains('body_mismatch'));
      expect(report.exitCode, isNonZero);
    });
  });
}
