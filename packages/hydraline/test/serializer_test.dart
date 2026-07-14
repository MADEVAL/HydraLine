import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  const s = HtmlSerializer();

  String frag(DocumentNode node) => s.serializeFragment(node);

  group('inline nodes', () {
    test('TextNode is escaped', () {
      expect(frag(const TextNode('A & <B>')), 'A &amp; &lt;B&gt;');
    });

    test('AnchorNode with and without rel', () {
      expect(
        frag(
          AnchorNode(
            href: SafeUrl.parse('/a'),
            children: const [TextNode('L')],
          ),
        ),
        '<a href="/a">L</a>',
      );
      expect(
        frag(
          AnchorNode(
            href: SafeUrl.parse('/a'),
            rel: 'nofollow',
            children: const [TextNode('L')],
          ),
        ),
        '<a href="/a" rel="nofollow">L</a>',
      );
    });

    test('ImageNode void element with escaped alt and optional size', () {
      expect(
        frag(ImageNode(src: SafeUrl.parse('/i.png'), alt: 'A "q"')),
        '<img src="/i.png" alt="A &quot;q&quot;">',
      );
      expect(
        frag(
          ImageNode(
            src: SafeUrl.parse('/i.png'),
            alt: 'A',
            width: 10,
            height: 20,
          ),
        ),
        '<img src="/i.png" alt="A" width="10" height="20">',
      );
    });
  });

  group('block nodes', () {
    test('HeadingNode', () {
      expect(
        frag(const HeadingNode(level: 2, children: [TextNode('A & <B>')])),
        '<h2>A &amp; &lt;B&gt;</h2>',
      );
    });

    test('ParagraphNode', () {
      expect(frag(const ParagraphNode(children: [TextNode('x')])), '<p>x</p>');
    });

    test('SectionNode roles map to semantic tags', () {
      expect(
        frag(
          const SectionNode(role: SectionRole.main, children: [TextNode('m')]),
        ),
        '<main>m</main>',
      );
      expect(
        frag(const SectionNode(role: SectionRole.article, children: [])),
        '<article></article>',
      );
    });

    test('ListNode ordered/unordered', () {
      const items = [
        ListItemNode(children: [TextNode('a')]),
        ListItemNode(children: [TextNode('b')]),
      ];
      expect(
        frag(const ListNode(ordered: true, items: items)),
        '<ol><li>a</li><li>b</li></ol>',
      );
      expect(
        frag(const ListNode(ordered: false, items: items)),
        '<ul><li>a</li><li>b</li></ul>',
      );
    });

    test('BlockquoteNode with cite', () {
      expect(
        frag(
          BlockquoteNode(
            children: const [TextNode('q')],
            cite: SafeUrl.parse('https://s.example/x'),
          ),
        ),
        '<blockquote cite="https://s.example/x">q</blockquote>',
      );
    });

    test('PreNode + CodeNode with language', () {
      expect(
        frag(const PreNode(children: [CodeNode('x();', language: 'dart')])),
        '<pre><code class="language-dart">x();</code></pre>',
      );
    });

    test('CodeNode text is escaped', () {
      expect(frag(const CodeNode('a<b>&c')), '<code>a&lt;b&gt;&amp;c</code>');
    });

    test('TimeNode', () {
      expect(
        frag(
          const TimeNode(dateTime: '2026-07-14', children: [TextNode('Jul')]),
        ),
        '<time datetime="2026-07-14">Jul</time>',
      );
    });

    test('TableNode with header and data cells', () {
      const table = TableNode(
        rows: [
          TableRowNode(
            cells: [
              TableCellNode(children: [TextNode('H')], header: true),
              TableCellNode(children: [TextNode('a')]),
            ],
          ),
        ],
      );
      expect(frag(table), '<table><tr><th>H</th><td>a</td></tr></table>');
    });

    test('DetailsNode open flag', () {
      const d = DetailsNode(
        summary: SummaryNode(children: [TextNode('S')]),
        children: [
          ParagraphNode(children: [TextNode('b')]),
        ],
        open: true,
      );
      expect(frag(d), '<details open><summary>S</summary><p>b</p></details>');
      const c = DetailsNode(
        summary: SummaryNode(children: [TextNode('S')]),
        children: [],
      );
      expect(frag(c), '<details><summary>S</summary></details>');
    });
  });

  group('head nodes', () {
    test('TitleNode escaped', () {
      expect(frag(const TitleNode('T & U')), '<title>T &amp; U</title>');
    });

    test('MetaNode charset / name / property', () {
      expect(frag(const MetaNode(charset: 'utf-8')), '<meta charset="utf-8">');
      expect(
        frag(const MetaNode(name: 'description', content: 'd')),
        '<meta name="description" content="d">',
      );
      expect(
        frag(const MetaNode(property: 'og:title', content: 'Home')),
        '<meta property="og:title" content="Home">',
      );
    });

    test('LinkNode with optional hreflang', () {
      expect(
        frag(LinkNode(rel: 'canonical', href: SafeUrl.parse('https://x/'))),
        '<link rel="canonical" href="https://x/">',
      );
      expect(
        frag(
          LinkNode(
            rel: 'alternate',
            href: SafeUrl.parse('https://x/en'),
            hreflang: 'en',
          ),
        ),
        '<link rel="alternate" href="https://x/en" hreflang="en">',
      );
    });
  });

  group('unsafe html', () {
    test('raw HTML is emitted verbatim when no sanitizer', () {
      expect(frag(const UnsafeHtmlNode('<b>x</b>')), '<b>x</b>');
    });

    test('sanitizer output is emitted', () {
      final node = UnsafeHtmlNode(
        '<script>x</script>ok',
        sanitizer: (raw) => raw.replaceAll(RegExp('</?script>'), ''),
      );
      expect(frag(node), 'xok');
    });
  });

  group('document', () {
    test('serialize wraps root with doctype/html/head/body', () {
      const root = DocumentRootNode(
        head: HeadNode(children: [TitleNode('T')]),
        body: [
          ParagraphNode(children: [TextNode('x')]),
        ],
      );
      expect(
        s.serialize(root),
        '<!DOCTYPE html><html><head><title>T</title></head><body><p>x</p></body></html>',
      );
    });
  });

  group('islands', () {
    test('flutter island emits custom element with DSD and defaults', () {
      expect(
        frag(const IslandPlaceholderNode(id: 'calc')),
        '<hydraline-island id="calc" data-directive="hydrateOnIdle" '
        'data-render-mode="ssr" data-style-mode="shadow" data-state="{}" '
        'role="region" aria-busy="true">'
        '<template shadowrootmode="open">'
        '<style>:host{display:block;contain:layout style paint}</style>'
        '<div class="host"><slot></slot></div>'
        '</template></hydraline-island>',
      );
    });

    test('flutter island with size, state and explicit options', () {
      const island = IslandPlaceholderNode(
        id: 'calc',
        directive: HydrationDirective.onVisible,
        renderMode: IslandRenderMode.skeletonOnly,
        styleMode: IslandStyleMode.scoped,
        size: IslandSize(width: 640, height: 480),
        state: {'price': 100},
        fallback: [
          ParagraphNode(children: [TextNode('loading')]),
        ],
      );
      expect(
        frag(island),
        '<hydraline-island id="calc" data-directive="hydrateOnVisible" '
        'data-render-mode="skeletonOnly" data-style-mode="scoped" '
        'data-size="640,480" '
        'data-state="{&quot;price&quot;:100}" role="region" aria-busy="true">'
        '<template shadowrootmode="open">'
        '<style>:host{display:block;contain:layout style paint}'
        '.host{width:640px;height:480px}</style>'
        '<div class="host"><slot><p>loading</p></slot></div>'
        '</template></hydraline-island>',
      );
    });

    test('flutter island onMedia carries data-media', () {
      const island = IslandPlaceholderNode(
        id: 'm',
        directive: HydrationDirective.onMedia,
        mediaQuery: '(min-width: 800px)',
      );
      expect(frag(island), contains('data-directive="hydrateOnMedia"'));
      expect(frag(island), contains('data-media="(min-width: 800px)"'));
    });

    test('flutter island with manual directive', () {
      const island = IslandPlaceholderNode(
        id: 'manual1',
        directive: HydrationDirective.manual,
      );
      expect(frag(island), contains('data-directive="hydrateManual"'));
    });

    test('htmx island div with defaults', () {
      expect(
        frag(const HtmxIslandNode(id: 'reviews', endpoint: '/api/reviews')),
        '<div class="hydraline-island" data-island="htmx" '
        'data-island-level="htmx" hx-get="/api/reviews" hx-trigger="load" '
        'hx-swap="innerHTML"></div>',
      );
    });

    test('htmx island with target and fallback', () {
      const island = HtmxIslandNode(
        id: 'reviews',
        endpoint: '/api/reviews',
        trigger: 'revealed',
        target: '#list',
        swap: 'beforeend',
        fallback: [
          ParagraphNode(children: [TextNode('loading')]),
        ],
      );
      expect(
        frag(island),
        '<div class="hydraline-island" data-island="htmx" '
        'data-island-level="htmx" hx-get="/api/reviews" hx-trigger="revealed" '
        'hx-target="#list" hx-swap="beforeend"><p>loading</p></div>',
      );
    });

    test('vanilla island div with kind and children', () {
      const island = VanillaIslandNode(
        id: 'tabs1',
        kind: 'tabs',
        children: [TextNode('tab')],
      );
      expect(
        frag(island),
        '<div class="hydraline-island" data-island="tabs" '
        'data-island-level="vanilla">tab</div>',
      );
    });

    test('vanilla island serializes non-empty config as data-config JSON', () {
      const island = VanillaIslandNode(
        id: 'carousel1',
        kind: 'carousel',
        config: {'autoplay': true, 'interval': 3000},
        children: [],
      );
      expect(
        frag(island),
        '<div class="hydraline-island" data-island="carousel" '
        'data-island-level="vanilla" '
        'data-config="{&quot;autoplay&quot;:true,&quot;interval&quot;:3000}">'
        '</div>',
      );
    });

    test('vanilla island omits data-config when config is empty', () {
      const island = VanillaIslandNode(id: 'x', kind: 'tabs', children: []);
      expect(frag(island), isNot(contains('data-config')));
    });

    test('flutter island with non-JSON-safe state throws ArgumentError', () {
      final island = IslandPlaceholderNode(
        id: 'bad',
        state: {'when': DateTime(2026)},
      );
      expect(() => frag(island), throwsArgumentError);
    });
  });
}
