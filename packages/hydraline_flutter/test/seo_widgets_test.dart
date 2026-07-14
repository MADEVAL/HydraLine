import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline/hydraline.dart';
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
  });

  group('Seo.link', () {
    testWidgets('registers AnchorNode with text child', (tester) async {
      await tester.pumpWidget(
        sandbox(Seo.link(href: '/about', child: const Text('About'))),
      );
      final node = seal().body[0] as AnchorNode;
      expect(node.href.value, '/about');
    });
  });

  group('Seo.section', () {
    testWidgets('registers sentinel + children via flat collector', (
      tester,
    ) async {
      await tester.pumpWidget(
        sandbox(
          Seo.section(role: SectionRole.main, children: [Seo.text('content')]),
        ),
      );
      expect(seal().body, hasLength(2));
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
  });
}
