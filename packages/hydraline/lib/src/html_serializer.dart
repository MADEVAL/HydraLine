/// Single-pass HTML serializer (ARCHITECTURE.md §6).
///
/// Invariants: SER1 (single pass into a [StringSink], no intermediate tree),
/// SER2 (deterministic, stable attribute order), SER3 (O(nodes + text), no
/// quadratic concatenation), SER4 (`serialize == concat(serializeToStream)`),
/// SER5 (line endings are always `\n`).
library;

import 'dart:convert';

import 'document_node.dart';
import 'escaping.dart';

/// Output options.
class SerializerOptions {
  const SerializerOptions({this.pretty = false});

  /// Pretty vs minified (determinism preserved either way).
  final bool pretty;
}

/// Serializes a [DocumentNode] tree to HTML.
abstract interface class HtmlSerializer {
  /// Default implementation.
  const factory HtmlSerializer([SerializerOptions options]) = _HtmlSerializer;

  /// Buffered HTML (bots / SSG file). SER1/SER2.
  String serialize(DocumentNode root);

  /// Progressive in-order stream (SSR). SER4: equals [serialize] concatenated.
  Stream<String> serializeToStream(DocumentNode root);

  /// A fragment without `<html>/<head>` (HTMX responses).
  String serializeFragment(DocumentNode node);
}

class _HtmlSerializer implements HtmlSerializer {
  const _HtmlSerializer([this.options = const SerializerOptions()]);

  // ignore: unused_field
  final SerializerOptions options;

  @override
  String serialize(DocumentNode root) {
    final buffer = StringBuffer();
    _write(root, buffer);
    return buffer.toString();
  }

  @override
  String serializeFragment(DocumentNode node) {
    final buffer = StringBuffer();
    _write(node, buffer);
    return buffer.toString();
  }

  @override
  Stream<String> serializeToStream(DocumentNode root) async* {
    if (root is DocumentRootNode) {
      final shell = StringBuffer('<!DOCTYPE html><html>');
      final head = root.head;
      if (head != null) {
        _write(head, shell);
      }
      shell.write('<body>');
      yield shell.toString();
      for (final child in root.body) {
        final buffer = StringBuffer();
        _write(child, buffer);
        yield buffer.toString();
      }
      yield '</body></html>';
    } else {
      final buffer = StringBuffer();
      _write(root, buffer);
      yield buffer.toString();
    }
  }

  void _write(DocumentNode node, StringSink out) {
    switch (node) {
      case final DocumentRootNode n:
        out.write('<!DOCTYPE html><html>');
        final head = n.head;
        if (head != null) {
          _write(head, out);
        }
        out.write('<body>');
        _writeAll(n.body, out);
        out.write('</body></html>');
      case final HeadNode n:
        out.write('<head>');
        _writeAll(n.children, out);
        out.write('</head>');
      case final TitleNode n:
        out
          ..write('<title>')
          ..write(escapeHtmlText(n.text))
          ..write('</title>');
      case final MetaNode n:
        _writeMeta(n, out);
      case final LinkNode n:
        _writeLink(n, out);
      case final HeadingNode n:
        out.write('<h${n.level}>');
        _writeAll(n.children, out);
        out.write('</h${n.level}>');
      case final ParagraphNode n:
        out.write('<p>');
        _writeAll(n.children, out);
        out.write('</p>');
      case final SectionNode n:
        final tag = n.role.name;
        out.write('<$tag>');
        _writeAll(n.children, out);
        out.write('</$tag>');
      case final ListNode n:
        final tag = n.ordered ? 'ol' : 'ul';
        out.write('<$tag>');
        _writeAll(n.items, out);
        out.write('</$tag>');
      case final ListItemNode n:
        out.write('<li>');
        _writeAll(n.children, out);
        out.write('</li>');
      case final BlockquoteNode n:
        out.write('<blockquote');
        final cite = n.cite;
        if (cite != null) {
          out
            ..write(' cite="')
            ..write(escapeHtmlAttribute(cite.value))
            ..write('"');
        }
        out.write('>');
        _writeAll(n.children, out);
        out.write('</blockquote>');
      case final PreNode n:
        out.write('<pre>');
        _writeAll(n.children, out);
        out.write('</pre>');
      case final CodeNode n:
        out.write('<code');
        final language = n.language;
        if (language != null) {
          out
            ..write(' class="language-')
            ..write(escapeHtmlAttribute(language))
            ..write('"');
        }
        out
          ..write('>')
          ..write(escapeHtmlText(n.text))
          ..write('</code>');
      case final TimeNode n:
        out
          ..write('<time datetime="')
          ..write(escapeHtmlAttribute(n.dateTime))
          ..write('">');
        _writeAll(n.children, out);
        out.write('</time>');
      case final TableNode n:
        out.write('<table>');
        _writeAll(n.rows, out);
        out.write('</table>');
      case final TableRowNode n:
        out.write('<tr>');
        _writeAll(n.cells, out);
        out.write('</tr>');
      case final TableCellNode n:
        final tag = n.header ? 'th' : 'td';
        out.write('<$tag>');
        _writeAll(n.children, out);
        out.write('</$tag>');
      case final DetailsNode n:
        out.write('<details');
        if (n.open) {
          out.write(' open');
        }
        out.write('>');
        _write(n.summary, out);
        _writeAll(n.children, out);
        out.write('</details>');
      case final SummaryNode n:
        out.write('<summary>');
        _writeAll(n.children, out);
        out.write('</summary>');
      case final TextNode n:
        out.write(escapeHtmlText(n.text));
      case final AnchorNode n:
        out
          ..write('<a href="')
          ..write(escapeHtmlAttribute(n.href.value))
          ..write('"');
        final rel = n.rel;
        if (rel != null) {
          out
            ..write(' rel="')
            ..write(escapeHtmlAttribute(rel))
            ..write('"');
        }
        out.write('>');
        _writeAll(n.children, out);
        out.write('</a>');
      case final ImageNode n:
        out
          ..write('<img src="')
          ..write(escapeHtmlAttribute(n.src.value))
          ..write('" alt="')
          ..write(escapeHtmlAttribute(n.alt))
          ..write('"');
        final width = n.width;
        if (width != null) {
          out
            ..write(' width="')
            ..write(width)
            ..write('"');
        }
        final height = n.height;
        if (height != null) {
          out
            ..write(' height="')
            ..write(height)
            ..write('"');
        }
        out.write('>');
      case final IslandPlaceholderNode n:
        _writeFlutterIsland(n, out);
      case final HtmxIslandNode n:
        _writeHtmxIsland(n, out);
      case final VanillaIslandNode n:
        _writeVanillaIsland(n, out);
      case final UnsafeHtmlNode n:
        out.write(n.sanitize());
    }
  }

