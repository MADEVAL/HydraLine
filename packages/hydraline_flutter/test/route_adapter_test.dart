import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

class _MockGoRoute {
  const _MockGoRoute(this.path);
  final String path;
}

class _MockConfig {
  const _MockConfig(this.routes);
  final List<_MockGoRoute>? routes;
}

class _MockRouter {
  const _MockRouter(this.configuration);
  final _MockConfig configuration;
}

class _NavRecordingRouter {
  _NavRecordingRouter(this.configuration);
  final _MockConfig configuration;
  final List<String> navigated = [];
  void go(String location) => navigated.add(location);
}

void main() {
  group('RouteAdapter', () {
    test('RouteInfo stores path and optional name', () {
      const info = RouteInfo(path: '/blog/', name: 'blog');
      expect(info.path, '/blog/');
      expect(info.name, 'blog');
    });

    test('Navigator2Adapter is a RouteAdapter', () {
      final adapter = Navigator2Adapter([]);
      expect(adapter, isA<RouteAdapter>());
      expect(adapter.routes, isEmpty);
    });

    test('Navigator2Adapter with routes', () {
      const routes = [RouteInfo(path: '/', name: 'home')];
      final adapter = Navigator2Adapter(routes);
      expect(adapter.routes, hasLength(1));
      expect(adapter.routes[0].path, '/');
    });

    test(
      'GoRouterAdapter constructor accepts an object and is a RouteAdapter',
      () {
        final adapter = GoRouterAdapter(const Object());
        expect(adapter, isA<RouteAdapter>());
      },
    );

    test('GoRouterAdapter returns empty list when object has no routes', () {
      final adapter = GoRouterAdapter(const Object());
      expect(adapter.routes, isEmpty);
    });

    test('GoRouterAdapter.navigateToForExtraction completes', () async {
      final adapter = GoRouterAdapter(const Object());
      await adapter.navigateToForExtraction(const RouteInfo(path: '/'));
    });

    test(
      'GoRouterAdapter.navigateToForExtraction drives go() on the router',
      () async {
        final router = _NavRecordingRouter(_MockConfig([_MockGoRoute('/x')]));
        final adapter = GoRouterAdapter(router);
        await adapter.navigateToForExtraction(const RouteInfo(path: '/x'));
        expect(router.navigated, ['/x']);
      },
    );

    test('GoRouterAdapter.routes parses valid configuration', () {
      final mockRoute = _MockGoRoute('/test');
      final mockConfig = _MockConfig([mockRoute]);
      final mockRouter = _MockRouter(mockConfig);
      final adapter = GoRouterAdapter(mockRouter);
      final routes = adapter.routes;
      expect(routes, hasLength(1));
      expect(routes[0].path, '/test');
    });

    test('GoRouterAdapter.routes returns empty for null routeList', () {
      final mockConfig = _MockConfig(null);
      final mockRouter = _MockRouter(mockConfig);
      final adapter = GoRouterAdapter(mockRouter);
      expect(adapter.routes, isEmpty);
    });

    test('Navigator2Adapter.navigateToForExtraction completes', () async {
      final adapter = Navigator2Adapter([const RouteInfo(path: '/')]);
      await adapter.navigateToForExtraction(const RouteInfo(path: '/'));
    });

    test('Navigator2Adapter records the last navigated route', () async {
      final adapter = Navigator2Adapter([const RouteInfo(path: '/')]);
      expect(adapter.current, isNull);
      await adapter.navigateToForExtraction(const RouteInfo(path: '/a'));
      expect(adapter.current?.path, '/a');
    });
  });
}
