/// shelf middleware: route matching and server-rendered HTML delivery from a
/// pure-Dart [DocumentNode] tree (ARCHITECTURE.md §10; S-1, S-2).
library;

import 'dart:async';

import 'package:hydraline/hydraline.dart'
    show
        DocumentNode,
        DocumentRootNode,
        HtmlSerializer,
        RouteEntry,
        RouteManifest,
        RouteMode;
import 'package:shelf/shelf.dart';

import 'http_semantics.dart' show RedirectException;

/// The configuration for [hydralineMiddleware].
class HydralineConfig {
  const HydralineConfig({
    required this.manifest,
    this.builders = const {},
    this.cache,
    this.botUserAgentPattern,
  });

  final RouteManifest manifest;

  /// Per-path pure-Dart [DocumentNode] builders (surface B).
  final Map<String, DocumentBuilder> builders;

  final Object? cache; // HydralineCache — wired in P2-06

  /// Pattern matching bot user agents. Read only by the transport layer, never
  /// by the builder (SRV1). When null, chunked delivery is always used.
  final Pattern? botUserAgentPattern;
}

/// A pure-Dart function that builds a [DocumentNode] for a given request and
/// optional application data. The signature deliberately does **not** include
/// `User-Agent` — the builder is architecturally prevented from cloaking
/// (SRV1, R7).
typedef DocumentBuilder =
    FutureOr<DocumentNode> Function(Request request, Object? data);

/// shelf middleware. For every request it:
/// 1. matches the path against the configured [RouteManifest];
/// 2. renders `document`/`hybrid` routes via the registered [DocumentBuilder],
///    or an empty page;
/// 3. passes `app` routes through to the inner handler.
Middleware hydralineMiddleware(HydralineConfig config) {
  final serializer = const HtmlSerializer();
  final routes = config.manifest.routes;
  final builders = config.builders;

  return (Handler inner) {
    return (Request request) async {
      final path = request.url.path.isEmpty ? '/' : '/${request.url.path}';
      final match = _matchRoute(routes, path);

      if (match == null) {
        return Response.notFound('');
      }

      switch (match.mode) {
        case RouteMode.app:
          return inner(request);
        case RouteMode.document:
        case RouteMode.hybrid:
          final builder = builders[path];
          DocumentNode root;
          if (builder != null) {
            try {
              root = await builder(request, null);
            } on RedirectException catch (e) {
              return e.status == 301
                  ? Response.movedPermanently(e.location)
                  : Response.found(e.location);
            }
          } else {
            root = DocumentRootNode(body: []);
          }
          final html = serializer.serialize(root);
          return Response.ok(
            html,
            headers: {'Content-Type': 'text/html; charset=utf-8'},
          );
      }
    };
  };
}

/// Returns the [RouteEntry] whose path matches [requestPath]. Supports exact
/// and prefix matching so `/blog/post-1` matches `/blog/:slug`.
RouteEntry? _matchRoute(List<RouteEntry> routes, String requestPath) {
  RouteEntry? prefixMatch;
  for (final route in routes) {
    if (route.path == requestPath) {
      return route;
    }
    if (_isPrefixMatch(route.path, requestPath)) {
      prefixMatch ??= route;
    }
  }
  return prefixMatch;
}

bool _isPrefixMatch(String pattern, String requestPath) {
  if (!pattern.contains(':')) {
    return false;
  }
  final parts = pattern.split('/');
  final actualParts = requestPath.split('/');
  if (parts.length != actualParts.length) {
    return false;
  }
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].startsWith(':')) {
      continue;
    }
    if (parts[i] != actualParts[i]) {
      return false;
    }
  }
  return true;
}

// Re-export core types for convenience.
