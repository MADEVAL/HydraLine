import 'dart:io';

import 'package:test/test.dart';

import '../tool/check_boundaries.dart';

void main() {
  group('findForbiddenImports', () {
    test('flags a forbidden package:flutter import', () {
      const source = "import 'package:flutter/material.dart';\nvoid main() {}";
      expect(
        findForbiddenImports(source, const ['package:flutter/']),
        contains('package:flutter/material.dart'),
      );
    });

    test('flags dart:ui and dart:html', () {
      const source = "import 'dart:ui';\nexport 'dart:html';";
      expect(
        findForbiddenImports(source, const ['dart:ui', 'dart:html']),
        containsAll(<String>['dart:ui', 'dart:html']),
      );
    });

    test('allows non-forbidden imports', () {
      const source = "import 'dart:async';\nimport 'package:meta/meta.dart';";
      expect(
        findForbiddenImports(source, const [
          'package:flutter/',
          'dart:ui',
          'dart:html',
        ]),
        isEmpty,
      );
    });

    test('does not false-positive on comments or string literals', () {
      const source =
          "// import 'package:flutter/material.dart';\n"
          "const s = 'package:flutter/x.dart';";
      expect(findForbiddenImports(source, const ['package:flutter/']), isEmpty);
    });
  });

  group('runCheck (invariant I1 — negative test)', () {
    test(
      'returns non-zero when a rule dir contains a forbidden import',
      () async {
        final tmp = await Directory.systemTemp.createTemp('hydraline_bnd_');
        addTearDown(() => tmp.deleteSync(recursive: true));
        File(
          '${tmp.path}/offender.dart',
        ).writeAsStringSync("import 'package:flutter/widgets.dart';");

        final code = runCheck([
          BoundaryRule(
            name: 'core',
            dir: tmp.path,
            forbidden: const ['package:flutter/'],
          ),
        ]);

        expect(code, isNonZero);
      },
    );

    test('returns zero when every rule dir is clean', () async {
      final tmp = await Directory.systemTemp.createTemp('hydraline_bnd_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File(
        '${tmp.path}/clean.dart',
      ).writeAsStringSync("import 'dart:async';\nvoid main() {}");

      final code = runCheck([
        BoundaryRule(
          name: 'core',
          dir: tmp.path,
          forbidden: const ['package:flutter/', 'dart:ui', 'dart:html'],
        ),
      ]);

      expect(code, isZero);
    });
  });
}
