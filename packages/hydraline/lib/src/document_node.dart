/// The `DocumentNode` tree.
///
/// The hierarchy is `sealed`, so the serializer walks it with an exhaustive
/// `switch` (no external visitor). Invariants: immutable, text stored raw (escaped only on serialization),
/// URL fields are always [SafeUrl], deterministic, tree without cycles.
///
/// Nodes have `const` constructors and store the child lists they are given
/// without copying; callers must not mutate a list after passing it in
/// (prefer `const` literals or freshly built lists).
library;

import 'escaping.dart' show SafeUrl;

/// Root of the node hierarchy.
sealed class DocumentNode {
  const DocumentNode();

  /// Child nodes (empty for leaves). No cycles.
  List<DocumentNode> get children;
}

// ── Root and metadata ────────────────────────────────────────────────────────

/// The document root: an optional `<head>` plus a body.
final class DocumentRootNode extends DocumentNode {
  const DocumentRootNode({this.head, required this.body, this.lang});

  final HeadNode? head;
  final List<DocumentNode> body;

  /// Optional `lang` for the `<html>` element.
  final String? lang;

  @override
  List<DocumentNode> get children => [if (head != null) head!, ...body];
}

/// The `<head>` container (title/meta/link children).
final class HeadNode extends DocumentNode {
  const HeadNode({required this.children});

  @override
  final List<DocumentNode> children;
}

/// The `<title>`.
final class TitleNode extends DocumentNode {
  const TitleNode(this.text);

  /// Raw title text; escaped only on serialization.
  final String text;

  @override
  List<DocumentNode> get children => const [];
}

/// A `<meta>` tag (name/property/content/charset).
final class MetaNode extends DocumentNode {
  const MetaNode({this.name, this.property, this.content, this.charset});

  final String? name;
  final String? property;
  final String? content;
  final String? charset;

  @override
  List<DocumentNode> get children => const [];
}

/// A `<link rel href>` (e.g. canonical, hreflang alternate).
final class LinkNode extends DocumentNode {
  const LinkNode({required this.rel, required this.href, this.hreflang});

  final String rel;
  final SafeUrl href;
  final String? hreflang;

  @override
  List<DocumentNode> get children => const [];
}

// ── Block ────────────────────────────────────────────────────────────────────

/// A heading `<h1>`..`<h6>`.
final class HeadingNode extends DocumentNode {
  const HeadingNode({required this.level, required this.children})
    : assert(level >= 1 && level <= 6, 'heading level must be in 1..6');

  final int level;

  @override
  final List<DocumentNode> children;
}

/// A paragraph `<p>`.
final class ParagraphNode extends DocumentNode {
  const ParagraphNode({required this.children});

  @override
  final List<DocumentNode> children;
}

/// Semantic sectioning role.
enum SectionRole { section, article, nav, header, footer, main }

/// A sectioning wrapper (`<section>`/`<article>`/`<nav>`/`<header>`/`<footer>`/`<main>`).
final class SectionNode extends DocumentNode {
  const SectionNode({required this.role, required this.children});

  final SectionRole role;

  @override
  final List<DocumentNode> children;
}

/// An ordered (`<ol>`) or unordered (`<ul>`) list.
final class ListNode extends DocumentNode {
  const ListNode({required this.ordered, required this.items});

  final bool ordered;
  final List<ListItemNode> items;

  @override
  List<DocumentNode> get children => items;
}

/// A list item `<li>`.
final class ListItemNode extends DocumentNode {
  const ListItemNode({required this.children});

  @override
  final List<DocumentNode> children;
}

/// A `<blockquote>` with an optional `cite`.
final class BlockquoteNode extends DocumentNode {
  const BlockquoteNode({required this.children, this.cite});

  final SafeUrl? cite;

  @override
  final List<DocumentNode> children;
}

/// A `<pre>` block.
final class PreNode extends DocumentNode {
  const PreNode({required this.children});

  @override
  final List<DocumentNode> children;
}

/// A `<code>` span/block with optional language hint.
final class CodeNode extends DocumentNode {
  const CodeNode(this.text, {this.language});

  final String text;
  final String? language;

  @override
  List<DocumentNode> get children => const [];
}

/// A `<time>` element carrying an ISO-8601 `dateTime`.
final class TimeNode extends DocumentNode {
  const TimeNode({required this.dateTime, required this.children});

  final String dateTime;

  @override
  final List<DocumentNode> children;
}

// ── Tables (MVP: text in cells) ──────────────────────────────────────────────

/// A `<table>`.
final class TableNode extends DocumentNode {
  const TableNode({required this.rows});

