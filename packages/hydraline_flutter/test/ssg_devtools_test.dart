@Tags(['ssg'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  group('SsgDevTools', () {
    test('empty collector -> zero islands', () {
      final c = SsgCollector('/');
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 0);
      expect(report.totalPropsBytes, 0);
      expect(report.islands, isEmpty);
    });

    test('single island with normal props', () {
      final c = SsgCollector('/');
      c.addIsland(const IslandSpec(
        id: 'hero',
        type: IslandType.flutter,
        size: IslandSize(width: 400, height: 300),
        state: {'title': 'Hello'},
      ));
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 1);
      final island = report.islands.single;
      expect(island.id, 'hero');
      expect(island.type, 'flutter');
      expect(island.hydration, 'onIdle');
      expect(island.widthPx, 400);
      expect(island.heightPx, 300);
      expect(island.propsBytes, greaterThan(0));
      expect(island.warnings, isEmpty);
    });

    test('island with props > 10KB warns', () {
      final bigStr = 'x' * IslandStateCodec.maxBytes;
      final c = SsgCollector('/');
      c.addIsland(IslandSpec(
        id: 'big',
        type: IslandType.flutter,
        state: {'data': bigStr},
      ));
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 1);
      expect(report.islands.single.warnings, contains('Props size exceeds 10 KB'));
    });

    test('island missing width/height warns about CLS', () {
      final c = SsgCollector('/');
      c.addIsland(const IslandSpec(
        id: 'no-size',
        type: IslandType.flutter,
      ));
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 1);
      expect(report.islands.single.warnings, contains('Missing width/height (anti-CLS)'));
    });

    test('multiple islands correct totals', () {
      final c = SsgCollector('/');
      c.addIsland(const IslandSpec(id: 'a', type: IslandType.flutter, state: {'n': 1}));
      c.addIsland(const IslandSpec(id: 'b', type: IslandType.flutter, state: {'n': 2}));
      c.addIsland(const IslandSpec(id: 'c', type: IslandType.flutter, state: {'n': 3}));
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 3);
      expect(report.islands, hasLength(3));
      num sum = 0;
      for (final island in report.islands) {
        sum += island.propsBytes;
      }
      expect(report.totalPropsBytes, sum);
    });

    test('fromCollector returns correct report after seal', () {
      final c = SsgCollector('/about');
      c.addIsland(const IslandSpec(
        id: 'sticky-header',
        type: IslandType.flutter,
        size: IslandSize(width: 800, height: 64),
        state: {'sticky': true},
      ));
      c.seal(); // explicitly seal before devtools
      final tools = SsgDevTools.fromCollector(c);
      final report = tools.analyze();
      expect(report.totalCount, 1);
      expect(report.islands.single.id, 'sticky-header');
      expect(report.islands.single.widthPx, 800);
      expect(report.islands.single.heightPx, 64);
    });
  });

  group('SsgDomDiff', () {
    test('identical HTML -> 0% divergence, no diffs', () {
      const html = '<html><body><p>Hello World</p></body></html>';
      final diff = SsgDomDiff.compare(html, html);
      expect(diff.divergencePercent, 0.0);
      expect(diff.diffs, isEmpty);
      expect(diff.hasWarning, isFalse);
    });

    test('one text node differs -> detected as diff, >0% divergence', () {
      final diff = SsgDomDiff.compare(
        '<html><body><p>Hello World</p></body></html>',
        '<html><body><p>Goodbye World</p></body></html>',
      );
      expect(diff.diffs, isNotEmpty);
      expect(diff.divergencePercent, greaterThan(0));
    });

    test('one text node differs out of 100 total -> ~1% divergence', () {
      final spans1 = StringBuffer();
      final spans2 = StringBuffer();
      for (var i = 0; i < 100; i++) {
        if (i == 50) {
          spans1.write('<span>Match</span>');
          spans2.write('<span>Mismatch</span>');
        } else {
          spans1.write('<span>Same$i</span>');
          spans2.write('<span>Same$i</span>');
        }
      }
      final diff = SsgDomDiff.compare(
        '<html><body>$spans1</body></html>',
        '<html><body>$spans2</body></html>',
      );
      expect(diff.divergencePercent, closeTo(1.0, 0.5));
    });

    test('>5% divergence -> warning flag set', () {
      final spans1 = StringBuffer();
      final spans2 = StringBuffer();
      for (var i = 0; i < 10; i++) {
        if (i < 2) {
          spans1.write('<span>Good</span>');
          spans2.write('<span>Bad</span>');
        } else {
          spans1.write('<span>Same$i</span>');
          spans2.write('<span>Same$i</span>');
        }
      }
      final diff = SsgDomDiff.compare(
        '<html><body>$spans1</body></html>',
        '<html><body>$spans2</body></html>',
      );
      expect(diff.hasWarning, isTrue);
    });

    test('deeply nested text nodes compared correctly', () {
      const h1 = '<html><body><div><section><article><p>Deep text</p>'
          '</article></section></div></body></html>';
      const h2 = '<html><body><div><section><article><p>Shallow text</p>'
          '</article></section></div></body></html>';
      final diff = SsgDomDiff.compare(h1, h2);
      expect(diff.diffs, isNotEmpty);
      expect(diff.divergencePercent, greaterThan(0));
      expect(diff.diffs.single.index, 0);
    });

    test('HTML structure mismatch handled gracefully', () {
      final diff = SsgDomDiff.compare(
        '<html><body><p>One</p><p>Two</p></body></html>',
        '<html><body><p>One</p></body></html>',
      );
      expect(diff.divergencePercent, isNotNull);
    });
  });
}
