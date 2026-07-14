# Document Model

The `DocumentNode` tree is Hydraline's central data model. It represents a
semantic HTML document as a typed, immutable tree. Everything - the serializer,
SSR engine, SSG extractor, and validators - works from this single model.

## Hierarchy Overview

```
DocumentNode (sealed, immutable)
├── DocumentRootNode            <!DOCTYPE html><html>
│   ├── HeadNode                <head>
│   │   ├── TitleNode           <title>
│   │   ├── MetaNode            <meta>
│   │   ├── LinkNode            <link>
│   │   └── JsonLdNode          <script type="application/ld+json">
│   └── body: [                 <body> children
│       ├── Block nodes
│       ├── Inline nodes
│       ├── Island placeholders
│       └── UnsafeHtmlNode
│   ]
```

`DocumentNode` is a **sealed** class. The serializer walks the tree with an
exhaustive `switch` over every subtype - the Dart compiler verifies completeness.
Adding a new node type causes a compile error until every `switch` handles it.

## Root and Metadata

### DocumentRootNode

The top of every document.

```dart
const DocumentRootNode({
  HeadNode? head,
  required List<DocumentNode> body,
  String? lang,          // <html lang="...">
})
```

If `head` is non-null, it is serialized as `<head>` before `<body>`.
`lang` sets the `lang` attribute on `<html>`.

### HeadNode

A container for metadata children. Rendered as `<head>...</head>`.

```dart
const HeadNode({required List<DocumentNode> children})
```

### TitleNode

The `<title>` element. Text is escaped on serialization.

```dart
const TitleNode(String text)
```

### MetaNode

A `<meta>` tag. Use `name`/`content` for standard meta, `property`/`content`
for Open Graph, or `charset` for character encoding.

```dart
const MetaNode({
  String? name,        // e.g. 'description', 'viewport'
  String? property,    // e.g. 'og:title', 'og:image'
  String? content,
  String? charset,     // e.g. 'utf-8'
})
```

### LinkNode

A `<link>` element. `href` must be a `SafeUrl`.

```dart
const LinkNode({
  required String rel,           // 'canonical', 'alternate', 'stylesheet'
  required SafeUrl href,
  String? hreflang,              // for alternate-language links
})
```

### JsonLdNode

A `<script type="application/ld+json">` block. JSON content is encoded via
`\uXXXX` escapes to prevent `</script>` breakout in the payload.

```dart
const JsonLdNode(Map<String, Object?> json)
```

Typically created via the `JsonLd` builders rather than directly.

## Block Nodes

### HeadingNode

`<h1>` through `<h6>`. `level` must be in `1..6`.

```dart
const HeadingNode({
  required int level,
  required List<DocumentNode> children,
})
```

### ParagraphNode

A `<p>` element.

```dart
const ParagraphNode({required List<DocumentNode> children})
```

### SectionNode

A semantic sectioning element. `role` determines the tag.

```dart
enum SectionRole { section, article, nav, header, footer, main }

const SectionNode({
  required SectionRole role,
  required List<DocumentNode> children,
})
```

| Role | HTML tag |
|---|---|
| `SectionRole.section` | `<section>` |
| `SectionRole.article` | `<article>` |
| `SectionRole.nav` | `<nav>` |
| `SectionRole.header` | `<header>` |
| `SectionRole.footer` | `<footer>` |
| `SectionRole.main` | `<main>` |

### ListNode / ListItemNode

Ordered (`<ol>`) or unordered (`<ul>`) lists.

```dart
const ListNode({
  required bool ordered,
  required List<ListItemNode> items,
})

const ListItemNode({required List<DocumentNode> children})
```

### BlockquoteNode

A `<blockquote>` with optional `cite` URL.

```dart
const BlockquoteNode({
  required List<DocumentNode> children,
  SafeUrl? cite,
})
```

### PreNode / CodeNode

Preformatted text and inline/source code.

```dart
const PreNode({required List<DocumentNode> children})

const CodeNode(
  String text, {
  String? language,   // added as class="language-..."
})
```

### TimeNode

A `<time>` element with an ISO-8601 `dateTime` attribute.

```dart
const TimeNode({
  required String dateTime,     // ISO-8601
  required List<DocumentNode> children,
})
```

### TableNode / TableRowNode / TableCellNode

Basic tables with text content in cells.

```dart
const TableNode({required List<TableRowNode> rows})

const TableRowNode({required List<TableCellNode> cells})

const TableCellNode({
  required List<DocumentNode> children,
  bool header = false,           // true → <th>, false → <td>
})
```

### DetailsNode / SummaryNode

A `<details>` disclosure widget with `<summary>`. Works without JavaScript -
the browser handles open/close natively. Vanilla islands can enhance it further.

