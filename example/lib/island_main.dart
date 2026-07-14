// Hydraline showcase — the island entry-point.
//
// Built separately so the island bundle stays small:
//   flutter build web --target=lib/island_main.dart
//
// The JS dispatcher creates one FlutterView per hydrated island and registers
// the binding in IslandViewRegistry; IslandHost mounts the right factory.
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

import 'islands/calculator.dart' deferred as calculator;

void main() {
  runWidget(
    IslandHost(
      factories: {
        'calculator-espresso': _calculator,
        'calculator-grinder': _calculator,
      },
    ),
  );
}

Future<Widget> _calculator(Map<String, Object?> props) async {
  await calculator.loadLibrary();
  return calculator.CalculatorIsland(price: props['price']! as int);
}
