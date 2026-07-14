// Hydraline — API-контракт (L4) · packages/hydraline/api/document_node.dart
//
// Замороженная форма публичного API модели документа. Тела опущены/заглушены;
// реализация — по PHASE_1_PLAN (P1-01…P1-07). Соответствует ARCHITECTURE.md §4.
//
// Инварианты: N1 (иммутабельность), N3 (только SafeUrl в url-полях),
// N4 (детерминизм), N5 (дерево без циклов, проверяется в SsgCollector.seal()).
//
// ignore_for_file: unused_element

import 'escaping.dart' show SafeUrl;

/// Корень иерархии узлов. `sealed` → сериализатор использует исчерпывающий
/// `switch` (Dart 3) без внешнего visitor'а.
sealed class DocumentNode {
  const DocumentNode();

  /// Дочерние узлы (пустой список для листьев). N5: без циклов.
  List<DocumentNode> get children;
}

// ── Корень и метаданные ──────────────────────────────────────────────────────

final class DocumentRootNode extends DocumentNode {
  const DocumentRootNode({this.head, required this.body});
  final HeadNode? head;
  final List<DocumentNode> body;
  @override
  List<DocumentNode> get children => [if (head != null) head!, ...body];
}

final class HeadNode extends DocumentNode {
  const HeadNode({required this.children});
  @override
  final List<DocumentNode> children; // TitleNode | MetaNode | LinkNode
}

final class TitleNode extends DocumentNode {
  const TitleNode(this.text);
  final String text; // экранируется на сериализации (N2/S2)
  @override
  List<DocumentNode> get children => const [];
}

final class MetaNode extends DocumentNode {
  const MetaNode({this.name, this.property, this.content, this.charset});
  final String? name;
  final String? property; // напр. og:title
  final String? content;
  final String? charset;
  @override
  List<DocumentNode> get children => const [];
}

final class LinkNode extends DocumentNode {
  const LinkNode({required this.rel, required this.href, this.hreflang});
  final String rel;
  final SafeUrl href; // N3
  final String? hreflang;
  @override
  List<DocumentNode> get children => const [];
}

// ── Блочные ──────────────────────────────────────────────────────────────────

final class HeadingNode extends DocumentNode {
  const HeadingNode({required this.level, required this.children})
      : assert(level >= 1 && level <= 6);
  final int level; // 1..6
  @override
  final List<DocumentNode> children;
}

final class ParagraphNode extends DocumentNode {
  const ParagraphNode({required this.children});
  @override
  final List<DocumentNode> children;
}

/// Секционные обёртки: section/article/nav/header/footer/main.
enum SectionRole { section, article, nav, header, footer, main }

final class SectionNode extends DocumentNode {
  const SectionNode({required this.role, required this.children});
  final SectionRole role;
  @override
  final List<DocumentNode> children;
}

final class ListNode extends DocumentNode {
  const ListNode({required this.ordered, required this.items});
  final bool ordered; // ol vs ul
  final List<ListItemNode> items;
  @override
  List<DocumentNode> get children => items;
}

final class ListItemNode extends DocumentNode {
  const ListItemNode({required this.children});
  @override
  final List<DocumentNode> children;
}

final class BlockquoteNode extends DocumentNode {
  const BlockquoteNode({required this.children, this.cite});
  final SafeUrl? cite; // N3
  @override
  final List<DocumentNode> children;
}

final class PreNode extends DocumentNode {
  const PreNode({required this.children});
  @override
  final List<DocumentNode> children;
}

final class CodeNode extends DocumentNode {
  const CodeNode(this.text, {this.language});
  final String text;
  final String? language;
  @override
  List<DocumentNode> get children => const [];
}

final class TimeNode extends DocumentNode {
  const TimeNode({required this.dateTime, required this.children});
  final String dateTime; // ISO-8601 (детерминизм, DS3)
  @override
  final List<DocumentNode> children;
}

// ── Таблицы (MVP: текст в ячейках) ─────────────────────────────────────────────

final class TableNode extends DocumentNode {
  const TableNode({required this.rows});
  final List<TableRowNode> rows;
  @override
  List<DocumentNode> get children => rows;
}

