/// `SsgCollector`: pure-Dart collector for self-registering widgets (surface A)
/// that seals into a [DocumentNode] tree.
library;

import 'document_node.dart';
import 'escaping.dart' show SafeUrl;
import 'island_manifest.dart' show IslandSpec;
import 'metadata.dart';

/// Instance-scoped collector. Immutable after [seal].
abstract interface class SsgCollector {
  factory SsgCollector(String route) = _SsgCollector;

  void addText(String text, {int? headingLevel, String? key});
  void addImage(
    SafeUrl src,
    String alt, {
    int? width,
    int? height,
    String? key,
  });
  void addLink(SafeUrl href, String text, {String? key});
  void addIsland(IslandSpec spec, {String? key});
  void addNode(DocumentNode node, {String? key});
  void addMeta(SeoMeta meta);

  /// Finalises: dedup by key, no cycles, immutable result.
  DocumentNode seal();
}

class _SsgCollector implements SsgCollector {
  _SsgCollector(this.route);

  final String route;
  final List<DocumentNode> _body = [];
  final Set<String> _keys = {};
  SeoMeta? _meta;
  DocumentRootNode? _sealed;

  void _add(DocumentNode node, String? key) {
    if (_sealed != null) {
      return;
    }
    if (key != null) {
      if (_keys.contains(key)) {
        return; // dedup
      }
      _keys.add(key);
    }
    _body.add(node);
  }

  @override
  void addText(String text, {int? headingLevel, String? key}) {
    final node = headingLevel != null
        ? HeadingNode(level: headingLevel, children: [TextNode(text)])
        : ParagraphNode(children: [TextNode(text)]);
    _add(node, key);
  }

  @override
  void addImage(
    SafeUrl src,
    String alt, {
    int? width,
    int? height,
    String? key,
  }) => _add(ImageNode(src: src, alt: alt, width: width, height: height), key);

  @override
  void addLink(SafeUrl href, String text, {String? key}) =>
      _add(AnchorNode(href: href, children: [TextNode(text)]), key);

  @override
  void addIsland(IslandSpec spec, {String? key}) =>
      _add(_islandNode(spec), key);

  @override
  void addNode(DocumentNode node, {String? key}) => _add(node, key);

  @override
  void addMeta(SeoMeta meta) {
    if (_sealed != null) {
      return;
    }
    _meta = meta;
  }

  @override
  DocumentNode seal() {
    return _sealed ??= DocumentRootNode(
      head: _meta == null ? null : buildHead(_meta!),
      body: List.unmodifiable(_body),
      lang: _meta?.lang,
    );
  }
}

DocumentNode _islandNode(IslandSpec spec) => switch (spec.type) {
  IslandType.flutter => IslandPlaceholderNode(
    id: spec.id,
    directive: spec.directive,
    renderMode: spec.renderMode,
    styleMode: spec.styleMode,
    size: spec.size,
    state: spec.state,
  ),
  IslandType.htmx => HtmxIslandNode(id: spec.id, endpoint: spec.endpoint ?? ''),
  IslandType.vanilla => VanillaIslandNode(
    id: spec.id,
    kind: spec.kind ?? '',
    children: const [],
  ),
};
