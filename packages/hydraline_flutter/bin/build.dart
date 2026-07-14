import 'dart:io';

import 'package:hydraline_flutter/src/route_adapter.dart';
import 'package:hydraline_flutter/src/ssg_cli.dart';

const _usage = '''
Usage: dart run hydraline_flutter:build <manifest.yaml> <outputDir>
       dart run hydraline_flutter:build --config <manifest.yaml> --output <dir>''';

void main(List<String> args) async {
  String? manifestPath;
  String? outputDir;

  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--config':
        if (i + 1 < args.length) manifestPath = args[++i];
      case '--output':
        if (i + 1 < args.length) outputDir = args[++i];
      default:
        positional.add(args[i]);
    }
  }
  manifestPath ??= positional.isNotEmpty ? positional[0] : null;
  outputDir ??= positional.length > 1 ? positional[1] : null;

  if (manifestPath == null || outputDir == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  exitCode = await runSsgCli(
    manifestPath: manifestPath,
    outputDir: outputDir,
    adapter: Navigator2Adapter([]),
    islandFactories: {},
  );
}
