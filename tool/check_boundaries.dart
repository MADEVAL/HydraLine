import 'dart:io';

/// A dependency-boundary rule: within [dir], any import/export whose URI starts
/// with one of [forbidden] is a violation of invariant I1.
class BoundaryRule {
  const BoundaryRule({
    required this.name,
    required this.dir,
    required this.forbidden,
  });

  final String name;
  final String dir;
  final List<String> forbidden;
}

/// A single forbidden-import occurrence.
class Violation {
  const Violation({
    required this.rule,
    required this.file,
    required this.import,
  });

  final String rule;
  final String file;
  final String import;

  @override
  String toString() => '[$rule] $file imports $import';
}

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Returns the URIs imported/exported by [source] that start with any of the
/// [forbidden] prefixes. Comments and string literals are ignored because only
/// leading `import`/`export` directives are matched.
List<String> findForbiddenImports(String source, List<String> forbidden) {
  final hits = <String>[];
  for (final match in _directive.allMatches(source)) {
    final uri = match.group(1)!;
    if (forbidden.any(uri.startsWith)) {
      hits.add(uri);
    }
  }
  return hits;
}

/// Scans every `.dart` file under [dir] for imports forbidden by the rule.
List<Violation> scanDirectory(
  Directory dir,
  List<String> forbidden, {
  required String rule,
}) {
  if (!dir.existsSync()) {
    return const [];
  }
  final violations = <Violation>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final source = entity.readAsStringSync();
    for (final uri in findForbiddenImports(source, forbidden)) {
      violations.add(Violation(rule: rule, file: entity.path, import: uri));
    }
  }
  return violations;
}

/// Runs all [rules] and returns a process exit code: 0 when clean, 1 otherwise.
int runCheck(List<BoundaryRule> rules, {void Function(String)? log}) {
  final report = log ?? stdout.writeln;
  final violations = <Violation>[];
  for (final rule in rules) {
    violations.addAll(
      scanDirectory(Directory(rule.dir), rule.forbidden, rule: rule.name),
    );
  }
  if (violations.isEmpty) {
    report('boundaries OK: no forbidden imports (I1).');
    return 0;
  }
  report('Dependency boundary violations (I1):');
  for (final violation in violations) {
    report('  $violation');
  }
  return 1;
}

/// Boundary rules for the Hydraline workspace (ARCHITECTURE.md §3, D1/I1).
const List<BoundaryRule> defaultRules = [
  BoundaryRule(
    name: 'hydraline (core)',
    dir: 'packages/hydraline/lib',
    forbidden: ['package:flutter/', 'dart:ui', 'dart:html'],
  ),
  BoundaryRule(
    name: 'hydraline_server',
    dir: 'packages/hydraline_server/lib',
    forbidden: ['package:flutter/'],
  ),
];

void main() {
  exit(runCheck(defaultRules));
}