  final List<TableRowNode> rows;

  @override
  List<DocumentNode> get children => rows;
}

/// A table row `<tr>`.
final class TableRowNode extends DocumentNode {
  const TableRowNode({required this.cells});

  final List<TableCellNode> cells;

  @override
  List<DocumentNode> get children => cells;
}

/// A table cell (`<th>` when [header], otherwise `<td>`).
final class TableCellNode extends DocumentNode {
  const TableCellNode({required this.children, this.header = false});

  final bool header;

  @override
  final List<DocumentNode> children;
}

// ── details/summary (no-JS accordion, level 0) ───────────────────────────────

/// A `<details>` disclosure with its `<summary>`.
final class DetailsNode extends DocumentNode {
  const DetailsNode({
    required this.summary,
    required this.children,
    this.open = false,
  });

  final SummaryNode summary;
  final bool open;

  @override
  final List<DocumentNode> children;
}

/// A `<summary>`.
final class SummaryNode extends DocumentNode {
  const SummaryNode({required this.children});

  @override
  final List<DocumentNode> children;
}

// ── Islands ──────────────────────────────────────────────────────────────────

/// Island kind.
enum IslandType { flutter, vanilla, htmx }

/// When an island hydrates.
enum HydrationDirective {
  onLoad,
  onIdle,
  onVisible,
  onInteraction,
  onMedia,
  manual,
}

/// What an island emits into the HTML.
enum IslandRenderMode { ssr, skeletonOnly }

/// How island styles are scoped.
enum IslandStyleMode { shadow, scoped }

/// Reserved placeholder size in px to prevent layout shift.
final class IslandSize {
  const IslandSize({required this.width, required this.height});

  final int width;
  final int height;
}

/// A Flutter island (level 2).
final class IslandPlaceholderNode extends DocumentNode {
  const IslandPlaceholderNode({
    required this.id,
    this.directive = HydrationDirective.onIdle,
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.size,
    this.state = const {},
    this.mediaQuery,
    this.fallback = const [],
  });

  final String id;
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final IslandSize? size;
  final Map<String, Object?> state;
  final String? mediaQuery;
  final List<DocumentNode> fallback;

  @override
  List<DocumentNode> get children => fallback;
}

/// An HTMX island (level 1).
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
  final String endpoint;
  final String trigger;
  final String? target;
  final String swap;
  final List<DocumentNode> fallback;

  @override
  List<DocumentNode> get children => fallback;
}

/// A vanilla island (level 1): accordion|tabs|carousel|theme|copy-button|lazy-image.
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

// ── Unsafe HTML (opt-in, the only raw-HTML escape hatch) ─────────────────────

/// The only path for raw HTML. The name intentionally contains "Unsafe".
/// Without a [sanitizer] the `SeoValidator` emits a warning.
final class UnsafeHtmlNode extends DocumentNode {
  const UnsafeHtmlNode(this.rawHtml, {this.sanitizer});

  final String rawHtml;
  final String Function(String raw)? sanitizer;

  /// Returns [sanitizer] applied to [rawHtml], or the raw HTML unchanged when
  /// no sanitizer was provided.
  String sanitize() => sanitizer?.call(rawHtml) ?? rawHtml;

  @override
  List<DocumentNode> get children => const [];
}

/// A `<script type="application/ld+json">` structured-data block.
///
/// This is the only `<script>` the serializer emits; its content is JSON data
/// (not executable code) and is escaped to prevent `</script>` breakout.
final class JsonLdNode extends DocumentNode {
  const JsonLdNode(this.json);

  final Map<String, Object?> json;

  @override
  List<DocumentNode> get children => const [];
}

// ── Inline ───────────────────────────────────────────────────────────────────

/// Text content. Stored raw; always escaped on serialization.
final class TextNode extends DocumentNode {
  const TextNode(this.text);

  final String text;

  @override
  List<DocumentNode> get children => const [];
}

/// An anchor `<a href>`; `href` is always a [SafeUrl].
final class AnchorNode extends DocumentNode {
  const AnchorNode({required this.href, required this.children, this.rel});

  final SafeUrl href;
  final String? rel;

  @override
  final List<DocumentNode> children;
}

/// An image `<img src alt>`; `src` is always a [SafeUrl].
final class ImageNode extends DocumentNode {
  const ImageNode({
    required this.src,
    required this.alt,
    this.width,
    this.height,
  });

  final SafeUrl src;
  final String alt;
  final int? width;
  final int? height;

  @override
  List<DocumentNode> get children => const [];
}
