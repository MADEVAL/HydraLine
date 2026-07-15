import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_example/main.dart';

void main() {
  testWidgets('home page renders the shop heading and product links', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoShopApp());
    expect(find.text('Hydraline Demo Shop'), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('Grinder'), findsOneWidget);
  });

  testWidgets('tapping a product link navigates to the product page', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoShopApp());
    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();
    expect(find.text('Product: espresso'), findsOneWidget);
  });

  testWidgets('the dynamic route serves any product id', (tester) async {
    await tester.pumpWidget(const DemoShopApp());
    await tester.tap(find.text('Grinder'));
    await tester.pumpAndSettle();
    expect(find.text('Product: grinder'), findsOneWidget);
  });

  testWidgets('home page uses Seo.section and Seo.list for semantic HTML', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoShopApp());
    expect(
      find.text('Real headings, paragraphs, images with alt'),
      findsOneWidget,
    );
    expect(
      find.text('Sectioning elements: <main>, <nav>, <article>'),
      findsOneWidget,
    );
  });
}
