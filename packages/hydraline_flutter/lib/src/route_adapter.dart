/// Routing adapters connecting go_router / Navigator 2.0 to the route manifest
/// for build-time traversal.
///
// ignore_for_file: avoid_dynamic_calls
library;

/// A single route descriptor.
class RouteInfo {
  const RouteInfo({required this.path, this.name});

  final String path;
  final String? name;
}

/// Interface: any router can provide the list of routes the SSG runner
/// should iterate over for extraction.
abstract interface class RouteAdapter {
  List<RouteInfo> get routes;

  /// Drives the underlying router to [route] so a widget-based extractor can
  /// pump the tree for that location. Returns once navigation is dispatched.
  Future<void> navigateToForExtraction(RouteInfo route);
}

/// First-class go_router adapter: wraps a `go_router` object and reads its
/// route configuration. The constructor accepts `Object` so the package does
/// not need an explicit `go_router` dependency - route extraction works
/// at runtime via reflection-ish inspection of the `GoRouter.routes` property.
class GoRouterAdapter implements RouteAdapter {
  GoRouterAdapter(this._goRouter);
  final Object _goRouter;

  @override
  List<RouteInfo> get routes {
    try {
      final router = _goRouter;
      final config = (router as dynamic).configuration as dynamic;
      final routeList = config.routes as List<dynamic>?;
      if (routeList == null) {
        return const [];
      }
      return [for (final r in routeList) RouteInfo(path: r.path as String)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> navigateToForExtraction(RouteInfo route) async {
    try {
      (_goRouter as dynamic).go(route.path);
    } catch (_) {
      // Router does not expose go(); nothing to drive.
    }
  }
}

/// Fallback for bare Navigator 2.0 applications.
class Navigator2Adapter implements RouteAdapter {
  Navigator2Adapter(List<RouteInfo> routes)
    : _routes = List.unmodifiable(routes);

  final List<RouteInfo> _routes;
  RouteInfo? _current;

  @override
  List<RouteInfo> get routes => _routes;

  /// The route most recently passed to [navigateToForExtraction], or `null`
  /// before any navigation. Read by widget-based extractors to know which
  /// location the tree is currently pumped for.
  RouteInfo? get current => _current;

  @override
  Future<void> navigateToForExtraction(RouteInfo route) async {
    _current = route;
  }
}
