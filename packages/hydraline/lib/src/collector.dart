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

  /// Opens a nested sectioning scope: registers a [SectionNode] with [role]
  /// into this collector and returns a child collector whose additions become
  /// the section's children, in build order. The child scope has its own
  /// dedup namespace; [addMeta] on it is forwarded to the document root.
  SsgCollector beginSection(SectionRole role, {String? key});

  /// Opens a nested list scope: registers a [ListNode] and returns a
  /// [SsgListScope] whose [SsgListScope.beginItem] wraps each item in a `<li>`.
  SsgListScope beginList({required bool ordered, String? key});

  /// Finalises: dedup by key, no cycles, immutable result.
  DocumentNode seal();
}

/// A nested list scope returned by [SsgCollector.beginList]. Each
/// [beginItem] appends a `<li>` to the list and returns a collector that
/// gathers that item's content.
abstract interface class SsgListScope {
  /// Opens a new `<li>` and returns a collector for its content.
  SsgCollector beginItem({String? key});
}

class _SsgCollector implements SsgCollector {
  _SsgCollector(this.route, {_SsgCollector? metaRoot}) : _metaRoot = metaRoot;

  final String route;
  final _SsgCollector? _metaRoot;
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
    if (_metaRoot != null) {
      _metaRoot.addMeta(meta);
      return;
    }
    if (_sealed != null) {
      return;
    }
    _meta = meta;
  }

  @override
  SsgCollector beginSection(SectionRole role, {String? key}) {
    final child = _SsgCollector(route, metaRoot: _metaRoot ?? this);
    _add(SectionNode(role: role, children: child._body), key);
    return child;
  }

  @override
  SsgListScope beginList({required bool ordered, String? key}) {
    final items = <ListItemNode>[];
    _add(ListNode(ordered: ordered, items: items), key);
    return _SsgListScope(route, items, _metaRoot ?? this);
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

class _SsgListScope implements SsgListScope {
  _SsgListScope(this._route, this._items, this._metaRoot);

  final String _route;
  final List<ListItemNode> _items;
  final _SsgCollector _metaRoot;

  @override
  SsgCollector beginItem({String? key}) {
    final child = _SsgCollector(_route, metaRoot: _metaRoot);
    _items.add(ListItemNode(children: child._body));
    return child;
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
    mediaQuery: spec.mediaQuery,
  ),
  IslandType.htmx => HtmxIslandNode(
    id: spec.id,
    endpoint:
        spec.endpoint ??
        (throw ArgumentError.value(
          spec.endpoint,
          'spec.endpoint',
          'an htmx island requires an endpoint',
        )),
  ),
  IslandType.vanilla => VanillaIslandNode(
    id: spec.id,
    kind:
        spec.kind ??
        (throw ArgumentError.value(
          spec.kind,
          'spec.kind',
          'a vanilla island requires a kind',
        )),
    children: const [],
  ),
};