```dart
const DetailsNode({
  required SummaryNode summary,
  required List<DocumentNode> children,
  bool open = false,
})

const SummaryNode({required List<DocumentNode> children})
```

## Inline Nodes

### TextNode

Plain text content. Stored raw; escaped on serialization via `escapeHtmlText()`.
Characters `<`, `>`, `&` become `&lt;`, `&gt;`, `&amp;`.

```dart
const TextNode(String text)
```

### AnchorNode

An `<a href>` link. `href` must be a `SafeUrl` - you cannot construct this node
with an unchecked URL.

```dart
const AnchorNode({
  required SafeUrl href,
  required List<DocumentNode> children,
  String? rel,                   // e.g. 'nofollow', 'noopener'
})
```

### ImageNode

An `<img>` element. `src` must be a `SafeUrl`. `alt` is required.

```dart
const ImageNode({
  required SafeUrl src,
  required String alt,
  int? width,
  int? height,
})
```

## Island Placeholders

### IslandPlaceholderNode

A Flutter island (level 2). Renders as a `<hydraline-island>` Custom Element
with Declarative Shadow DOM.

```dart
const IslandPlaceholderNode({
  required String id,
  HydrationDirective directive = HydrationDirective.onIdle,
  IslandRenderMode renderMode = IslandRenderMode.ssr,
  IslandStyleMode styleMode = IslandStyleMode.shadow,
  IslandSize? size,
  Map<String, Object?> state = const {},
  String? mediaQuery,
  List<DocumentNode> fallback = const [],
})
```

| Field | Description |
|---|---|
| `id` | Unique island identifier |
| `directive` | When to hydrate (onIdle, onVisible, onLoad, etc.) |
| `renderMode` | What goes into HTML: `ssr` (semantic fallback) or `skeletonOnly` |
| `styleMode` | `shadow` (Shadow DOM, isolated) or `scoped` (CSS `@scope`, deduplicated) |
| `size` | `IslandSize(width, height)` in px - prevents CLS |
| `state` | Props passed to the island as `data-state` (JSON-safe types only) |
| `mediaQuery` | CSS media query for `hydrateOnMedia` |
| `fallback` | Content shown inside the slot before hydration |

### HtmxIslandNode

An HTMX-powered island (level 1). The server responds with HTML fragments.

```dart
const HtmxIslandNode({
  required String id,
  required String endpoint,     // URL for hx-get/hx-post
  String trigger = 'load',      // HTMX trigger spec
  String? target,               // CSS selector for hx-target
  String swap = 'innerHTML',   // HTMX swap strategy
  List<DocumentNode> fallback = const [],  // shown before the fragment loads
})
```

### VanillaIslandNode

A client-side JS island (level 1). The kind determines which vanilla widget
enhances the content.

```dart
const VanillaIslandNode({
  required String id,
  required String kind,          // 'accordion' | 'tabs' | 'carousel' | 'theme' | 'copy-button' | 'lazy-image'
  Map<String, Object?> config = const {},
  required List<DocumentNode> children,
})
```

Built-in vanilla kinds:

| Kind | Description | No-JS fallback |
|---|---|---|
| `accordion` | Animates `<details>`, adds ARIA | `<details>` works natively |
| `tabs` | Toggles visible panels | `:target` CSS anchors |
| `carousel` | Slides content | Static content strip |
| `theme` | Toggles `data-theme` | `prefers-color-scheme` media query |
| `copy-button` | Copies text to clipboard | Button remains (no copy) |
| `lazy-image` | Lazy-loads images | `<img loading="lazy">` |

## UnsafeHtmlNode

The only escape hatch for raw HTML. The name intentionally contains "Unsafe".
Without a sanitizer, the validator emits a warning.

```dart
const UnsafeHtmlNode(
  String rawHtml, {
  String Function(String raw)? sanitizer,
})
```

## SEO Metadata

The `SeoMeta` class bundles all route metadata into one object. It is used
by both pure-Dart builders and the Flutter `Seo.head()` widget.

```dart
const SeoMeta({
  required String title,
  String? description,
  SafeUrl? canonical,
  RobotsDirectives robots = const RobotsDirectives(),
  OpenGraph? openGraph,
  TwitterCard? twitter,
  String? lang,
  String charset = 'utf-8',
  String viewport = 'width=device-width, initial-scale=1',
  List<HreflangAlternate> hreflang = const [],
  List<({String name, String content})> extraMeta = const [],
  List<({String rel, SafeUrl href})> extraLinks = const [],
})
```

### OpenGraph

```dart
const OpenGraph({
  String? title, String? description, String? type,
  SafeUrl? url, SafeUrl? image, String? imageAlt,
  int? imageWidth, int? imageHeight, SafeUrl? imageSecureUrl,
  String? locale, String? siteName,
})
```

