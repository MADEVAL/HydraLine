// Hydraline — API contract (L4) · packages/hydraline/api/serializer.dart
//
// HTML serializer contract. Single-pass, deterministic, buffered/stream identity.
//
// ignore_for_file: unused_element

import 'document_node.dart' show DocumentNode;

/// Output options.
class SerializerOptions {
  const SerializerOptions({this.pretty = false});
  final bool pretty; // pretty vs minified (determinism preserved in both)
}

abstract interface class HtmlSerializer {
  /// Default implementation factory.
  factory HtmlSerializer([SerializerOptions options]) => throw UnimplementedError();

  /// Buffered HTML (bots / SSG file). Single-pass, deterministic.
  String serialize(DocumentNode root);

  /// Streamed in-order (SSR streaming, progressive flush).
  /// Identity invariant: `serialize(root) == concat(serializeToStream(root))`.
  Stream<String> serializeToStream(DocumentNode root);

  /// Fragment without `<html>/<head>` (HTMX responses).
  String serializeFragment(DocumentNode node);
}
