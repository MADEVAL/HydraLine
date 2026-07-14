// Hydraline — API contract (L4) · packages/hydraline/api/manifests.dart
//
// Route manifest, island manifest, data-state contract, and SsgCollector.
//
// ignore_for_file: unused_element

import 'document_node.dart'
    show DocumentNode, HydrationDirective, IslandType, IslandRenderMode, IslandStyleMode, IslandSize;
import 'escaping.dart' show SafeUrl;
import 'metadata.dart' show SeoMeta;

// ── Route manifest ────────────────────────────────────────────────────────────

enum RouteMode { app, document, hybrid }

/// Content source: widgets (surface A) or pure-Dart builder (surface B).
sealed class ContentSource {
  const ContentSource();
}

/// Surface A: content is extracted from Flutter route widgets at build-time
/// (SSG). `pageBuilderId` is optional: a bare `content_source: widget` in YAML
/// suffices (the page is matched to the route via RouteAdapter); the identifier
/// is only needed for programmatic registration of multiple page builders.
final class WidgetContent extends ContentSource {
  const WidgetContent([this.pageBuilderId]);
  final String? pageBuilderId;
}

final class DartBuilderContent extends ContentSource {
  const DartBuilderContent(this.builderId); // e.g. 'BlogPostBuilder.new'
  final String builderId;
}

class RouteEntry {
  const RouteEntry({
    required this.path,
    required this.mode,
    this.metadata,
    this.contentSource,
    this.dynamicSegments = const {}, // SSG only
  });
  final String path; // path-routing, no hash
  final RouteMode mode;
  final SeoMeta? metadata;
  final ContentSource? contentSource;
  final Map<String, List<String>> dynamicSegments;
}

/// YAML (`hydraline.routes.yaml`) — primary; Dart-builder generates the same.
abstract interface class RouteManifest {
  List<RouteEntry> get routes;

  /// Parsing the canonical YAML.
  static RouteManifest parseYaml(String yaml) => throw UnimplementedError();

  /// Programmatic construction (round-trip to YAML).
  static RouteManifestBuilder builder() => throw UnimplementedError();

  String toYaml();
}

abstract interface class RouteManifestBuilder {
  RouteManifestBuilder route(RouteEntry entry);
  RouteManifest build();
}

// ── data-state / props contract ────────────────────────────────────────────────

/// JSON-safe value: String|int|double|bool|null|List|Map<String,dynamic>.
typedef IslandState = Map<String, Object?>;

abstract final class IslandStateCodec {
  /// Encodes state to JSON + HTML-escapes for the data-state attribute.
  /// Throws on non-deterministic or disallowed values.
  /// Budget: ~10 KB.
  static String encode(IslandState state) => throw UnimplementedError();

  static IslandState decode(String attributeValue) => throw UnimplementedError();

  /// Budget check — used by devtools.
  static int byteSize(IslandState state) => throw UnimplementedError();
}

// ── Island manifest ────────────────────────────────────────────────────────────

class IslandSpec {
  const IslandSpec({
    required this.id,
    required this.type,
    this.directive = HydrationDirective.onIdle,
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.size,
    this.state = const {},
    this.mountSelector,
    this.endpoint, // htmx
    this.kind, // vanilla
  });
  final String id;
  final IslandType type;
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final IslandSize? size; // anti-CLS
  final IslandState state;
  final String? mountSelector;
  final String? endpoint;
  final String? kind;
}

abstract interface class IslandManifest {
  List<IslandSpec> get islands;
  String serialize(); // embedded into HTML
  static IslandManifest deserialize(String data) => throw UnimplementedError();
}

// ── SsgCollector ──────────────────────────────────────────────────────────────

/// Pure-Dart collector for self-registering widgets (surface A).
/// Instance-scoped. Immutable after seal().
abstract interface class SsgCollector {
  factory SsgCollector(String route) => throw UnimplementedError();

  void addText(String text, {int? headingLevel, String? key});
  void addImage(SafeUrl src, String alt, {int? width, int? height, String? key});
  void addLink(SafeUrl href, String text, {String? key});
  void addIsland(IslandSpec spec, {String? key});
  void addMeta(SeoMeta meta);

  /// Finalize: dedup by key, acyclicity check, immutable result.
  DocumentNode seal();
}
