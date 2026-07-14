import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('Table nodes', () {
    test('TableNode rows are its children', () {
      const rows = [
        TableRowNode(
          cells: [
            TableCellNode(children: [TextNode('a')]),
          ],
        ),
      ];
      const table = TableNode(rows: rows);
      expect(table.children, rows);
    });

    test('TableRowNode cells are its children', () {
      const cells = [
        TableCellNode(children: [TextNode('a')]),
        TableCellNode(children: [TextNode('b')]),
      ];
      const row = TableRowNode(cells: cells);
      expect(row.children, cells);
    });

    test('TableCellNode header defaults to false (td vs th)', () {
      const td = TableCellNode(children: [TextNode('x')]);
      const th = TableCellNode(children: [TextNode('H')], header: true);
      expect(td.header, isFalse);
      expect(th.header, isTrue);
      expect(td.children, hasLength(1));
    });
  });

  group('Details/Summary nodes', () {
    test('DetailsNode carries summary, children and open flag', () {
      const details = DetailsNode(
        summary: SummaryNode(children: [TextNode('More')]),
        children: [
          ParagraphNode(children: [TextNode('Body')]),
        ],
        open: true,
      );
      expect(details.summary.children, hasLength(1));
      expect(details.children, hasLength(1));
      expect(details.open, isTrue);
    });

    test('DetailsNode open defaults to false', () {
      const details = DetailsNode(
        summary: SummaryNode(children: [TextNode('More')]),
        children: [],
      );
      expect(details.open, isFalse);
    });
  });
}