final class TableRowNode extends DocumentNode {
  const TableRowNode({required this.cells});
  final List<TableCellNode> cells;
  @override
  List<DocumentNode> get children => cells;
}

final class TableCellNode extends DocumentNode {
  const TableCellNode({required this.children, this.header = false});
  final bool header; // th vs td
  @override
  final List<DocumentNode> children;
}

// ── details/summary (no-JS аккордеон уровня 0) ─────────────────────────────────

final class DetailsNode extends DocumentNode {
  const DetailsNode({required this.summary, required this.children, this.open = false});
  final SummaryNode summary;
  final bool open;
  @override
  final List<DocumentNode> children;
}

final class SummaryNode extends DocumentNode {
  const SummaryNode({required this.children});
  @override
  final List<DocumentNode> children;
}

// ── Инлайн ─────────────────────────────────────────────────────────────────────

/// Всегда экранируется на сериализации (S2). Сырой текст хранится как есть (N2).
final class TextNode extends DocumentNode {
  const TextNode(this.text);
  final String text;
  @override
  List<DocumentNode> get children => const [];
}

final class AnchorNode extends DocumentNode {
  const AnchorNode({required this.href, required this.children, this.rel});
  final SafeUrl href; // N3
  final String? rel;
  @override
  final List<DocumentNode> children;
}

final class ImageNode extends DocumentNode {
  const ImageNode({required this.src, required this.alt, this.width, this.height});
  final SafeUrl src; // N3
  final String alt; // валидатор требует непустой (SEO-11)
  final int? width;
  final int? height;
  @override
  List<DocumentNode> get children => const [];
}

// ── Острова ──────────────────────────────────────────────────────────────────

enum IslandType { flutter, vanilla, htmx }

enum HydrationDirective { onLoad, onIdle, onVisible, onInteraction, onMedia, manual }

enum IslandRenderMode { ssr, skeletonOnly }

enum IslandStyleMode { shadow, scoped }

/// Размеры-заглушки (px) для anti-CLS (I8).
final class IslandSize {
  const IslandSize({required this.width, required this.height});
  final int width;
  final int height;
}

/// Flutter-остров (уровень 2).
final class IslandPlaceholderNode extends DocumentNode {
  const IslandPlaceholderNode({
    required this.id,
    this.directive = HydrationDirective.onIdle, // дефолт
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.size,
    this.state = const {}, // JSON-safe (DS2)
    this.mediaQuery, // для onMedia
    this.fallback = const [],
  });
  final String id;
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final IslandSize? size;
  final Map<String, Object?> state;
  final String? mediaQuery;
  final List<DocumentNode> fallback; // SSR-контент/скелетон
  @override
  List<DocumentNode> get children => fallback;
}

/// HTMX-остров (уровень 1).
final class HtmxIslandNode extends DocumentNode {
  const HtmxIslandNode({
    required this.id,
    required this.endpoint,
    this.trigger = 'load',
    this.target,
    this.swap = 'innerHTML',
    this.fallback = const [],
  });
  final String id;
  final String endpoint; // hx-get/hx-post
  final String trigger; // hx-trigger
  final String? target; // hx-target
  final String swap; // hx-swap
  final List<DocumentNode> fallback;
  @override
  List<DocumentNode> get children => fallback;
}

/// Vanilla-остров (уровень 1): accordion|tabs|carousel|theme|copy-button|lazy-image.
final class VanillaIslandNode extends DocumentNode {
  const VanillaIslandNode({
    required this.id,
    required this.kind,
    this.config = const {},
    required this.children,
  });
  final String id;
  final String kind;
  final Map<String, Object?> config;
  @override
  final List<DocumentNode> children;
}

// ── Небезопасный HTML (opt-in, единственный обход) ─────────────────────────────

/// S3: имя содержит «Unsafe». Валидатор предупреждает при `sanitizer == null`.
final class UnsafeHtmlNode extends DocumentNode {
  const UnsafeHtmlNode(this.rawHtml, {this.sanitizer});
  final String rawHtml;
  final String Function(String raw)? sanitizer;
  @override
  List<DocumentNode> get children => const [];
}