  void _writeAll(List<DocumentNode> nodes, StringSink out) {
    for (final node in nodes) {
      _write(node, out);
    }
  }

  void _writeMeta(MetaNode m, StringSink out) {
    out.write('<meta');
    final charset = m.charset;
    if (charset != null) {
      out
        ..write(' charset="')
        ..write(escapeHtmlAttribute(charset))
        ..write('"');
    }
    final name = m.name;
    if (name != null) {
      out
        ..write(' name="')
        ..write(escapeHtmlAttribute(name))
        ..write('"');
    }
    final property = m.property;
    if (property != null) {
      out
        ..write(' property="')
        ..write(escapeHtmlAttribute(property))
        ..write('"');
    }
    final content = m.content;
    if (content != null) {
      out
        ..write(' content="')
        ..write(escapeHtmlAttribute(content))
        ..write('"');
    }
    out.write('>');
  }

  void _writeLink(LinkNode l, StringSink out) {
    out
      ..write('<link rel="')
      ..write(escapeHtmlAttribute(l.rel))
      ..write('" href="')
      ..write(escapeHtmlAttribute(l.href.value))
      ..write('"');
    final hreflang = l.hreflang;
    if (hreflang != null) {
      out
        ..write(' hreflang="')
        ..write(escapeHtmlAttribute(hreflang))
        ..write('"');
    }
    out.write('>');
  }

  void _writeFlutterIsland(IslandPlaceholderNode n, StringSink out) {
    out
      ..write('<hydraline-island id="')
      ..write(escapeHtmlAttribute(n.id))
      ..write('" data-directive="')
      ..write(_directiveAttr(n.directive))
      ..write('" data-render-mode="')
      ..write(n.renderMode.name)
      ..write('" data-style-mode="')
      ..write(n.styleMode.name)
      ..write('"');
    final media = n.mediaQuery;
    if (n.directive == HydrationDirective.onMedia && media != null) {
      out
        ..write(' data-media="')
        ..write(escapeHtmlAttribute(media))
        ..write('"');
    }
    out
      ..write(' data-state="')
      ..write(escapeHtmlAttribute(jsonEncode(n.state)))
      ..write('" role="region" aria-busy="true">')
      ..write('<template shadowrootmode="open"><style>')
      ..write(':host{display:block;contain:layout style paint}');
    final size = n.size;
    if (size != null) {
      out
        ..write('.host{width:')
        ..write(size.width)
        ..write('px;height:')
        ..write(size.height)
        ..write('px}');
    }
    out.write('</style><div class="host"><slot>');
    _writeAll(n.fallback, out);
    out.write('</slot></div></template></hydraline-island>');
  }

  void _writeHtmxIsland(HtmxIslandNode n, StringSink out) {
    out
      ..write('<div class="hydraline-island" data-island="htmx" ')
      ..write('data-island-level="htmx" hx-get="')
      ..write(escapeHtmlAttribute(n.endpoint))
      ..write('" hx-trigger="')
      ..write(escapeHtmlAttribute(n.trigger))
      ..write('"');
    final target = n.target;
    if (target != null) {
      out
        ..write(' hx-target="')
        ..write(escapeHtmlAttribute(target))
        ..write('"');
    }
    out
      ..write(' hx-swap="')
      ..write(escapeHtmlAttribute(n.swap))
      ..write('">');
    _writeAll(n.fallback, out);
    out.write('</div>');
  }

  void _writeVanillaIsland(VanillaIslandNode n, StringSink out) {
    out
      ..write('<div class="hydraline-island" data-island="')
      ..write(escapeHtmlAttribute(n.kind))
      ..write('" data-island-level="vanilla">');
    _writeAll(n.children, out);
    out.write('</div>');
  }

  String _directiveAttr(HydrationDirective directive) => switch (directive) {
        HydrationDirective.onLoad => 'hydrateOnLoad',
        HydrationDirective.onIdle => 'hydrateOnIdle',
        HydrationDirective.onVisible => 'hydrateOnVisible',
        HydrationDirective.onInteraction => 'hydrateOnInteraction',
        HydrationDirective.onMedia => 'hydrateOnMedia',
        HydrationDirective.manual => 'hydrateManual',
      };
}
