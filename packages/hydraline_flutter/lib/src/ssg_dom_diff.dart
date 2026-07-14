import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

class SsgDomDiff {
  factory SsgDomDiff.compare(String ssgHtml, String domHtml) {
    final ssgDoc = html.parse(ssgHtml);
    final domDoc = html.parse(domHtml);
    final ssgTexts = _extractTexts(ssgDoc.body);
    final domTexts = _extractTexts(domDoc.body);

    final diffs = <SsgTextDiff>[];
    final maxLen = ssgTexts.length > domTexts.length
        ? ssgTexts.length
        : domTexts.length;
    for (var i = 0; i < maxLen; i++) {
      final expected = i < ssgTexts.length ? ssgTexts[i] : '';
      final actual = i < domTexts.length ? domTexts[i] : '';
      if (expected != actual) {
        diffs.add(SsgTextDiff(expected: expected, actual: actual, index: i));
      }
    }

    final total = maxLen > 0 ? maxLen : 1;
    final percent = (diffs.length / total) * 100;
    return SsgDomDiff._(
      divergencePercent: percent,
      diffs: List.unmodifiable(diffs),
    );
  }

  SsgDomDiff._({required this.divergencePercent, required this.diffs});

  final double divergencePercent;
  final List<SsgTextDiff> diffs;

  bool get hasWarning => divergencePercent > 5.0;

  static List<String> _extractTexts(Element? element) {
    final texts = <String>[];
    if (element == null) return texts;
    _walkNodes(element.nodes, texts);
    return texts;
  }

  static void _walkNodes(List<Node> nodes, List<String> out) {
    for (final node in nodes) {
      if (node is Text) {
        final t = node.text.trim();
        if (t.isNotEmpty) out.add(t);
      } else if (node is Element) {
        _walkNodes(node.nodes, out);
      }
    }
  }
}

class SsgTextDiff {
  const SsgTextDiff({
    required this.expected,
    required this.actual,
    required this.index,
  });

  final String expected;
  final String actual;
  final int index;
}