Renders as `<meta property="og:*" content="...">`.

### Twitter Card

```dart
const TwitterCard({
  required TwitterCardType card,       // summary or summaryLargeImage
  String? title, String? description,
  SafeUrl? image, String? site, String? creator,
})
```

### Robots Directives

```dart
const RobotsDirectives({
  bool noindex = false,
  bool nofollow = false,
})
```

When `noindex` is true, a `<meta name="robots" content="noindex">` is emitted
and the server adds an `X-Robots-Tag: noindex` header.

### Hreflang

```dart
const HreflangAlternate({
  required String hreflang,      // 'en', 'ru', 'x-default'
  required SafeUrl href,
})
```

Renders as `<link rel="alternate" hreflang="en" href="...">`.

## JSON-LD Structured Data

Type-safe builders for common schemas. Each returns a `JsonLdSchema` that
serializes to `<script type="application/ld+json">`.

```dart
// Available builders
JsonLd.article(headline:, author:, datePublished:, image:)
JsonLd.product(name:, description:, price:, currency:, image:, sku:)
JsonLd.breadcrumbList([(name:, url:)])
JsonLd.webPage(name:, url:, description:)
JsonLd.organization(name:, url:, logo:)
JsonLd.faq([(question:, answer:)])
JsonLd.event(name:, startDate:, endDate:, location:)
JsonLd.recipe(name:, ingredients:, steps:)
JsonLd.review(itemName:, rating:, bestRating:, author:)
JsonLd.raw(Map<String, Object?> json)      // arbitrary schema
```

Example:

```dart
final schema = JsonLd.product(
  name: 'iPhone 15',
  price: 89990,
  currency: 'RUB',
  image: SafeUrl.parse('https://example.com/iphone15.png'),
);
```

Use `buildHead()` to combine metadata and structured data into a `HeadNode`:

```dart
final head = buildHead(
  SeoMeta(title: 'Product', description: '...'),
  structuredData: [JsonLd.product(name: 'iPhone 15')],
);
```

## Escaping and SafeUrl

### Contextual Escaping

Two distinct functions - never interchangeable:

```dart
String escapeHtmlText(String s);       // & < > → entities (for text content)
String escapeHtmlAttribute(String s);  // " ' & < > → entities (for attribute values)
```

The serializer always applies the correct function based on context. You don't
need to call these manually - they are internal to the serialization layer.

### SafeUrl

URLs in `AnchorNode`, `ImageNode`, and `LinkNode` must be `SafeUrl` - you
cannot construct these nodes with raw strings.

```dart
SafeUrl? tryParse(String raw)   // Returns null if the scheme is blocked
SafeUrl parse(String raw)       // Throws UnsafeUrlException if blocked
```

**Allowlist**: `http`, `https`, `mailto`, `tel`, and relative URLs
(`/`, `./`, `#`, `?`, bare paths).

**Blocked**: `javascript:`, `data:`, `vbscript:`, and everything else.

### CSP Helper

```dart
// Recommended header value: script-src 'self' 'wasm-unsafe-eval'
Csp.recommendedHeaderValue(extraDirectives: [...])

// Meta tag for same policy
Csp.metaTag(extraDirectives: [...])
```

The default policy is compatible with CanvasKit (which requires
`wasm-unsafe-eval`) while blocking `unsafe-inline`.

## Building the Tree Programmatically

Compose nodes directly - the tree is plain immutable Dart objects:

```dart
final doc = DocumentRootNode(
  lang: 'en',
  head: buildHead(
    SeoMeta(title: 'Page Title'),
    structuredData: [JsonLd.webPage(name: 'Page Title')],
  ),
  body: [
    SectionNode(role: SectionRole.main, children: [
      HeadingNode(level: 1, children: [TextNode('Hello')]),
      ParagraphNode(children: [TextNode('Content here.')]),
      AnchorNode(
        href: SafeUrl.parse('https://example.com'),
        children: [TextNode('A link')],
      ),
      ImageNode(
        src: SafeUrl.parse('/img.png'),
        alt: 'An image',
        width: 800, height: 600,
      ),
      ListNode(ordered: false, items: [
        ListItemNode(children: [TextNode('First')]),
        ListItemNode(children: [TextNode('Second')]),
      ]),
    ]),
  ],
);
```

## See Also

- [Getting Started](./getting-started.md) - installation and first pages
- [Server](./server.md) - rendering trees at request time
- [Flutter Widgets](./flutter-widgets.md) - building trees from widgets
- [Security](./security.md) - escaping, SafeUrl, UnsafeHtmlNode
- Runnable example: [packages/hydraline/example/main.dart](../packages/hydraline/example/main.dart)
