/// shelf middleware: route matching and server-rendered HTML delivery from a
/// pure-Dart [DocumentNode] tree.
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

import 'cache.dart' show HydralineCache;
import 'delivery.dart' show ResponseDelivery;
import 'http_semantics.dart' show Http, RedirectException;

/// The configuration for [hydralineMiddleware].
class HydralineConfig {
  const HydralineConfig({
    required this.manifest,
    this.builders = const {},
    this.cache,
    this.cacheTtl,
    this.botUserAgentPattern,
  });

  final RouteManifest manifest;

  /// Pure-Dart [DocumentNode] builders (surface B), keyed by the route path
  /// exactly as it appears in the manifest - including dynamic patterns such
  /// as `/product/:id`. The matched route's pattern selects the builder; the
  /// concrete request path is available on the [Request] passed to it.
  final Map<String, DocumentBuilder> builders;

  /// Optional server-side HTML cache. When set, rendered pages are stored
  /// per canonical path + query string, responses carry an `ETag`, and
  /// `If-None-Match` revalidation returns `304 Not Modified`.
  final HydralineCache? cache;

  /// TTL for cached entries; also emitted as
  /// `Cache-Control: public, max-age=N` on cacheable responses.
  final Duration? cacheTtl;

  /// Pattern matching bot user agents. Read only by the transport layer, never
  /// by the builder. When null, chunked delivery is always used.
  final Pattern? botUserAgentPattern;
}

/// A pure-Dart function that builds a [DocumentNode] for a given request and
/// optional application data. The signature deliberately does **not** include
/// `User-Agent` - the builder is architecturally prevented from cloaking.
typedef DocumentBuilder =
    FutureOr<DocumentNode> Function(Request request, Object? data);

/// shelf middleware. For every request it:
/// 1. matches the path against the configured [RouteManifest];
/// 2. renders `document`/`hybrid` routes via the registered [DocumentBuilder],
///    or an empty page;
/// 3. passes `app` routes through to the inner handler (adding
///    `X-Robots-Tag: noindex` unless overridden);
/// 4. serves from [HydralineConfig.cache] with `ETag`/`304` support when a
///    cache is configured.
Middleware hydralineMiddleware(HydralineConfig config) {
  final delivery = const ResponseDelivery();
  final botPattern = config.botUserAgentPattern;
  final routes = config.manifest.routes;
  final builders = config.builders;
  final cache = config.cache;
  final cacheTtl = config.cacheTtl;

  return (Handler inner) {
    return (Request request) async {
      final path = Http.canonicalizePath(
        request.url.path.isEmpty ? '/' : '/${request.url.path}',
      );
      final match = _matchRoute(routes, path);

      if (match == null) {
        return Response.notFound('');
      }

      switch (match.mode) {
        case RouteMode.app:
          final response = await inner(request);
          // App routes default to noindex unless explicitly overridden.
          return Http.withRobots(response, noindex: match.noindex ?? true);
        case RouteMode.document:
        case RouteMode.hybrid:
          final robotsHeaders = _robotsHeaders(match);
          final builder = builders[match.path];

          if (cache != null) {
            final query = request.url.query;
            final cacheKey = query.isEmpty ? path : '$path?$query';
            final cached = await cache.get(cacheKey);
            String html;
            if (cached != null) {
              html = cached;
            } else {
              final DocumentNode root;
              try {
                root = await _buildRoot(builder, request);
              } on RedirectException catch (e) {
                return _redirectResponse(e);
              }
              html = const HtmlSerializer().serialize(root);
              await cache.set(cacheKey, html, ttl: cacheTtl);
            }
            return _cachedResponse(
              request,
              html,
              cacheTtl,
              robotsHeaders,
              delivery,
            );
          }

          final DocumentNode root;
          try {
            root = await _buildRoot(builder, request);
          } on RedirectException catch (e) {
            return _redirectResponse(e);
          }

          if (_isBotRequest(request, botPattern)) {
            return delivery.buffered(root, headers: robotsHeaders);
          }
          return delivery.chunked(root, headers: robotsHeaders);
      }
    };
  };
}

Future<DocumentNode> _buildRoot(
  DocumentBuilder? builder,
  Request request,
) async {
  if (builder == null) {
    return const DocumentRootNode(body: []);
  }
  return builder(request, null);
}

Response _redirectResponse(RedirectException e) => switch (e.status) {
  301 => Response.movedPermanently(e.location),
  302 => Response.found(e.location),
  410 => Response(410, body: ''),
  _ => Response(e.status, headers: {'location': e.location}),
};

Map<String, String> _robotsHeaders(RouteEntry route) {
  final robots = route.metadata?.robots;
  final noindex = route.noindex ?? robots?.noindex ?? false;
  final nofollow = robots?.nofollow ?? false;
  if (!noindex && !nofollow) {
    return const {};
  }
  final values = [if (noindex) 'noindex', if (nofollow) 'nofollow'].join(', ');
  return {'x-robots-tag': values};
}

Response _cachedResponse(
  Request request,
  String html,
  Duration? cacheTtl,
  Map<String, String> robotsHeaders,
  ResponseDelivery delivery,
) {
  final etag = _etag(html);
  final headers = <String, String>{
    ...robotsHeaders,
    'ETag': etag,
    'Vary': 'Accept-Encoding',
    if (cacheTtl != null)
      'Cache-Control': 'public, max-age=${cacheTtl.inSeconds}',
  };
  if (_ifNoneMatchContains(request.headers['if-none-match'], etag)) {
    return Response(304, headers: headers);
  }
  return Response(
    200,
    body: html,
    headers: {'Content-Type': 'text/html; charset=utf-8', ...headers},
  );
}

/// RFC 9110 `If-None-Match`: a comma-separated list of entity tags, each
/// optionally prefixed with the weak validator marker `W/`, or `*`.
bool _ifNoneMatchContains(String? headerValue, String etag) {
  if (headerValue == null) {
    return false;
  }
  if (headerValue.trim() == '*') {
    return true;
  }
  for (final candidate in headerValue.split(',')) {
    var value = candidate.trim();
    if (value.startsWith('W/')) {
      value = value.substring(2);
    }
    if (value == etag) {
      return true;
    }
  }
  return false;
}

/// Deterministic 64-bit FNV-1a hash over the HTML - stable across process
/// restarts, formatted as 16 lowercase hex digits.
String _etag(String html) {
  var hash = 0xcbf29ce484222325;
  for (final unit in html.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  final high = (hash >>> 32).toRadixString(16).padLeft(8, '0');
  final low = (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return '"$high$low"';
}

bool _isBotRequest(Request request, Pattern? botUserAgentPattern) {
  if (botUserAgentPattern == null) return false;
  final userAgent = request.headers['user-agent'];
  if (userAgent == null) return false;
  return botUserAgentPattern.allMatches(userAgent).isNotEmpty;
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
