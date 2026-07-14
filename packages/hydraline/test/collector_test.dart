import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

DocumentRootNode sealed(void Function(SsgCollector) build) {
  final collector = SsgCollector('/route');
  build(collector);
  return collector.seal() as DocumentRootNode;
}

void main() {
  group('SsgCollector content', () {
    test('addText emits heading or paragraph', () {
      final root = sealed((c) {
        c
          ..addText('Title', headingLevel: 1)
          ..addText('Body');
      });
      expect(root.body[0], isA<HeadingNode>());
      expect((root.body[0] as HeadingNode).level, 1);
      expect(root.body[1], isA<ParagraphNode>());
    });

    test('addImage and addLink', () {
      final root = sealed((c) {
        c
          ..addImage(SafeUrl.parse('/i.png'), 'alt', width: 10, height: 20)
          ..addLink(SafeUrl.parse('/x'), 'link');
      });
      expect(root.body[0], isA<ImageNode>());
      expect((root.body[0] as ImageNode).alt, 'alt');
      expect(root.body[1], isA<AnchorNode>());
    });

    test('addIsland maps spec type to the right node', () {
      final root = sealed((c) {
        c
          ..addIsland(const IslandSpec(id: 'a', type: IslandType.flutter))
          ..addIsland(
            const IslandSpec(id: 'b', type: IslandType.htmx, endpoint: '/e'),
          )
          ..addIsland(
            const IslandSpec(id: 'c', type: IslandType.vanilla, kind: 'tabs'),
          );
      });
      expect(root.body[0], isA<IslandPlaceholderNode>());
      expect(root.body[1], isA<HtmxIslandNode>());
      expect(root.body[2], isA<VanillaIslandNode>());
    });

    test('addMeta populates the head', () {
      final root = sealed((c) {
        c
          ..addMeta(const SeoMeta(title: 'Home'))
          ..addText('x');
      });
      expect(root.head, isNotNull);
      expect(
        const HtmlSerializer().serializeFragment(root.head!),
        contains('<title>Home</title>'),
      );
    });
  });

  group('SsgCollector invariants', () {
    test('dedup by key keeps the first occurrence', () {
      final root = sealed((c) {
        c
          ..addText('first', key: 'k')
          ..addText('second', key: 'k')
          ..addText('other');
      });
      expect(root.body, hasLength(2));
    });

    test('add* is ignored after seal()', () {
      final collector = SsgCollector('/r')..addText('one');
      final first = collector.seal() as DocumentRootNode;
      collector.addText('two');
      final second = collector.seal() as DocumentRootNode;
      expect(first.body, hasLength(1));
      expect(second.body, hasLength(1));
    });

    test('separate instances are isolated', () {
      final a = SsgCollector('/a')..addText('a');
      final b = SsgCollector('/b')
        ..addText('b1')
        ..addText('b2');
      expect((a.seal() as DocumentRootNode).body, hasLength(1));
      expect((b.seal() as DocumentRootNode).body, hasLength(2));
    });
  });
}
