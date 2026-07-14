// Hydraline — API contract (L4) · packages/hydraline_flutter/api/runtime_ssg.dart
//
// IslandHost/multiview, props reception, routing adapters, SSG runner/CLI, devtools.
//
// ignore_for_file: unused_element, undefined_class, uri_does_not_exist

import 'package:flutter/widgets.dart';

// ── IslandHost ─────────────────────────────────────────────────────────────────

typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

/// Root multiview widget on the Dart side (runWidget + ViewCollection + View).
/// One engine instance — N views. Maps view→island by id from initialData.
class IslandHost extends StatelessWidget {
  const IslandHost({required this.factories, super.key});

  /// Registry of factories; heavy ones loaded via deferred loadLibrary() inside the factory.
  final Map<String, IslandFactory> factories;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Type-safe access to an island's initialData.
abstract interface class IslandProps {
  static IslandProps of(Object view /* FlutterView */) => throw UnimplementedError();
  String get id;
  Map<String, Object?> get state;
  T? get<T>(String key);
}

// ── Routing adapters ───────────────────────────────────────────────────────────

class RouteInfo {
  const RouteInfo({required this.path, this.name});
  final String path;
  final String? name;
}

/// Common interface: links a router to the route manifest for build-time traversal.
abstract interface class RouteAdapter {
  List<RouteInfo> get routes;
  Future<void> navigateToForExtraction(RouteInfo route);
}

/// First-class go_router adapter (cross-checks GoRoute tree with the manifest).
abstract interface class GoRouterAdapter implements RouteAdapter {
  factory GoRouterAdapter(Object goRouter) => throw UnimplementedError();
}

/// Fallback for raw Navigator 2.0 (beamer not supported).
abstract interface class Navigator2Adapter implements RouteAdapter {}

// ── SSG runner + CLI ───────────────────────────────────────────────────────────

class SsgResult {
  const SsgResult({required this.pagesWritten, required this.assetsCopied});
  final int pagesWritten;
  final bool assetsCopied; // true only when IslandType.flutter is present
}

/// REQUIRES dart:ui — runs inside the flutter_tester harness
/// (`flutter test --tags ssg`) or a Flutter-compiled executable
/// (AutomatedTestWidgetsFlutterBinding). Does NOT work via plain `dart run`.
abstract interface class SsgRunner {
  factory SsgRunner({
    required Object routeManifest,
    required RouteAdapter routeAdapter,
    required Map<String, IslandFactory> islandFactories,
  }) => throw UnimplementedError();

  /// Single party responsible for copying the island bundle + web/ assets
  /// from build/web to dist (only if Flutter islands are present, else skipped).
  /// Deterministic output (stable paths/ordering).
  Future<SsgResult> run({required String outputDir /* dist/ */});
}

// CLI entrypoint: `dart run hydraline_flutter:build` (encapsulates the SSG environment).

// ── DevTools ───────────────────────────────────────────────────────────────────

/// Overlay: island/directive/boundary highlighting, hydration diagnostics,
/// anti-CLS warnings (missing sizes) and props > 10 KB warnings.
class HydraDevtoolsOverlay extends StatelessWidget {
  const HydraDevtoolsOverlay({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Compares SSG-HTML ↔ hydrated DOM (divergence > 5% → warning).
abstract final class HydrationDiagnostics {
  static Future<List<String>> diffSsgVsHydrated({required String ssgHtml, required Object liveDom}) =>
      throw UnimplementedError();
}
