/// Island runtime helpers: the `<script>` nodes that hydrate L2 Flutter
/// islands. Append these to a `DocumentRootNode` body before serializing.
library;

import '../document_node.dart' show DocumentNode, UnsafeHtmlNode;

/// Returns the runtime script nodes needed for island hydration: the
/// engine bootstrap location via `HYDRALINE_CONFIG`, the custom element,
/// and the dispatcher. [engineScript] points to the Flutter engine
/// bootstrap (defaults to `/flutter_bootstrap.js`).
///
/// [islandElementIntegrity] and [dispatcherIntegrity] are optional
/// Subresource Integrity (SRI) hashes (`sha384-...`) for the shipped
/// `hydraline-island.js` and `hydraline-dispatcher.js` assets. When
/// supplied, the `<script>` tags carry `integrity` and
/// `crossorigin="anonymous"` attributes, guaranteeing the browser
/// rejects a tampered runtime even when the CDN or static host is
/// compromised.
///
/// The returned nodes are [UnsafeHtmlNode] instances carrying trusted,
/// static `<script>` markup - no user-input interpolation.
List<DocumentNode> islandRuntime({
  String engineScript = '/flutter_bootstrap.js',
  String? islandElementIntegrity,
  String? dispatcherIntegrity,
}) {
  final islandAttrs = islandElementIntegrity != null
      ? ' integrity="$islandElementIntegrity" crossorigin="anonymous"'
      : '';
  final dispatcherAttrs = dispatcherIntegrity != null
      ? ' integrity="$dispatcherIntegrity" crossorigin="anonymous"'
      : '';

  return [
    UnsafeHtmlNode(
      '<script>'
      "window.HYDRALINE_CONFIG={engineScript:'$engineScript'}"
      '</script>'
      '<script src="/hydraline-island.js" defer$islandAttrs></script>'
      '<script src="/hydraline-dispatcher.js" defer$dispatcherAttrs></script>',
    ),
  ];
}
