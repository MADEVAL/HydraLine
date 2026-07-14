// The island entry-point, built separately from the main app:
//   flutter build web --target=lib/island_main.dart --output=build/islands
// One engine instance hosts N islands in N views; the dispatcher calls
// app.addView() per island and IslandMultiViewApp mounts the matching factory.
import 'package:flutter/widgets.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

import 'main.dart' show PriceCalculator;

void main() {
  runWidget(
    IslandMultiViewApp(
      factories: {
        'price-calculator': (props) async =>
            PriceCalculator(price: props['price']! as int),
      },
    ),
  );
}
