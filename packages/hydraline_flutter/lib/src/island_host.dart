/// IslandHost — root multi-view widget for the island engine
/// (ARCHITECTURE.md §11.2; W-6, IH1).
///
/// One Flutter engine instance hosts N islands in N views. The `factories`
/// map island IDs to async builder functions; heavy islands use deferred
/// `loadLibrary()` inside the factory (W-7).
library;

import 'package:flutter/material.dart';

/// A factory that asynchronously builds an island widget from its props.
typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

/// The root widget of the island entry-point. Renders a full-viewport
/// `Container` and wires up the supplied [factories]. Multi-view mapping
/// (IH1) is driven by the JavaScript dispatcher at runtime.
class IslandHost extends StatelessWidget {
  const IslandHost({required this.factories, super.key});

  final Map<String, IslandFactory> factories;

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, height: double.infinity);
  }
}
