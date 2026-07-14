/// Route manifest: parses/emits the canonical `hydraline.routes.yaml` and
/// provides a Dart builder for the same model.
library;

import 'package:yaml/yaml.dart';

import 'escaping.dart' show SafeUrl;
import 'metadata.dart';

/// Render mode of a route (WebRouteRenderMode).
enum RouteMode { app, document, hybrid }

/// Content owner: Flutter widgets (surface A) or a pure-Dart builder (surface B).
sealed class ContentSource {
  const ContentSource();
}

/// Surface A: content extracted from route widgets at build time (SSG).
final class WidgetContent extends ContentSource {
  const WidgetContent([this.pageBuilderId]);

  final String? pageBuilderId;
}

/// Surface B: a pure-Dart `DocumentNode` builder (e.g. `BlogPostBuilder.new`).
final class DartBuilderContent extends ContentSource {
  const DartBuilderContent(this.builderId);

  final String builderId;
}

/// A single route entry.
class RouteEntry {
  const RouteEntry({
    required this.path,
    required this.mode,
    this.metadata,
    this.contentSource,
    this.dynamicSegments = const {},
    this.noindex,
    this.includeInSitemap,
  });

  final String path;
  final RouteMode mode;
  final SeoMeta? metadata;
  final ContentSource? contentSource;
  final Map<String, List<String>> dynamicSegments;

  /// Explicit `noindex` override; when null, `mode == app` implies noindex.
  final bool? noindex;

  /// Explicit sitemap inclusion; when null, `mode != app` is included.
  final bool? includeInSitemap;
}

/// The route manifest. YAML is primary; the Dart builder emits the same YAML.
abstract interface class RouteManifest {
  List<RouteEntry> get routes;

  /// Absolute site origin from `base_url`, used for generated absolute URLs
  /// (e.g. sitemap `loc` values). `null` when the YAML omits it.
  String? get baseUrl;

  /// Parses the canonical YAML.
  static RouteManifest parseYaml(String yaml) => _parseYaml(yaml);

  /// Programmatic construction (round-trips to YAML).
  static RouteManifestBuilder builder() => _RouteManifestBuilder();

  String toYaml();
}

/// Builder for a [RouteManifest].
abstract interface class RouteManifestBuilder {
  RouteManifestBuilder route(RouteEntry entry);
  RouteManifest build();
}

class _RouteManifestBuilder implements RouteManifestBuilder {
  final List<RouteEntry> _routes = [];

  @override
  RouteManifestBuilder route(RouteEntry entry) {
    _routes.add(entry);
    return this;
  }

  @override
  RouteManifest build() => _RouteManifest(List.unmodifiable(_routes));
}

class _RouteManifest implements RouteManifest {
  const _RouteManifest(this.routes, {this.version, this.baseUrl});

  @override
  final List<RouteEntry> routes;

  final String? version;

  @override
  final String? baseUrl;

  @override
  String toYaml() {
    final out = StringBuffer();
    if (version != null) {
      out.writeln('version: ${_scalar(version!)}');
    }
    if (baseUrl != null) {
      out.writeln('base_url: ${_scalar(baseUrl!)}');
    }
    out.writeln('routes:');
    for (final route in routes) {
      out
        ..writeln('  - path: ${_scalar(route.path)}')
        ..writeln('    mode: ${_scalar(route.mode.name)}');
      final source = route.contentSource;
      if (source != null) {
        out.writeln('    content_source: ${_scalar(_encodeSource(source))}');
      }
      final metadata = route.metadata;
      if (metadata != null) {
        _writeMetadata(metadata, out);
      }
      if (route.dynamicSegments.isNotEmpty) {
        out.writeln('    dynamic_segments:');
        for (final entry in route.dynamicSegments.entries) {
          final values = entry.value.map(_scalar).join(', ');
          out.writeln('      ${entry.key}: [$values]');
        }
      }
      if (route.noindex != null) {
        out.writeln('    noindex: ${route.noindex}');
      }
      if (route.includeInSitemap != null) {
        out.writeln('    sitemap: ${route.includeInSitemap}');
      }
    }
    return out.toString();
  }

