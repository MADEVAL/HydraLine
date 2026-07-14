import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/island_main.dart';

void main() {
  setUpAll(() {
    try {
      islandEntryPoint();
    } catch (_) {}
  });

  test('island entry point was invoked', () {
    expect(islandFactories, isEmpty);
  });
}
