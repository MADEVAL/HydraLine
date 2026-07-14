// Hydraline — API contract (L4) · packages/hydraline_server/api/server.dart
//
// SSR / HTMX / bot-aware delivery. This package does NOT import flutter.
//
// ignore_for_file: unused_element

// Pseudo-imports (real: package:shelf, package:hydraline/*).
import 'dart:async';

typedef Request = Object; // shelf.Request
typedef Response = Object; // shelf.Response
typedef Handler = FutureOr<Response> Function(Request request);
typedef Middleware = Handler Function(Handler inner);

typedef DocumentNode = Object; // hydraline.DocumentNode
typedef RouteManifest = Object; // hydraline.RouteManifest

// ── Content builder (signature does NOT receive User-Agent) ────────────────────

/// Extension point for dynamic routes. Compile-time guarantee: no access to UA →
/// architectural ban on cloaking. `data` — data from developer's DB/API.
typedef DocumentBuilder = FutureOr<DocumentNode> Function(Request request, Object? data);

// ── Middleware / handler ───────────────────────────────────────────────────────

class HydralineConfig {
  const HydralineConfig({
    required this.manifest,
    this.builders = const {}, // path → DocumentBuilder (surface B)
    this.cache,
    this.botUserAgentPattern, // for delivery selection (NOT content!)
  });
  final RouteManifest manifest;
  final Map<String, DocumentBuilder> builders;
  final HydralineCache? cache;
  final Pattern? botUserAgentPattern;
}

/// shelf-middleware. Matches by manifest: document/hybrid → render; app → shell.
Middleware hydralineMiddleware(HydralineConfig config) => throw UnimplementedError();

/// Dart Frog adapter on top of the same logic.
abstract final class DartFrogAdapter {
  static Handler middleware(HydralineConfig config) => throw UnimplementedError();
}

// ── Delivery ──────────────────────────────────────────────────────────────────

enum DeliveryMode { buffered, chunked }

/// Two-layer design: content (UA-blind) is separated from transport (may read UA).
/// Identity invariant: `bytes(buffered) == bytes(concat(chunks))` on deterministic input.
abstract interface class ResponseDelivery {
  /// Bots: full HTML at once (Content-Length).
  Response buffered(DocumentNode root, {int status = 200, Map<String, String> headers});

  /// Users: same stream as chunks (Transfer-Encoding: chunked), in-order flush.
  Response chunked(DocumentNode root, {int status = 200, Map<String, String> headers});
}

// ── HTTP semantics ─────────────────────────────────────────────────────────────

abstract final class Http {
  static Response redirect(String location, {int status = 301}) => throw UnimplementedError();
  static Response notFound({DocumentNode? body}) => throw UnimplementedError(); // 404
  static Response gone() => throw UnimplementedError(); // 410
  static Response withRobots(Response base, {bool noindex = false, bool nofollow = false}) =>
      throw UnimplementedError(); // X-Robots-Tag
  static String canonicalizePath(String path) => throw UnimplementedError(); // no hash
}

// ── HTMX helpers ───────────────────────────────────────────────────────────────

class HtmxTrigger {
  const HtmxTrigger(this.value); // e.g. 'load', 'click', 'revealed'
  final String value;
}

abstract final class Htmx {
  /// Fragment without <html>/<head> (serializeFragment).
  static Response renderFragment(DocumentNode fragment, {int status = 200}) =>
      throw UnimplementedError();
}

class HtmxResponse {
  const HtmxResponse({required this.body, this.trigger, this.retarget, this.reswap});
  final DocumentNode body;
  final HtmxTrigger? trigger; // HX-Trigger
  final String? retarget; // HX-Retarget
  final String? reswap; // HX-Reswap
}

// ── Cache ──────────────────────────────────────────────────────────────────────

abstract interface class HydralineCache {
  Future<String?> get(String key);
  Future<void> set(String key, String html, {Duration? ttl, String? etag});
}

// ── Assets ─────────────────────────────────────────────────────────────────────

abstract final class Assets {
  /// Serves sitemap/robots + L0–L1 core assets (vanilla, self-hosted HTMX).
  static Handler serveCoreAssets() => throw UnimplementedError();

  /// Injects island manifest + ABSOLUTE engine paths:
  /// `/flutter_bootstrap.js`, `/main.dart.js`, `/canvaskit/` or via <base href>.
  /// Only for routes with IslandType.flutter.
  static DocumentNode injectFlutterAssets(DocumentNode root, {String baseHref = '/'}) =>
      throw UnimplementedError();
}
