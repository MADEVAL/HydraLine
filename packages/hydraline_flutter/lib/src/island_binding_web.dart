/// Web implementation: reads the `{ islandId, state }` initialData that the
/// Hydraline dispatcher passes to `app.addView()` and registers the binding
/// in [IslandViewRegistry].
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'island_host.dart' show IslandViewRegistry;

/// Registers the view -> island binding for [viewId] from the platform
/// `initialData`, when present. Malformed data never crashes the runtime.
void registerViewBindingFromPlatform(int viewId) {
  if (IslandViewRegistry.lookup(viewId) != null) {
    return;
  }
  try {
    final raw = ui_web.views.getInitialData(viewId);
    final data = raw?.dartify();
    if (data is! Map) {
      return;
    }
    final islandId = data['islandId'];
    if (islandId is! String || islandId.isEmpty) {
      return;
    }
    final state = data['state'];
    IslandViewRegistry.register(
      viewId,
      islandId,
      state is Map ? state.cast<String, Object?>() : const {},
    );
  } catch (_) {
    // Ignore malformed initialData; the island falls back to its skeleton.
  }
}
