/// Shared test helpers for hydraline_server.
library;

import 'dart:convert';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:shelf/shelf.dart';

Handler createTestHandler(RouteManifest manifest) {
  final middleware = hydralineMiddleware(
    HydralineConfig(manifest: manifest, builders: const {}),
  );
  // shelf.Middleware = Handler Function(Handler inner)
  // Apply it to a pass-through inner handler.
  final Handler handler = middleware((Request req) async {
    return Response.ok('app-shell');
  });
  // Wrap to catch RedirectException thrown by http_semantics during test.
  return (Request request) async {
    try {
      return await handler(request);
    } on RedirectException catch (e) {
      return Response.movedPermanently(e.location);
    }
  };
}

Future<Response> httpGet(Handler handler, String path) async {
  final request = Request('GET', Uri.parse('http://localhost$path'));
  final response = await handler(request);
  return response;
}

Future<String> bodyOf(Response response) async {
  final bytes = await response.read().expand((chunk) => chunk).toList();
  return utf8.decode(bytes, allowMalformed: true);
}
