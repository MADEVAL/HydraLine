/// SSG runner: iterates the route manifest, extracts a [DocumentNode] for every
/// route via SSG extraction (flutter_tester), and writes the serialised HTML
/// + sitemap + robots + island assets into an output directory.
library;

import 'dart:io';

import 'package:hydraline/hydraline.dart';

import 'assets/js_custom_element.dart' show jsCustomElement;
import 'assets/js_dispatcher.dart' show jsDispatcher;
import 'assets/js_service_worker.dart' show jsServiceWorker;
import 'assets/js_virtual_views.dart' show jsVirtualViews;
import 'route_adapter.dart' show RouteAdapter;

/// Generates the default [SeoMeta] for a route when no explicit metadata is
/// configured in the manifest.
///
/// `app` routes default to `noindex`.
SeoMeta defaultSeoMeta(RouteEntry route) {
  final noindex = route.mode == RouteMode.app;
  return SeoMeta(
    title: route.path,
    robots: RobotsDirectives(noindex: noindex || (route.noindex ?? false)),
  );
}

/// The result of an SSG run.
class SsgResult {
  const SsgResult({required this.pagesWritten, required this.assetsCopied});

  final int pagesWritten;

  /// `true` when Flutter islands were present and their bundle was copied.
  final bool assetsCopied;
}

/// A pure-Dart page builder (surface B) invoked at build time for each
/// concrete path expanded from the route pattern it is registered under.
typedef SsgPageBuilder = DocumentNode Function(String path);

/// Runs on the plain Dart VM (`dart run hydraline_flutter:build` or a custom
/// `bin/build.dart`). Page content comes from registered pure-Dart
/// [SsgPageBuilder]s (surface B); routes without a builder produce a
/// metadata-only shell from the manifest. Widget-based extraction (surface A)
/// happens separately via `SsgCollector` inside a `flutter test --tags ssg`
/// harness.
abstract interface class SsgRunner {
  factory SsgRunner({
    required RouteManifest routeManifest,
    required Map<String, Object?> islandFactories,
    RouteAdapter? routeAdapter,
    Map<String, SsgPageBuilder> builders,
  }) = _SsgRunner.create;

  /// The ONLY responsible for writing the island runtime JS into the output
  /// dir (only when islands of type flutter are present).
  /// Deterministic output (stable paths, stable order).
  Future<SsgResult> run({required String outputDir});
}

class _SsgRunner implements SsgRunner {
  _SsgRunner({
    required RouteManifest manifest,
    required Map<String, Object?> islandFactories,
    RouteAdapter? adapter,
    Map<String, SsgPageBuilder> builders = const {},
  }) : _manifest = manifest,
       _adapter = adapter,
       _islandFactories = islandFactories,
       _builders = builders;

  factory _SsgRunner.create({
    required RouteManifest routeManifest,
    required Map<String, Object?> islandFactories,
    RouteAdapter? routeAdapter,
    Map<String, SsgPageBuilder> builders = const {},
  }) => _SsgRunner(
    manifest: routeManifest,
    adapter: routeAdapter,
    islandFactories: islandFactories,
    builders: builders,
  );

  final RouteManifest _manifest;
  final RouteAdapter? _adapter;
  final Map<String, Object?> _islandFactories;
  final Map<String, SsgPageBuilder> _builders;
  final HtmlSerializer _serializer = const HtmlSerializer();

  bool _hasFlutterIslands() =>
      _islandFactories.values.contains(IslandType.flutter);

