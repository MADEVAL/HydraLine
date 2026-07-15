@Tags(['ssg'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  group('SSG extraction', () {
    testWidgets('extracts heading and paragraph nodes', (tester) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: Column(
            children: [
              Seo.heading('Page Title', level: 1),
              Seo.text('A paragraph of content.'),
            ],
          ),
        ),
      );
      await tester.pump();
      final root = collector.seal() as DocumentRootNode;
      expect(root.body, hasLength(2));
      expect(root.body[0], isA<HeadingNode>());
      expect(root.body[1], isA<ParagraphNode>());
    });

    testWidgets('extracts image node with attributes', (tester) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: Seo.image(
            '/img/photo.jpg',
            alt: 'A photo',
            width: 800,
            height: 600,
          ),
        ),
      );
      await tester.pump();
      final root = collector.seal() as DocumentRootNode;
      final img = root.body[0] as ImageNode;
      expect(img.alt, 'A photo');
      expect(img.width, 800);
      expect(img.height, 600);
    });

    testWidgets('extracts head metadata', (tester) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: Seo.head(const SeoMeta(title: 'Home', description: 'A page')),
        ),
      );
      await tester.pump();
      final root = collector.seal() as DocumentRootNode;
      expect(root.head, isNotNull);
      final headHtml = const HtmlSerializer().serializeFragment(root.head!);
      expect(headHtml, contains('<title>Home</title>'));
      expect(headHtml, contains('<meta name="description" content="A page">'));
    });
  });

  group('Golden A<->B equivalence', () {
    testWidgets(
      'Seo widgets produce the same DocumentNode as a pure-Dart builder',
      (tester) async {
        final collector = SsgCollector('/test');
        await tester.pumpWidget(
          SsgSandbox(
            collector: collector,
            child: Column(
              children: [
                Seo.heading('Title', level: 1),
                Seo.text('A <paragraph>.'),
                Seo.image('/img/x.png', alt: 'x', width: 100, height: 200),
              ],
            ),
          ),
        );
        await tester.pump();
        final rootA = collector.seal() as DocumentRootNode;

        final rootB = DocumentRootNode(
          body: [
            const HeadingNode(level: 1, children: [TextNode('Title')]),
            const ParagraphNode(children: [TextNode('A <paragraph>.')]),
            ImageNode(
              src: SafeUrl.parse('/img/x.png'),
              alt: 'x',
              width: 100,
              height: 200,
            ),
          ],
        );

        final htmlA = const HtmlSerializer().serialize(rootA);
        final htmlB = const HtmlSerializer().serialize(rootB);
        expect(htmlA, htmlB);
      },
    );
  });

  group('Island widget SSG extraction', () {
    testWidgets('Island with mediaQuery registers an island node', (
      tester,
    ) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: const Island(
            id: 'responsive',
            type: IslandType.flutter,
            mediaQuery: '(min-width: 800px)',
          ),
        ),
      );
      await tester.pump();
      final root = collector.seal() as DocumentRootNode;
      expect(root.body, hasLength(1));
      final island = root.body[0] as IslandPlaceholderNode;
      expect(island.id, 'responsive');
    });

    testWidgets('mediaQuery reaches the serialized HTML as data-media', (
      tester,
    ) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: const Island(
            id: 'responsive',
            type: IslandType.flutter,
            directive: HydrationDirective.onMedia,
            mediaQuery: '(min-width: 800px)',
          ),
        ),
      );
      await tester.pump();
      final root = collector.seal() as DocumentRootNode;
      final html = const HtmlSerializer().serialize(root);
      expect(html, contains('data-directive="hydrateOnMedia"'));
      expect(html, contains('data-media="(min-width: 800px)"'));
    });
  });

  group('full extraction pipeline', () {
    testWidgets('navigates adapter, pumps widget tree, seals and audits', (
      tester,
    ) async {
      // Surface A: a minimal app using Seo.* widgets and HydraApp.
      // The adapter navigates per route; the collector seals into HTML;
      // the audit validates SEO invariants.
      final routes = [
        RouteInfo(path: '/', name: 'home'),
        RouteInfo(path: '/about', name: 'about'),
      ];
      final adapter = Navigator2Adapter(routes);

      for (final route in routes) {
        await adapter.navigateToForExtraction(route);

        final collector = SsgCollector(route.path);
        await tester.pumpWidget(
          SsgSandbox(
            collector: collector,
            child: HydraApp(
              collector: collector,
              child: Builder(
                builder: (context) {
                  final scope = HydraScope.of(context);
                  return scope.isSsgMode
                      ? Column(
                          children: [
                            Seo.head(SeoMeta(title: route.path)),
                            Seo.heading('Title ${route.path}', level: 1),
                            Seo.text('Content of ${route.path}'),
                          ],
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        final root = collector.seal() as DocumentRootNode;
        final html = const HtmlSerializer().serialize(root);

        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('<h1>Title ${route.path}</h1>'));
        expect(html, contains('<title>${route.path}</title>'));

        final report = Audit.auditHtml(html);
        expect(report.exitCode, 0, reason: report.issues.join('\n'));
      }
    });
  });
}
