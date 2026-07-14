// Hydraline showcase - the static site build (SSG, pure Dart).
//
// Run with: dart run hydraline_example:build hydraline.routes.yaml dist
//
// The route manifest drives which pages exist; the pure-Dart builders in
// lib/content.dart provide the full page content - the same trees the SSR
// server streams at request time.
import 'dart:io';

import 'package:hydraline_example/content.dart';
import 'package:hydraline_flutter/build.dart';

void main(List<String> args) async {
  final manifestPath = args.isNotEmpty ? args[0] : 'hydraline.routes.yaml';
  final outputDir = args.length > 1 ? args[1] : 'dist';

  exitCode = await runSsgCli(
    manifestPath: manifestPath,
    outputDir: outputDir,
    adapter: Navigator2Adapter([]),
    islandFactories: {'calculator': IslandType.flutter},
    builders: {
      '/': (path) => homePage(),
      '/product/:id': (path) => productPage(path.split('/').last),
    },
  );
}
