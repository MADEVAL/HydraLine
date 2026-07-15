/// Island runtime helpers: the `<script>` nodes that hydrate L2 Flutter
/// islands. Append these to a `DocumentRootNode` body before serializing.
library;

import '../document_node.dart' show DocumentNode, UnsafeHtmlNode;

/// Returns the runtime script nodes needed for island hydration: the
/// engine bootstrap location via `HYDRALINE_CONFIG`, the custom element,
/// and the dispatcher. [engineScript] points to the Flutter engine
/// bootstrap (defaults to `/flutter_bootstrap.js`).
///
/// The returned nodes are [UnsafeHtmlNode] instances carrying trusted,
/// static `<script>` markup - no user-input interpolation.
List<DocumentNode> islandRuntime({
  String engineScript = '/flutter_bootstrap.js',
}) {
  return [
    UnsafeHtmlNode(
      '<script>'
      "window.HYDRALINE_CONFIG={engineScript:'$engineScript'}"
      '</script>'
      '<script src="/hydraline-island.js" defer></script>'
      '<script src="/hydraline-dispatcher.js" defer></script>',
    ),
  ];
}
