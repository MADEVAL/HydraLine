import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  late SsgCollector collector;

  setUp(() {
    collector = SsgCollector('/test');
  });

  DocumentRootNode seal() => collector.seal() as DocumentRootNode;

  Widget sandbox(Widget child) =>
      SsgSandbox(collector: collector, child: child);

  group('Seo.text', () {
    testWidgets('registers plain text as ParagraphNode', (tester) async {
      await tester.pumpWidget(sandbox(Seo.text('Hello')));
      expect(seal().body[0], isA<ParagraphNode>());
    });

    testWidgets('register as HeadingNode when headingLevel is given', (
      tester,
    ) async {
      await tester.pumpWidget(sandbox(Seo.text('Title', headingLevel: 1)));
      final node = seal().body[0] as HeadingNode;
      expect(node.level, 1);
    });
  });

  group('Seo.heading', () {
    testWidgets('registers HeadingNode', (tester) async {
      await tester.pumpWidget(sandbox(Seo.heading('Hello', level: 2)));
      final node = seal().body[0] as HeadingNode;
      expect(node.level, 2);
    });
  });

  group('Seo.image', () {
    testWidgets('registers ImageNode with alt and dimensions', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.image('/img/a.png', alt: 'A', width: 640, height: 480)),
      );
      final node = seal().body[0] as ImageNode;
      expect(node.alt, 'A');
      expect(node.width, 640);
      expect(node.height, 480);
    });

    testWidgets('renders an Image widget at runtime', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.image('/img/a.png', alt: 'A', width: 64, height: 48)),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'A');
    });
  });

  group('Seo.link', () {
    testWidgets('registers AnchorNode with text child', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.link(href: '/about', child: const Text('About'))),
      );
      final node = seal().body[0] as AnchorNode;
      expect(node.href.value, '/about');
    });

    testWidgets('extracts the label from a Text child', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.link(href: '/about', child: const Text('About me'))),
      );
      final node = seal().body[0] as AnchorNode;
      final html = const HtmlSerializer().serializeFragment(node);
      expect(html, '<a href="/about">About me</a>');
    });

    testWidgets('tap invokes the provided onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HydraApp(
            child: Seo.link(
              href: '/about',
              onTap: () => tapped = true,
              child: const Text('About'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('About'));
      expect(tapped, isTrue);
    });

    testWidgets('tap navigates to an internal href by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (_) => HydraApp(
              child: Seo.link(href: '/about', child: const Text('About')),
            ),
            '/about': (_) => const Text('about page'),
          },
        ),
      );
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(find.text('about page'), findsOneWidget);
    });

    testWidgets('exposes link semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HydraApp(
            child: Seo.link(href: '/about', child: const Text('About')),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.text('About'));
      expect(semantics.flagsCollection.isLink, isTrue);
    });
  });

  group('Seo.section', () {
    testWidgets('registers children via the flat collector', (tester) async {
      await tester.pumpWidget(
        sandbox(
          Seo.section(role: SectionRole.main, children: [Seo.text('content')]),
        ),
      );
      final body = seal().body;
      expect(body, hasLength(1));
      expect(body[0], isA<ParagraphNode>());
    });
  });

  group('Seo.list', () {
    testWidgets('registers items via flat collector', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.list(ordered: true, items: [Seo.text('a'), Seo.text('b')])),
      );
      expect(seal().body, hasLength(2));
    });
  });

  group('Seo.head', () {
    testWidgets('registers meta and title in the collector', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.head(const SeoMeta(title: 'Page Title'))),
      );
      final root = seal();
      expect(root.head, isNotNull);
      final headHtml = const HtmlSerializer().serializeFragment(root.head!);
      expect(headHtml, contains('<title>Page Title</title>'));
    });
  });

  group('Island widget', () {
    testWidgets('registers IslandPlaceholderNode with id and props', (
      tester,
    ) async {
      await tester.pumpWidget(
        sandbox(
          Island(
            id: 'calc',
            type: IslandType.flutter,
            props: {'price': 100},
            width: 640,
            height: 480,
          ),
        ),
      );
      final node = seal().body[0] as IslandPlaceholderNode;
      expect(node.id, 'calc');
      expect(node.state['price'], 100);
      expect(node.size!.width, 640);
      expect(node.size!.height, 480);
    });

    testWidgets('renders a placeholder widget', (tester) async {
      await tester.pumpWidget(
        sandbox(Island(id: 'calc', type: IslandType.flutter)),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('registers default hydration directive as onIdle', (
      tester,
    ) async {
      await tester.pumpWidget(
        sandbox(Island(id: 'calc', type: IslandType.flutter)),
      );
      final node = seal().body[0] as IslandPlaceholderNode;
      expect(node.directive, HydrationDirective.onIdle);
    });

    testWidgets('registers custom hydration directive', (tester) async {
      await tester.pumpWidget(
        sandbox(
          Island(
            id: 'calc',
            type: IslandType.flutter,
            directive: HydrationDirective.onLoad,
          ),
        ),
      );
      final node = seal().body[0] as IslandPlaceholderNode;
      expect(node.directive, HydrationDirective.onLoad);
    });

    testWidgets('registers default render mode as ssr', (tester) async {
      await tester.pumpWidget(
        sandbox(Island(id: 'calc', type: IslandType.flutter)),
      );
      final node = seal().body[0] as IslandPlaceholderNode;
      expect(node.renderMode, IslandRenderMode.ssr);
    });

    testWidgets('registers custom render mode', (tester) async {
      await tester.pumpWidget(
        sandbox(
          Island(
            id: 'calc',
            type: IslandType.flutter,
            renderMode: IslandRenderMode.skeletonOnly,
          ),
        ),
      );
      final node = seal().body[0] as IslandPlaceholderNode;
      expect(node.renderMode, IslandRenderMode.skeletonOnly);
    });

    testWidgets('vanilla island registers its kind', (tester) async {
      await tester.pumpWidget(
        sandbox(Island(id: 'faq', type: IslandType.vanilla, kind: 'accordion')),
      );
      final node = seal().body[0] as VanillaIslandNode;
      expect(node.kind, 'accordion');
      final html = const HtmlSerializer().serializeFragment(node);
      expect(html, contains('data-island="accordion"'));
    });

    testWidgets('htmx island registers its endpoint', (tester) async {
      await tester.pumpWidget(
        sandbox(
          Island(id: 'reviews', type: IslandType.htmx, endpoint: '/api/r'),
        ),
      );
      final node = seal().body[0] as HtmxIslandNode;
      expect(node.endpoint, '/api/r');
    });

    test('vanilla island without a kind fails fast', () {
      expect(
        () => Island(id: 'faq', type: IslandType.vanilla),
        throwsAssertionError,
      );
    });

    test('htmx island without an endpoint fails fast', () {
      expect(
        () => Island(id: 'reviews', type: IslandType.htmx),
        throwsAssertionError,
      );
    });
  });
}
