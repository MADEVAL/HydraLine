import 'dart:io';

import 'package:test/test.dart';

import '../tool/check_coverage.dart';

void main() {
  group('lineCoverage', () {
    test('computes percentage from LF/LH records', () {
      const lcov = 'SF:lib/a.dart\nLF:10\nLH:5\nend_of_record\n';
      expect(lineCoverage(lcov), 50);
    });

    test('sums records across files', () {
      const lcov =
          'SF:lib/a.dart\nLF:10\nLH:10\nend_of_record\n'
          'SF:lib/b.dart\nLF:10\nLH:0\nend_of_record\n';
      expect(lineCoverage(lcov), 50);
    });

    test('treats no coverable lines as 100%', () {
      expect(lineCoverage(''), 100);
    });
  });

  group('runCoverageGate (invariant I9 — negative test)', () {
    test('returns non-zero when a target is below its threshold', () async {
      final tmp = await Directory.systemTemp.createTemp('hydraline_cov_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final lcov = File('${tmp.path}/lcov.info')
        ..writeAsStringSync('SF:lib/a.dart\nLF:10\nLH:5\nend_of_record\n');

      final code = runCoverageGate([
        CoverageTarget(name: 'core', lcovPath: lcov.path, minPercent: 90),
      ]);

      expect(code, isNonZero);
    });

    test('returns zero when the target meets its threshold', () async {
      final tmp = await Directory.systemTemp.createTemp('hydraline_cov_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final lcov = File('${tmp.path}/lcov.info')
        ..writeAsStringSync('SF:lib/a.dart\nLF:10\nLH:10\nend_of_record\n');

      final code = runCoverageGate([
        CoverageTarget(name: 'core', lcovPath: lcov.path, minPercent: 90),
      ]);

      expect(code, isZero);
    });
  });
}