  void _writeMetadata(SeoMeta meta, StringSink out) {
    out
      ..writeln('    metadata:')
      ..writeln('      title: ${_scalar(meta.title)}');
    if (meta.description != null) {
      out.writeln('      description: ${_scalar(meta.description!)}');
    }
    if (meta.canonical != null) {
      out.writeln('      canonical: ${_scalar(meta.canonical!.value)}');
    }
    if (meta.lang != null) {
      out.writeln('      lang: ${_scalar(meta.lang!)}');
    }
    if (meta.robots.noindex || meta.robots.nofollow) {
      out
        ..writeln('      robots:')
        ..writeln('        noindex: ${meta.robots.noindex}')
        ..writeln('        nofollow: ${meta.robots.nofollow}');
    }
  }
}

String _encodeSource(ContentSource source) => switch (source) {
  WidgetContent(:final pageBuilderId) =>
    pageBuilderId == null ? 'widget' : 'widget:$pageBuilderId',
  DartBuilderContent(:final builderId) => 'dart_builder:$builderId',
};

String _scalar(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

RouteManifest _parseYaml(String yaml) {
  final doc = loadYaml(yaml);
  if (doc is! YamlMap) {
    throw const FormatException('route manifest must be a YAML map');
  }
  final rawRoutes = doc['routes'];
  if (rawRoutes is! YamlList) {
    throw const FormatException('route manifest requires a `routes` list');
  }
  final routes = <RouteEntry>[];
  for (final raw in rawRoutes) {
    if (raw is! YamlMap) {
      throw const FormatException('each route must be a map');
    }
    routes.add(_parseRoute(raw));
  }
  return _RouteManifest(
    List.unmodifiable(routes),
    version: doc['version'] as String?,
    baseUrl: doc['base_url'] as String?,
  );
}

RouteEntry _parseRoute(YamlMap raw) {
  final path = raw['path'];
  if (path is! String) {
    throw const FormatException('route is missing a `path`');
  }
  final modeName = raw['mode'];
  if (modeName is! String) {
    throw const FormatException('route is missing a `mode`');
  }
  final mode = RouteMode.values.firstWhere(
    (m) => m.name == modeName,
    orElse: () => throw FormatException('unknown route mode: $modeName'),
  );

  final rawSegments = raw['dynamic_segments'];
  final dynamicSegments = <String, List<String>>{};
  if (rawSegments is YamlMap) {
    for (final entry in rawSegments.entries) {
      final values = entry.value;
      if (values is YamlList) {
        dynamicSegments[entry.key as String] = [
          for (final v in values) v.toString(),
        ];
      }
    }
  }

  return RouteEntry(
    path: path,
    mode: mode,
    contentSource: _parseSource(raw['content_source'] as String?),
    metadata: _parseMetadata(raw['metadata']),
    dynamicSegments: dynamicSegments,
    noindex: raw['noindex'] as bool?,
    includeInSitemap: raw['sitemap'] as bool?,
  );
}

ContentSource? _parseSource(String? value) {
  if (value == null) {
    return null;
  }
  if (value == 'widget') {
    return const WidgetContent();
  }
  if (value.startsWith('widget:')) {
    return WidgetContent(value.substring('widget:'.length));
  }
  if (value.startsWith('dart_builder:')) {
    return DartBuilderContent(value.substring('dart_builder:'.length));
  }
  throw FormatException('invalid content_source: $value');
}

SeoMeta? _parseMetadata(Object? raw) {
  if (raw is! YamlMap) {
    return null;
  }
  final canonical = raw['canonical'] as String?;
  final robots = raw['robots'];
  return SeoMeta(
    title: (raw['title'] as String?) ?? '',
    description: raw['description'] as String?,
    canonical: canonical == null ? null : SafeUrl.parse(canonical),
    lang: raw['lang'] as String?,
    robots: robots is YamlMap
        ? RobotsDirectives(
            noindex: (robots['noindex'] as bool?) ?? false,
            nofollow: (robots['nofollow'] as bool?) ?? false,
          )
        : const RobotsDirectives(),
  );
}
