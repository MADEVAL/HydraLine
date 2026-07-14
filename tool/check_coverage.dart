import 'dart:convert';
import 'dart:io';

/// A coverage threshold for one package's LCOV report (invariant I9).
class CoverageTarget {
  const CoverageTarget({
    required this.name,
    required this.lcovPath,
    required this.minPercent,
  });

  final String name;
  final String lcovPath;
  final double minPercent;
}

/// Sums `LF:` (lines found) and `LH:` (lines hit) across an LCOV [content].
({int found, int hit}) parseLcov(String content) {
  var found = 0;
  var hit = 0;
  for (final line in const LineSplitter().convert(content)) {
    if (line.startsWith('LF:')) {
      found += int.parse(line.substring(3).trim());
    } else if (line.startsWith('LH:')) {
      hit += int.parse(line.substring(3).trim());
    }
  }
  return (found: found, hit: hit);
}

/// Line-coverage percentage (0..100). Returns 100 when there are no coverable
/// lines, so an empty report never fails the gate on its own.
double lineCoverage(String lcov) {
  final result = parseLcov(lcov);
  if (result.found == 0) {
    return 100;
  }
  return 100 * result.hit / result.found;
}

/// Checks every [target] against its threshold; returns a process exit code
/// (0 = all pass, 1 = at least one below threshold).
int runCoverageGate(List<CoverageTarget> targets,
    {void Function(String)? log}) {
  final report = log ?? stdout.writeln;
  var failed = false;
  for (final target in targets) {
    final file = File(target.lcovPath);
    if (!file.existsSync()) {
      report('coverage: ${target.name}: no report at ${target.lcovPath} '
          '(skipped)');
      continue;
    }
    final percent = lineCoverage(file.readAsStringSync());
    final ok = percent + 1e-9 >= target.minPercent;
    report('coverage: ${target.name}: ${percent.toStringAsFixed(1)}% '
        '(min ${target.minPercent.toStringAsFixed(0)}%) '
        '${ok ? 'OK' : 'FAIL'}');
    if (!ok) {
      failed = true;
    }
  }
  return failed ? 1 : 0;
}

/// Coverage thresholds per package (DEVELOPMENT.md §6.4, I9).
const List<CoverageTarget> defaultTargets = [
  CoverageTarget(
    name: 'hydraline',
    lcovPath: 'packages/hydraline/coverage/lcov.info',
    minPercent: 90,
  ),
  CoverageTarget(
    name: 'hydraline_server',
    lcovPath: 'packages/hydraline_server/coverage/lcov.info',
    minPercent: 90,
  ),
  CoverageTarget(
    name: 'hydraline_flutter',
    lcovPath: 'packages/hydraline_flutter/coverage/lcov.info',
    minPercent: 80,
  ),
];

void main() {
  exit(runCoverageGate(defaultTargets));
}
