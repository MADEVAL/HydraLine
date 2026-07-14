// Hydraline showcase - the Flutter Web side.
//
// The same widgets render the visual UI at runtime and register semantic
// HTML during SSG extraction. Nothing here replaces MaterialApp or your
// router: Hydraline is additive.
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  runApp(const DemoShopApp());
}

class DemoShopApp extends StatelessWidget {
  const DemoShopApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hydraline Demo Shop',
    routes: {
      '/': (_) => const HomePage(),
      '/product': (_) => const ProductPage(id: 'espresso'),
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HydraApp(
      child: ListView(
        children: [
          Seo.head(
            const SeoMeta(
              title: 'Hydraline Demo Shop',
              description: 'A Flutter Web shop with real, crawlable HTML.',
            ),
          ),
          Seo.heading('Hydraline Demo Shop', level: 1),
          Seo.text('Static HTML loads instantly; islands hydrate on demand.'),
          Seo.link(href: '/product/espresso', child: const Text('Espresso')),
          Seo.link(href: '/product/grinder', child: const Text('Grinder')),
        ],
      ),
    ),
  );
}

class ProductPage extends StatelessWidget {
  const ProductPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HydraApp(
      child: ListView(
        children: [
          Seo.head(SeoMeta(title: 'Product - $id')),
          Seo.heading('Product: $id', level: 1),
          Seo.image(
            '/img/$id.jpg',
            alt: 'Photo of $id',
            width: 800,
            height: 600,
          ),

          // Level 2 island: the Flutter engine loads only when this becomes
          // visible. The reserved size prevents layout shift.
          Island(
            id: 'calculator-$id',
            type: IslandType.flutter,
            directive: HydrationDirective.onVisible,
            props: const {'price': 249},
            width: 640,
            height: 320,
          ),

          // Level 1 island: vanilla JS accordion, no Flutter engine at all.
          Island(
            id: 'faq-$id',
            type: IslandType.vanilla,
            props: const {'kind': 'accordion'},
          ),
        ],
      ),
    ),
  );
}
