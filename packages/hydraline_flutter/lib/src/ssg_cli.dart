/// SSG CLI: programmatic entry point that reads a manifest config and
/// invokes the SSG runner. Designed to be called from `bin/main.dart` or
/// from tests directly.
library;

import 'dart:io';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

Future<int> runSsgCli({
  required String manifestPath,
  required String outputDir,
  required RouteAdapter adapter,
  required Map<String, Object?> islandFactories,
}) async {
  try {
    final manifestFile = File(manifestPath);
    if (!await manifestFile.exists()) {
      stderr.writeln('Manifest file not found: $manifestPath');
      return 1;
    }

    final yamlContent = await manifestFile.readAsString();
    final manifest = RouteManifest.parseYaml(yamlContent);

    final runner = SsgRunner(
      routeManifest: manifest,
      routeAdapter: adapter,
      islandFactories: islandFactories,
    );

    final result = await runner.run(outputDir: outputDir);

    stdout
      ..writeln('Pages written: ${result.pagesWritten}')
      ..writeln('Assets copied: ${result.assetsCopied}');

    return 0;
  } on FormatException catch (e) {
    stderr.writeln('Invalid manifest: $e');
    return 1;
  } catch (e) {
    stderr.writeln('SSG failed: $e');
    return 1;
  }
}
