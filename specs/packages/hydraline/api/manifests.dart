// Hydraline — API-контракт (L4) · packages/hydraline/api/manifests.dart
//
// Route-манифест, island-манифест, контракт data-state, SsgCollector.
// Реализация — PHASE_1 (P1-15…P1-17). ARCHITECTURE.md §8/§9.
// Инварианты: RM1, DS1–DS5, CO1–CO4, N5.
//
// ignore_for_file: unused_element

import 'document_node.dart'
    show DocumentNode, HydrationDirective, IslandType, IslandRenderMode, IslandStyleMode, IslandSize;
import 'escaping.dart' show SafeUrl;
import 'metadata.dart' show SeoMeta;

// ── Route-манифест (C-8) ─────────────────────────────────────────────────────

enum RouteMode { app, document, hybrid }

/// Источник контента: виджеты (поверхность A) или pure-Dart билдер (поверхность B).
sealed class ContentSource {
  const ContentSource();
}

/// Поверхность A: контент извлекается из Flutter-виджетов маршрута в build-time
/// (SSG). `pageBuilderId` опционален: в YAML достаточно `content_source: widget`
/// (страница сопоставляется маршруту через RouteAdapter, W-5); идентификатор
/// задаётся лишь при программной регистрации нескольких page-builder'ов.
final class WidgetContent extends ContentSource {
  const WidgetContent([this.pageBuilderId]);
  final String? pageBuilderId;
}

final class DartBuilderContent extends ContentSource {
  const DartBuilderContent(this.builderId); // напр. 'BlogPostBuilder.new'
  final String builderId;
}

class RouteEntry {
  const RouteEntry({
    required this.path,
    required this.mode,
    this.metadata,
    this.contentSource,
    this.dynamicSegments = const {}, // только SSG (P1-15/W-15)
  });
  final String path; // path-routing, без hash (SEO-7)
  final RouteMode mode;
  final SeoMeta? metadata;
  final ContentSource? contentSource;
  final Map<String, List<String>> dynamicSegments;
}

/// RM1: YAML (`hydraline.routes.yaml`) — primary; Dart-builder — генератор того же.
abstract interface class RouteManifest {
  List<RouteEntry> get routes;

  /// Парсинг канонического YAML.
  static RouteManifest parseYaml(String yaml) => throw UnimplementedError();

  /// Программное построение (round-trip в YAML).
  static RouteManifestBuilder builder() => throw UnimplementedError();

  String toYaml();
}

abstract interface class RouteManifestBuilder {
  RouteManifestBuilder route(RouteEntry entry);
  RouteManifest build();
}

// ── Контракт data-state / props (§7.8, DS1–DS5) ───────────────────────────────

/// JSON-safe значение: String|int|double|bool|null|List|Map<String,dynamic>. (DS2)
typedef IslandState = Map<String, Object?>;

abstract final class IslandStateCodec {
  /// DS1: JSON.stringify + HTML-escape для атрибута data-state. DS4: лимит ~10 KB.
  /// DS3: бросает при недетерминированных/недопустимых значениях.
  static String encode(IslandState state) => throw UnimplementedError();

  static IslandState decode(String attributeValue) => throw UnimplementedError();

  /// Проверка бюджета (DS4) — используется devtools (W-18).
  static int byteSize(IslandState state) => throw UnimplementedError();
}

// ── Island-манифест (C-7) ─────────────────────────────────────────────────────

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
  final IslandSize? size; // anti-CLS (I8)
  final IslandState state;
  final String? mountSelector;
  final String? endpoint;
  final String? kind;
}

abstract interface class IslandManifest {
  List<IslandSpec> get islands;
  String serialize(); // встраивается в HTML
  static IslandManifest deserialize(String data) => throw UnimplementedError();
}

// ── SsgCollector (C-9) ─────────────────────────────────────────────────────────

/// Pure-Dart коллектор для self-registering виджетов (поверхность A).
/// CO1: инстанс-скопированный. CO4: иммутабелен после seal().
abstract interface class SsgCollector {
  factory SsgCollector(String route) => throw UnimplementedError();

  void addText(String text, {int? headingLevel, String? key});
  void addImage(SafeUrl src, String alt, {int? width, int? height, String? key});
  void addLink(SafeUrl href, String text, {String? key});
  void addIsland(IslandSpec spec, {String? key});
  void addMeta(SeoMeta meta);

  /// Финализация: dedup по key, N5-проверка (без циклов), иммутабельный результат.
  DocumentNode seal();
}
