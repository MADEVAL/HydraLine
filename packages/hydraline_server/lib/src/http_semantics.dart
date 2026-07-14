/// HTTP semantics: status codes, redirects, X-Robots-Tag and path
/// canonicalisation (ARCHITECTURE.md §10; S-7, SEO-9).
library;

import 'dart:convert';

import 'package:hydraline/hydraline.dart' show DocumentNode, HtmlSerializer;
import 'package:shelf/shelf.dart';

/// Redirect marker thrown from a `DocumentBuilder` so the middleware can
/// produce a redirect without the builder creating a shelf `Response` directly
/// (keeping the builder pure from HTTP concerns).
class RedirectException implements Exception {
  const RedirectException(this.location, {this.status = 301});

  final String location;
  final int status;
}

/// HTTP / status helper.
abstract final class Http {
  /// 301/302 redirect.
  static Response redirect(String location, {int status = 301}) {
    return status == 301
        ? Response.movedPermanently(location)
        : Response.found(location);
  }

  /// 404.
  static Response notFound({DocumentNode? body}) {
    if (body != null) {
      return Response(404, body: utf8.encode(HtmlSerializer().serialize(body)));
    }
    return Response.notFound('');
  }

  /// 410 Gone.
  static Response gone() => Response(410, body: '');

  /// Attaches an `X-Robots-Tag` header to [base].
  static Response withRobots(
    Response base, {
    bool noindex = false,
    bool nofollow = false,
  }) {
    if (!noindex && !nofollow) {
      return base;
    }
    final values = [
      if (noindex) 'noindex',
      if (nofollow) 'nofollow',
    ].join(', ');
    return base.change(headers: {'x-robots-tag': values});
  }

  /// Canonicalises a path: normalises slashes, strips trailing slash, ensures
  /// leading slash (SEO-7).
  static String canonicalizePath(String path) {
    var clean = path.replaceAll(RegExp(r'/+'), '/');
    if (clean.length > 1 && clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('/')) {
      clean = '/$clean';
    }
    return clean;
  }
}
