/// Response delivery: buffered (bot, Content-Length) and chunked streaming
/// (user, Transfer-Encoding) from a pure-Dart [DocumentNode] tree.
/// (ARCHITECTURE.md §10; S-4, S-5, SRV2/SRV3, I3).
library;

import 'dart:convert';

import 'package:hydraline/hydraline.dart' show DocumentNode, HtmlSerializer;
import 'package:shelf/shelf.dart';

/// Two-layer transport: content (UA-blind, always identical) vs transport
/// (may check UA; I3 demands byte-identical output either way).
abstract interface class ResponseDelivery {
  const factory ResponseDelivery() = _ResponseDelivery;

  /// Buffered: the full HTML in one response (Content-Length). Used for bots.
  Response buffered(
    DocumentNode root, {
    int status = 200,
    Map<String, String> headers = const {},
  });

  /// Chunked: progressive in-order streaming (Transfer-Encoding: chunked).
  /// I3: `bytes(buffered(root)) == bytes(concat(stream chunks))`.
  Response chunked(
    DocumentNode root, {
    int status = 200,
    Map<String, String> headers = const {},
  });
}

class _ResponseDelivery implements ResponseDelivery {
  const _ResponseDelivery();

  final HtmlSerializer _serializer = const HtmlSerializer();

  @override
  Response buffered(
    DocumentNode root, {
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    final html = _serializer.serialize(root);
    return Response(
      status,
      body: html,
      headers: {'Content-Type': 'text/html; charset=utf-8', ...headers},
    );
  }

  @override
  Response chunked(
    DocumentNode root, {
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    final stream = _serializer.serializeToStream(root);
    return Response(
      status,
      body: stream.transform(utf8.encoder),
      headers: {'Content-Type': 'text/html; charset=utf-8', ...headers},
    );
  }
}
