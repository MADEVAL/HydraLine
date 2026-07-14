/// Dart Frog adapter - wraps [hydralineMiddleware] so it plugs into a Dart Frog
/// server with the same configuration.
library;

import 'package:shelf/shelf.dart';

import 'middleware.dart' show HydralineConfig, hydralineMiddleware;

/// Provides [hydralineMiddleware] as a Dart Frog compatible [Middleware].
abstract final class DartFrogAdapter {
  /// Returns the same shelf [Middleware] as [hydralineMiddleware]; the adapter
  /// is a passthrough since both shelf and Dart Frog use the same handler type.
  static Middleware middleware(HydralineConfig config) =>
      hydralineMiddleware(config);
}
