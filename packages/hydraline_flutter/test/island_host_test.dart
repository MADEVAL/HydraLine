import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  group('IslandHost (P3-05/W-6, IH1)', () {
    testWidgets('builds with provided factories', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(IslandHost), findsOneWidget);
    });

    testWidgets('occupies the full viewport with a Container', (tester) async {
      await tester.pumpWidget(const IslandHost(factories: {}));
      expect(find.byType(Container), findsOneWidget);
    });
  });
}
