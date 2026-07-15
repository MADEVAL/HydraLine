import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:hydraline_flutter/island_main.dart';

void main() {
  tearDown(IslandViewRegistry.clear);

  group('IslandHost', () {
    testWidgets('builds with provided factories', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(IslandHost), findsOneWidget);
    });

    testWidgets('occupies the full viewport with a Container', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('mounts the island widget bound to the current view', (
      tester,
    ) async {
      IslandViewRegistry.register(tester.view.viewId, 'calc', {'price': 100});
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IslandHost(
            factories: {
              'calc': (props) async => Text('price: ${props['price']}'),
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('price: 100'), findsOneWidget);
    });

    testWidgets('renders the fallback container for an unknown island id', (
      tester,
    ) async {
      IslandViewRegistry.register(tester.view.viewId, 'missing');
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('renders a fallback when the factory throws synchronously', (
      tester,
    ) async {
      IslandViewRegistry.register(tester.view.viewId, 'boom');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IslandHost(
            factories: {'boom': (props) => throw StateError('sync boom')},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders a fallback when the factory future rejects', (
      tester,
    ) async {
      IslandViewRegistry.register(tester.view.viewId, 'boom');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IslandHost(
            factories: {
              'boom': (props) async => throw StateError('async boom'),
            },
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('IslandViewRegistry', () {
    test('register/lookup/unregister lifecycle', () {
      IslandViewRegistry.register(7, 'hero', {'a': 1});
      final binding = IslandViewRegistry.lookup(7);
      expect(binding, isNotNull);
      expect(binding!.islandId, 'hero');
      expect(binding.state['a'], 1);

      IslandViewRegistry.unregister(7);
      expect(IslandViewRegistry.lookup(7), isNull);
    });

    test('clear removes all bindings', () {
      IslandViewRegistry.register(1, 'a');
      IslandViewRegistry.register(2, 'b');
      IslandViewRegistry.clear();
      expect(IslandViewRegistry.lookup(1), isNull);
      expect(IslandViewRegistry.lookup(2), isNull);
    });
  });

  group('IslandMultiViewApp', () {
    testWidgets('hosts one IslandHost per platform view', (tester) async {
      IslandViewRegistry.register(tester.view.viewId, 'calc', {'price': 7});
      await tester.pumpWidget(
        IslandMultiViewApp(
          factories: {
            'calc': (props) async => Directionality(
              textDirection: TextDirection.ltr,
              child: Text('total ${props['price']}'),
            ),
          },
        ),
        wrapWithView: false,
      );
      await tester.pump();
      expect(find.byType(IslandHost), findsOneWidget);
      expect(find.text('total 7'), findsOneWidget);
    });

    testWidgets('renders the fallback for views without a binding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const IslandMultiViewApp(factories: {}),
        wrapWithView: false,
      );
      expect(find.byType(Container), findsOneWidget);
    });
  });

  group('island_main entry point', () {
    test('islandFactories is a map', () {
      expect(islandFactories, isA<Map<String, IslandFactory>>());
      expect(islandFactories, isEmpty);
    });

    test('main and islandEntryPoint are callable functions', () {
      expect(main, isA<void Function()>());
      expect(islandEntryPoint, isA<void Function()>());
    });
  });
}