  @override
  Future<SsgResult> run({required String outputDir}) async {
    _adapter; // reserved for widget-based extraction
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Sitemap origin: the manifest base_url wins; the localhost fallback
    // keeps output valid for local previews when no base_url is configured.
    final baseUrl = SafeUrl.parse(_origin(_manifest.baseUrl));

    final entries = <SitemapEntry>[];
    var pagesWritten = 0;

    for (final route in _manifest.routes) {
      if (route.mode == RouteMode.app) {
        continue;
      }

      final paths = route.dynamicSegments.isNotEmpty
          ? DynamicSegments.expand({route.path: route.dynamicSegments})
          : <String>[route.path];

      for (final concretePath in paths) {
        final root = _buildRoot(route, concretePath);
        final html = _serializer.serialize(root);

        final filePath = _filePath(outputDir, concretePath);
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(html);
        pagesWritten++;

        final canonical = route.metadata?.canonical;
        entries.add(
          SitemapEntry(
            loc: canonical ?? SafeUrl.parse('${baseUrl.value}$concretePath'),
          ),
        );
      }
    }

    // Sitemap
    final sitemapOutput = await Sitemap.generate(
      _ListSource(entries),
      baseUrl: baseUrl,
    );
    for (final entry in sitemapOutput.files.entries) {
      await File('$outputDir/${entry.key}').writeAsString(entry.value);
    }

    // Robots
    final robotsTxt = Robots.generate(
      rules: const [RobotsRule(userAgent: '*')],
    );
    await File('$outputDir/robots.txt').writeAsString(robotsTxt);

    final assetsCopied = _hasFlutterIslands();
    if (assetsCopied) {
      await _copyAssets(outputDir);
    }

    return SsgResult(pagesWritten: pagesWritten, assetsCopied: assetsCopied);
  }

  /// Builds the page for [concretePath]: a registered [SsgPageBuilder] wins;
  /// otherwise a metadata-only shell is produced from the route manifest.
  DocumentNode _buildRoot(RouteEntry route, String concretePath) {
    final builder = _builders[route.path];
    if (builder != null) {
      final built = builder(concretePath);
      if (built is DocumentRootNode) {
        return built;
      }
      return DocumentRootNode(
        head: buildHead(route.metadata ?? defaultSeoMeta(route)),
        body: [built],
        lang: route.metadata?.lang,
      );
    }
    return DocumentRootNode(
      head: buildHead(route.metadata ?? defaultSeoMeta(route)),
      body: const [],
      lang: route.metadata?.lang,
    );
  }

  /// The first-party runtime files, written from the inline constants that
  /// are byte-identical to this package's `web/` sources (locked by test).
  /// The application's own `web/` host files (`index.html`,
  /// `flutter_bootstrap.js`, ...) are never touched - copying them would
  /// overwrite the generated pages.
  static const Map<String, String> _runtimeAssets = {
    'hydraline-dispatcher.js': jsDispatcher,
    'hydraline-island.js': jsCustomElement,
    'hydraline-virtual-views.js': jsVirtualViews,
    'service-worker.js': jsServiceWorker,
  };

  Future<void> _copyAssets(String outputDir) async {
    for (final asset in _runtimeAssets.entries) {
      await File('$outputDir/${asset.key}').writeAsString(asset.value);
    }
  }

  String _filePath(String outputDir, String routePath) {
    var path = routePath == '/' ? '/index' : routePath;
    if (!path.endsWith('.html')) {
      path = '$path.html';
    }
    path = path.replaceAll(':', '-');
    return '$outputDir$path';
  }

  /// Strips a trailing slash so `origin + path` never doubles the separator.
  static String _origin(String? baseUrl) {
    final base = baseUrl ?? 'https://localhost';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}

class _ListSource implements SitemapSource {
  _ListSource(this._entries);
  final List<SitemapEntry> _entries;

  @override
  Stream<SitemapEntry> entries() => Stream.fromIterable(_entries);
}

/// Expands dynamic segment patterns into concrete paths.
abstract final class DynamicSegments {
  /// [segments] maps a route pattern (e.g. `/blog/:category/:slug`) to its
  /// per-segment values. Every named segment is replaced by each of its
  /// values; multiple segments expand as a cartesian product in declaration
  /// order. Throws [ArgumentError] when a named segment has no values.
  static List<String> expand(Map<String, Map<String, List<String>>> segments) {
    final expanded = <String>[];
    for (final entry in segments.entries) {
      expanded.addAll(_expandPattern(entry.key, entry.value));
    }
    return expanded;
  }

  static List<String> _expandPattern(
    String pattern,
    Map<String, List<String>> values,
  ) {
    final parts = pattern.split('/');
    var paths = <List<String>>[parts];
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i].startsWith(':')) {
        continue;
      }
      final name = parts[i].substring(1);
      final segmentValues = values[name];
      if (segmentValues == null || segmentValues.isEmpty) {
        throw ArgumentError.value(
          values,
          'segments',
          'no values for ":$name" in "$pattern"',
        );
      }
      paths = [
        for (final path in paths)
          for (final value in segmentValues) List.of(path)..[i] = value,
      ];
    }
    return [for (final path in paths) path.join('/')];
  }
}
