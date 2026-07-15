/// IslandHost - root multi-view widget for the island engine.
///
/// One Flutter engine instance hosts N islands in N views. The `factories`
/// map island IDs to async builder functions; heavy islands use deferred
/// `loadLibrary()` inside the factory. The JavaScript dispatcher creates a
/// `FlutterView` per hydrated island via `app.addView()` and passes
/// `{ islandId, state }` as initialData; [IslandMultiViewApp] turns that into
/// an [IslandViewRegistry] binding and [IslandHost] mounts the matching
/// island widget inside each view.
library;

import 'package:flutter/material.dart';

import 'island_binding.dart' show registerViewBindingFromPlatform;

/// A factory that asynchronously builds an island widget from its props.
typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

/// A view → island binding: which island an engine view hosts, plus the
/// deserialized `data-state` props.
typedef IslandViewBinding = ({String islandId, Map<String, Object?> state});

/// Maps `FlutterView` IDs to island bindings.
///
/// Populated by the web bootstrap when the dispatcher calls `addView()` for a
/// hydrating island; read by [IslandHost] to decide which island widget to
/// mount in each view.
abstract final class IslandViewRegistry {
  static final Map<int, IslandViewBinding> _bindings = {};

  /// Binds [viewId] to the island [islandId] with its `data-state` [state].
  static void register(
    int viewId,
    String islandId, [
    Map<String, Object?> state = const {},
  ]) {
    _bindings[viewId] = (islandId: islandId, state: state);
  }

  /// Removes the binding for [viewId] (no-op when absent).
  static void unregister(int viewId) {
    _bindings.remove(viewId);
  }

  /// Returns the binding for [viewId], or `null` when the view hosts no
  /// island.
  static IslandViewBinding? lookup(int viewId) => _bindings[viewId];

  /// Removes all bindings (used between hot restarts and in tests).
  static void clear() => _bindings.clear();
}

/// The root widget of the island entry-point. Resolves the island bound to
/// the current view via [IslandViewRegistry] and mounts it through the
/// matching factory from [factories]. Falls back to a full-viewport
/// `Container` when the view has no island binding.
class IslandHost extends StatelessWidget {
  const IslandHost({required this.factories, super.key});

  final Map<String, IslandFactory> factories;

  @override
  Widget build(BuildContext context) {
    final viewId = View.of(context).viewId;
    final binding = IslandViewRegistry.lookup(viewId);
    final factory = binding == null ? null : factories[binding.islandId];
    if (binding == null || factory == null) {
      return Container(width: double.infinity, height: double.infinity);
    }
    final Future<Widget> future;
    try {
      future = factory(binding.state);
    } catch (_) {
      return const SizedBox.expand();
    }
    return FutureBuilder<Widget>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.expand();
        }
        return snapshot.data ?? const SizedBox.expand();
      },
    );
  }
}

/// The multi-view root for the island entry-point (`runWidget`-compatible).
///
/// Builds one [View] per `FlutterView` reported by the platform dispatcher
/// and rebuilds when views are added or removed (the dispatcher's
/// `addView()`/`removeView()` calls). For every view it first resolves the
/// island binding - from [IslandViewRegistry], or from the platform
/// `initialData` on the web - and then delegates to [IslandHost].
class IslandMultiViewApp extends StatefulWidget {
  const IslandMultiViewApp({required this.factories, super.key});

  final Map<String, IslandFactory> factories;

  @override
  State<IslandMultiViewApp> createState() => _IslandMultiViewAppState();
}

class _IslandMultiViewAppState extends State<IslandMultiViewApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Fired when views are added/removed; rebuild the view collection.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    for (final view in views) {
      registerViewBindingFromPlatform(view.viewId);
    }
    return ViewCollection(
      views: [
        for (final view in views)
          View(
            view: view,
            child: IslandHost(factories: widget.factories),
          ),
      ],
    );
  }
}
