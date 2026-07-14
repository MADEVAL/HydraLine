/// Hydraline core — pure-Dart document model, HTML serializer, escaping and SEO
/// artifacts.
///
/// This package must not import `package:flutter/*`, `dart:ui` or `dart:html`
/// (invariant I1); enforced by `melos run boundaries`.
library;

export 'src/audit.dart';
export 'src/collector.dart';
export 'src/document_node.dart';
export 'src/escaping.dart';
export 'src/html_serializer.dart';
export 'src/island_manifest.dart';
export 'src/metadata.dart';
export 'src/robots.dart';
export 'src/route_manifest.dart';
export 'src/sitemap.dart';
export 'src/structured_data.dart';
export 'src/validators.dart';
