// Hydraline showcase - the island entry-point.
//
// Built separately so the island bundle stays small:
//   flutter build web --target=lib/island_main.dart
//
// The dispatcher (hydraline-dispatcher.js) loads the engine on the first
// island trigger and calls app.addView() per island with { islandId, state }
// initialData; IslandMultiViewApp resolves the binding for every view and
// mounts the matching factory.
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

import 'islands/calculator.dart' deferred as calculator;

void main() {
  runWidget(
    IslandMultiViewApp(
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
