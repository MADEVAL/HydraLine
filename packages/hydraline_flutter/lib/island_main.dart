/// Separate island entry-point (`flutter build web --target=lib/island_main.dart`).
///
/// This file owns only the island runtime: [IslandHost] + per-island factories.
/// It does NOT include MaterialApp, the main app router, or business logic,
/// keeping the island bundle small (~450 KB gzip).
library;

import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

/// Placeholder factories — developers replace these with their actual deferred
/// island constructors.
final Map<String, IslandFactory> islandFactories = {};

void main() {
  runWidget(IslandHost(factories: islandFactories));
}

void islandEntryPoint() {
  main();
}
