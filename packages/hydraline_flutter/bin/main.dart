import 'dart:io';

import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:hydraline_flutter/src/ssg_cli.dart';

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: ssg <manifest.yaml> <outputDir>');
    exitCode = 1;
    return;
  }

  final manifestPath = args[0];
  final outputDir = args[1];

  exitCode = await runSsgCli(
    manifestPath: manifestPath,
    outputDir: outputDir,
    adapter: Navigator2Adapter([]),
    islandFactories: {},
  );
}
