import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  group('RouteAdapter (P3-07, W-5)', () {
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
  });
}
