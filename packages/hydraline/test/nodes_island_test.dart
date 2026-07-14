import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('Island enums', () {
    test('IslandType values', () {
      expect(IslandType.values, [
        IslandType.flutter,
        IslandType.vanilla,
        IslandType.htmx,
      ]);
    });

    test('HydrationDirective values', () {
      expect(HydrationDirective.values, [
        HydrationDirective.onLoad,
        HydrationDirective.onIdle,
        HydrationDirective.onVisible,
        HydrationDirective.onInteraction,
        HydrationDirective.onMedia,
        HydrationDirective.manual,
      ]);
    });

    test('IslandRenderMode and IslandStyleMode values', () {
      expect(IslandRenderMode.values, [
        IslandRenderMode.ssr,
        IslandRenderMode.skeletonOnly,
      ]);
      expect(IslandStyleMode.values, [
        IslandStyleMode.shadow,
        IslandStyleMode.scoped,
      ]);
    });
  });

  test('IslandSize carries px width/height (anti-CLS, I8)', () {
    const size = IslandSize(width: 640, height: 480);
    expect(size.width, 640);
    expect(size.height, 480);
  });

  group('IslandPlaceholderNode (Flutter island)', () {
    test('applies documented defaults', () {
      const island = IslandPlaceholderNode(id: 'calc');
      expect(island.id, 'calc');
      expect(island.directive, HydrationDirective.onIdle);
      expect(island.renderMode, IslandRenderMode.ssr);
      expect(island.styleMode, IslandStyleMode.shadow);
      expect(island.size, isNull);
      expect(island.state, isEmpty);
      expect(island.mediaQuery, isNull);
      expect(island.fallback, isEmpty);
      expect(island.children, isEmpty);
    });

    test('fallback is exposed as children', () {
      const fallback = [
        ParagraphNode(children: [TextNode('loading')]),
      ];
      const island = IslandPlaceholderNode(id: 'calc', fallback: fallback);
      expect(island.children, fallback);
    });

    test('carries state and explicit hydration options', () {
      const island = IslandPlaceholderNode(
        id: 'calc',
        directive: HydrationDirective.onVisible,
        renderMode: IslandRenderMode.skeletonOnly,
        styleMode: IslandStyleMode.scoped,
        size: IslandSize(width: 320, height: 200),
        state: {'price': 100},
      );
      expect(island.directive, HydrationDirective.onVisible);
      expect(island.renderMode, IslandRenderMode.skeletonOnly);
      expect(island.styleMode, IslandStyleMode.scoped);
      expect(island.size!.width, 320);
      expect(island.state['price'], 100);
    });
  });

  group('HtmxIslandNode', () {
    test('applies defaults (trigger=load, swap=innerHTML)', () {
      const island = HtmxIslandNode(id: 'reviews', endpoint: '/api/reviews');
      expect(island.endpoint, '/api/reviews');
      expect(island.trigger, 'load');
      expect(island.swap, 'innerHTML');
      expect(island.target, isNull);
      expect(island.children, isEmpty);
    });

    test('fallback is exposed as children', () {
      const fallback = [
        ParagraphNode(children: [TextNode('loading')]),
      ];
      const island = HtmxIslandNode(
        id: 'reviews',
        endpoint: '/api/reviews',
        fallback: fallback,
      );
      expect(island.children, fallback);
    });
  });

  group('VanillaIslandNode', () {
    test('carries kind, config and children', () {
      const island = VanillaIslandNode(
        id: 'tabs1',
        kind: 'tabs',
        config: {'active': 0},
        children: [TextNode('tab')],
      );
      expect(island.kind, 'tabs');
      expect(island.config['active'], 0);
      expect(island.children, hasLength(1));
    });
  });
}
