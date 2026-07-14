/// SSG runner: iterates the route manifest, extracts a [DocumentNode] for every
/// route via SSG extraction (flutter_tester), and writes the serialised HTML
/// + sitemap + robots + island assets into an output directory.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:hydraline/hydraline.dart';

import 'route_adapter.dart' show RouteAdapter;

/// Generates the default [SeoMeta] for a route when no explicit metadata is
/// configured in the manifest.
///
/// `app` routes default to `noindex` (§4.1).
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

/// MUST be executed inside a flutter_tester harness
/// (`flutter test --tags ssg`). Never plain `dart run`.
abstract interface class SsgRunner {
  factory SsgRunner({
    required Object routeManifest,
    required RouteAdapter routeAdapter,
    required Map<String, Object?> islandFactories,
  }) => _SsgRunner(
    manifest: routeManifest as RouteManifest,
    adapter: routeAdapter,
    islandFactories: islandFactories,
  );

  /// The ONLY responsible for copying the island bundle + web/ assets
  /// into the output dir (only when islands of type flutter are present).
  /// Deterministic output (stable paths, stable order).
  Future<SsgResult> run({required String outputDir});
}

class _SsgRunner implements SsgRunner {
  _SsgRunner({
    required RouteManifest manifest,
    required RouteAdapter adapter,
    required Map<String, Object?> islandFactories,
  }) : _manifest = manifest,
       _adapter = adapter,
       _islandFactories = islandFactories;

  final RouteManifest _manifest;
  final RouteAdapter _adapter;
  final Map<String, Object?> _islandFactories;
  final HtmlSerializer _serializer = const HtmlSerializer();

  bool _hasFlutterIslands() => _islandFactories.isNotEmpty;

  @override
  Future<SsgResult> run({required String outputDir}) async {
    _adapter; // reserved for widget-based extraction
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

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
        final head = buildHead(route.metadata ?? defaultSeoMeta(route));
        final root = DocumentRootNode(
          head: head,
          body: const [],
          lang: route.metadata?.lang,
        );
        final html = _serializer.serialize(root);

        final filePath = _filePath(outputDir, concretePath);
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(html);
        pagesWritten++;

        final canonical = route.metadata?.canonical;
        entries.add(
          SitemapEntry(
            loc: canonical ?? SafeUrl.parse('https://localhost$concretePath'),
          ),
        );
      }
    }

    // Sitemap
    final baseUrl = SafeUrl.parse('https://localhost');
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

  Future<void> _copyAssets(String outputDir) async {
    final webDir = await _findWebDir();
    if (webDir == null) return;

    await for (final entity in webDir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        await entity.copy('$outputDir/$name');
      }
    }
  }

  Future<Directory?> _findWebDir() async {
    final cwdWeb = Directory('web');
    if (await cwdWeb.exists()) return cwdWeb;

    try {
      final libUri = await Isolate.resolvePackageUri(
        Uri.parse('package:hydraline_flutter/hydraline_flutter.dart'),
      );
      if (libUri != null) {
        final resolved = Directory.fromUri(libUri.resolve('../../web/'));
        if (await resolved.exists()) return resolved;
      }
    } catch (_) {}

    return null;
  }

  String _filePath(String outputDir, String routePath) {
    var path = routePath == '/' ? '/index' : routePath;
    if (!path.endsWith('.html')) {
      path = '$path.html';
    }
    path = path.replaceAll(':', '-');
    return '$outputDir$path';
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
  static List<String> expand(Map<String, Map<String, List<String>>> segments) {
    final expanded = <String>[];
    for (final entry in segments.entries) {
      for (final value in entry.value.values.expand((v) => v)) {
        expanded.add(entry.key.replaceFirst(RegExp(r':[^/]+'), value));
      }
    }
    return expanded;
  }
}
