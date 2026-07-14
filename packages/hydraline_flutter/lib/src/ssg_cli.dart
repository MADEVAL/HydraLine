/// SSG CLI: programmatic entry point that reads a manifest config and
/// invokes the SSG runner. Designed to be called from `bin/build.dart` or
/// from tests directly.
///
/// Deliberately imports only pure-Dart modules so `dart run
/// hydraline_flutter:build` works on the plain Dart VM.
library;

import 'dart:io';

import 'package:hydraline/hydraline.dart' show RouteManifest;

import 'route_adapter.dart' show RouteAdapter;
import 'ssg_runner.dart' show SsgPageBuilder, SsgRunner;

Future<int> runSsgCli({
  required String manifestPath,
  required String outputDir,
  required Map<String, Object?> islandFactories,
  RouteAdapter? adapter,
  Map<String, SsgPageBuilder> builders = const {},
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
      builders: builders,
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
