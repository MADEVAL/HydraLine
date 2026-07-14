import 'package:hydraline/hydraline.dart';

class SsgDevTools {
  factory SsgDevTools.fromCollector(SsgCollector collector) {
    final sealed = collector.seal();
    return SsgDevTools._(sealed);
  }

  SsgDevTools._(this._root);

  final DocumentNode _root;

  SsgDevToolsReport analyze() {
    final islands = <SsgIslandInfo>[];
    _walk(_root.children, islands);
    return SsgDevToolsReport(islands: List.unmodifiable(islands));
  }

  void _walk(List<DocumentNode> nodes, List<SsgIslandInfo> out) {
    for (final node in nodes) {
      if (node is IslandPlaceholderNode) {
        final warnings = <String>[];
        final propsSize = IslandStateCodec.byteSize(node.state);
        if (propsSize > IslandStateCodec.maxBytes) {
          warnings.add('Props size exceeds 10 KB');
        }
        if (node.size == null) {
          warnings.add('Missing width/height (anti-CLS)');
        }
        out.add(SsgIslandInfo(
          id: node.id,
          type: node.runtimeType == IslandPlaceholderNode ? 'flutter' : 'unknown',
          hydration: node.directive.name,
          widthPx: node.size?.width,
          heightPx: node.size?.height,
          propsBytes: propsSize,
          warnings: List.unmodifiable(warnings),
        ));
      } else if (node is HtmxIslandNode) {
        out.add(SsgIslandInfo(
          id: node.id,
          type: 'htmx',
          hydration: node.trigger,
          propsBytes: 0,
          warnings: const [],
        ));
      } else if (node is VanillaIslandNode) {
        out.add(SsgIslandInfo(
          id: node.id,
          type: 'vanilla',
          hydration: node.kind,
          propsBytes: 0,
          warnings: const [],
        ));
      }
      _walk(node.children, out);
    }
  }
}

class SsgDevToolsReport {
  const SsgDevToolsReport({required this.islands});

  final List<SsgIslandInfo> islands;

  int get totalCount => islands.length;

  int get totalPropsBytes => islands.fold<int>(0, (sum, i) => sum + i.propsBytes);
}

class SsgIslandInfo {
  const SsgIslandInfo({
    required this.id,
    required this.type,
    required this.hydration,
    this.widthPx,
    this.heightPx,
    required this.propsBytes,
    required this.warnings,
  });

  final String id;
  final String type;
  final String hydration;
  final int? widthPx;
  final int? heightPx;
  final int propsBytes;
  final List<String> warnings;
}
