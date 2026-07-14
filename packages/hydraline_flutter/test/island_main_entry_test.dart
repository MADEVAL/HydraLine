import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:hydraline_flutter/island_main.dart';

void main() {
  testWidgets('island entry point mounts IslandMultiViewApp', (tester) async {
    islandEntryPoint();
    await tester.pump();
    expect(find.byType(IslandMultiViewApp), findsOneWidget);
  });

  test('ships with no default factories (developers register their own)', () {
    expect(islandFactories, isEmpty);
  });
}
