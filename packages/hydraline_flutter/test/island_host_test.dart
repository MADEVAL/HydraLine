import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:hydraline_flutter/island_main.dart';

void main() {
  group('IslandHost', () {
    testWidgets('builds with provided factories', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(IslandHost), findsOneWidget);
    });

    testWidgets('occupies the full viewport with a Container', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
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
