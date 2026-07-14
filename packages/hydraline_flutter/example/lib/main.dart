// Hydraline Flutter example: a product page built with Seo.* widgets and
// islands. The same widgets render visually at runtime and register semantic
// HTML during SSG extraction.
//
// SSG extraction runs inside flutter_tester - see the package README.
// Static build: dart run hydraline_flutter:build hydraline.routes.yaml dist
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  runApp(const MaterialApp(home: ProductPage()));
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HydraApp(
      // At runtime `collector` is null - widgets just render.
      // During SSG extraction a SsgCollector instance is injected and the
      // same widgets self-register their semantic content.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route metadata - renders nothing, registers <head> content.
            Seo.head(
              const SeoMeta(
                title: 'Espresso Machine - Barista Shop',
                description: 'Compact 15-bar espresso machine.',
              ),
            ),

            // Semantic content: headings, text, images, links.
            Seo.heading('Espresso Machine', level: 1),
            Seo.text('Compact 15-bar espresso machine with a milk frother.'),
            Seo.image(
              '/img/espresso.jpg',
              alt: 'Espresso machine, front view',
              width: 800,
              height: 600,
            ),
            Seo.link(href: '/catalog', child: const Text('Back to catalog')),

            Seo.section(
              role: SectionRole.section,
              children: [
                Seo.heading('Specifications', level: 2),
                Seo.list(
                  ordered: false,
                  items: [
                    Seo.text('15-bar pump'),
                    Seo.text('1.5 L water tank'),
                    Seo.text('Steam milk frother'),
                  ],
                ),
              ],
            ),

            // Level 2: a Flutter island - the engine loads only when this
            // scrolls into the viewport. Size reservation prevents CLS.
            const Island(
              id: 'price-calculator',
              type: IslandType.flutter,
              directive: HydrationDirective.onVisible,
              props: {'price': 249, 'currency': 'EUR'},
              width: 640,
              height: 320,
            ),

            // Level 1: a vanilla JS accordion - no Flutter engine involved.
            const Island(
              id: 'faq',
              type: IslandType.vanilla,
              props: {'kind': 'accordion'},
            ),
          ],
        ),
      ),
    ),
  );
}

/// The island entry-point (built separately with
/// `flutter build web --target=lib/island_main.dart`): one engine, N views.
/// The dispatcher calls `app.addView()` per island with `{ islandId, state }`
/// initialData; [IslandMultiViewApp] mounts the matching factory per view.
void islandMain() {
  runWidget(
    IslandMultiViewApp(
      factories: {
        'price-calculator': (props) async =>
            PriceCalculator(price: props['price']! as int),
      },
    ),
  );
}

class PriceCalculator extends StatelessWidget {
  const PriceCalculator({required this.price, super.key});

  final int price;

  @override
  Widget build(BuildContext context) => Center(child: Text('Total: $price'));
}
