// Hydraline — API-контракт (L4) · packages/hydraline/api/serializer.dart
//
// Контракт HTML-сериализатора. Реализация — PHASE_1 (P1-08…P1-10).
// ARCHITECTURE.md §6. Инварианты: SER1 (single-pass), SER2 (детерминизм),
// SER3 (без квадратичности), SER4 (идентичность buffered↔stream), SER5 (\n).
//
// ignore_for_file: unused_element

import 'document_node.dart' show DocumentNode;

/// Опции вывода.
class SerializerOptions {
  const SerializerOptions({this.pretty = false});
  final bool pretty; // pretty vs minified (SER2 сохраняется в обоих)
}

abstract interface class HtmlSerializer {
  /// Фабрика реализации по умолчанию.
  factory HtmlSerializer([SerializerOptions options]) => throw UnimplementedError();

  /// Буферизованный HTML (боты / SSG-файл). SER1/SER2.
  String serialize(DocumentNode root);

  /// Потоковый in-order (SSR streaming, прогрессивный flush).
  /// Инвариант SER4: `serialize(root) == concat(serializeToStream(root))`.
  Stream<String> serializeToStream(DocumentNode root);

  /// Фрагмент без `<html>/<head>` (HTMX-ответы).
  String serializeFragment(DocumentNode node);
}
