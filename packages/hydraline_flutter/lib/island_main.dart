/// Separate island entry-point (`flutter build web --target=lib/island_main.dart`).
///
/// This file owns only the island runtime: [IslandMultiViewApp] +
/// per-island factories. It does NOT include MaterialApp, the main app
/// router, or business logic, keeping the island bundle small.
///
/// The Hydraline dispatcher (`hydraline-dispatcher.js`) loads the engine on
/// the first island trigger and calls `app.addView()` per island; the
/// multi-view root mounts the matching factory in each view.
library;

import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

/// Placeholder factories - developers replace these with their actual deferred
/// island constructors.
final Map<String, IslandFactory> islandFactories = {};

void main() {
  runWidget(IslandMultiViewApp(factories: islandFactories));
}

void islandEntryPoint() {
  main();
}
