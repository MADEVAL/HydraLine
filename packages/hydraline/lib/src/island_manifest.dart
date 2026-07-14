/// Island manifest and the `data-state` props contract
/// (ARCHITECTURE.md §8.2/§8.3; C-7, DS1-DS5).
library;

import 'dart:convert';

import 'document_node.dart'
    show
        HydrationDirective,
        IslandRenderMode,
        IslandSize,
        IslandStyleMode,
        IslandType;
import 'escaping.dart' show escapeHtmlAttribute;

/// JSON-safe island state: `String|int|double|bool|null|List|Map<String,Object?>` (DS2).
typedef IslandState = Map<String, Object?>;

/// Serialises island props across the server → HTML → client boundary (DS1-DS5).
abstract final class IslandStateCodec {
  /// DS4: soft budget (~10 KB) per island; devtools warns past this.
  static const int maxBytes = 10 * 1024;

  /// DS1: `jsonEncode` + HTML-attribute escape. Throws [ArgumentError] on a
  /// non-JSON-safe value (DS3): `DateTime`, `Uri`, functions, etc.
  static String encode(IslandState state) {
    _validate(state, 'state');
    return escapeHtmlAttribute(jsonEncode(state));
  }

  /// Reverses [encode]: HTML-unescape then `jsonDecode`.
  static IslandState decode(String attributeValue) {
    final json = jsonDecode(_unescape(attributeValue));
    if (json is! Map) {
      throw const FormatException('island state must be a JSON object');
    }
    return json.cast<String, Object?>();
  }

  /// DS4: byte size of the JSON payload (before HTML-escaping).
  static int byteSize(IslandState state) =>
      utf8.encode(jsonEncode(state)).length;

  static void _validate(Object? value, String path) {
    switch (value) {
      case null:
      case bool():
      case int():
      case double():
      case String():
        return;
      case List():
        for (final (i, item) in value.indexed) {
          _validate(item, '$path[$i]');
        }
      case Map():
        for (final entry in value.entries) {
          if (entry.key is! String) {
            throw ArgumentError.value(
              entry.key,
              path,
              'island state map keys must be String',
            );
          }
          _validate(entry.value, '$path.${entry.key}');
        }
      default:
        throw ArgumentError.value(
          value,
          path,
          'island state must be JSON-safe (DS2); got ${value.runtimeType}',
        );
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// A serialisable island descriptor.
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
    this.endpoint,
    this.kind,
  });

  final String id;
  final IslandType type;
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final IslandSize? size;
  final IslandState state;
  final String? mountSelector;
  final String? endpoint;
  final String? kind;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'directive': directive.name,
    'renderMode': renderMode.name,
    'styleMode': styleMode.name,
    if (size != null) 'size': {'width': size!.width, 'height': size!.height},
    if (state.isNotEmpty) 'state': state,
    if (mountSelector != null) 'mountSelector': mountSelector,
    if (endpoint != null) 'endpoint': endpoint,
    if (kind != null) 'kind': kind,
  };

  static IslandSpec fromJson(Map<String, Object?> json) {
    final size = json['size'];
    return IslandSpec(
      id: json['id']! as String,
      type: IslandType.values.byName(json['type']! as String),
      directive: HydrationDirective.values.byName(json['directive']! as String),
      renderMode: IslandRenderMode.values.byName(json['renderMode']! as String),
      styleMode: IslandStyleMode.values.byName(json['styleMode']! as String),
      size: size is Map
          ? IslandSize(
              width: (size['width']! as num).toInt(),
              height: (size['height']! as num).toInt(),
            )
          : null,
      state: (json['state'] as Map?)?.cast<String, Object?>() ?? const {},
      mountSelector: json['mountSelector'] as String?,
      endpoint: json['endpoint'] as String?,
      kind: json['kind'] as String?,
    );
  }
}

/// The set of islands on a page, embedded into the HTML and consumed by the
/// dispatcher.
abstract interface class IslandManifest {
  factory IslandManifest(List<IslandSpec> islands) = _IslandManifest;

  List<IslandSpec> get islands;

  /// JSON serialisation embedded in the page.
  String serialize();

  static IslandManifest deserialize(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! List) {
      throw const FormatException('island manifest must be a JSON array');
    }
    return _IslandManifest([
      for (final item in decoded)
        IslandSpec.fromJson((item as Map).cast<String, Object?>()),
    ]);
  }
}

class _IslandManifest implements IslandManifest {
  _IslandManifest(List<IslandSpec> islands)
    : islands = List.unmodifiable(islands);

  @override
  final List<IslandSpec> islands;

  @override
  String serialize() => jsonEncode([for (final i in islands) i.toJson()]);
}
