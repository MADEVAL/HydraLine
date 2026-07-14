// Hydraline — API contract (L4) · packages/hydraline_flutter/api/widgets.dart
//
// Flutter widgets (surface A) + Island.
//
// ignore_for_file: unused_element, undefined_class, uri_does_not_exist

import 'package:flutter/widgets.dart';
import 'package:hydraline/hydraline.dart'
    show SsgCollector, SectionRole, IslandType, HydrationDirective, IslandRenderMode, IslandStyleMode, SeoMeta;

// ── Integration ────────────────────────────────────────────────────────────────

/// Integration wrapper. Provides [HydraScope]. Does NOT replace MaterialApp.
class HydraApp extends StatelessWidget {
  const HydraApp({required this.child, this.collector, super.key});
  final Widget child;
  final SsgCollector? collector; // null in runtime mode
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// InheritedWidget holding the collector (single access point from widgets).
class HydraScope extends InheritedWidget {
  const HydraScope({required this.collector, required this.isSsgMode, required super.child, super.key});
  final SsgCollector? collector;
  final bool isSsgMode;
  static HydraScope of(BuildContext context) => throw UnimplementedError();
  @override
  bool updateShouldNotify(covariant HydraScope oldWidget) => throw UnimplementedError();
}

/// Build-time extraction wrapper: stubs MediaQuery/Navigator/Directionality.
class SsgSandbox extends StatelessWidget {
  const SsgSandbox({required this.collector, required this.child, super.key});
  final SsgCollector collector;
  final Widget child;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// ── Seo.* widgets (dual nature) ────────────────────────────────────────────────

/// Namespace factories. Each: (1) visual widget, (2) self-registering in build().
abstract final class Seo {
  static Widget text(String text, {int? headingLevel, Key? key}) => throw UnimplementedError();
  static Widget heading(String text, {required int level, Key? key}) => throw UnimplementedError();
  static Widget image(String src, {required String alt, int? width, int? height, Key? key}) => throw UnimplementedError();
  static Widget link({required String href, required Widget child, Key? key}) => throw UnimplementedError();
  static Widget section({required SectionRole role, required List<Widget> children, Key? key}) => throw UnimplementedError();
  static Widget list({required bool ordered, required List<Widget> items, Key? key}) => throw UnimplementedError();
  static Widget head(SeoMeta meta) => throw UnimplementedError();
}

// ── Island ─────────────────────────────────────────────────────────────────────

/// Two orthogonal axes: directive (when to hydrate) ⟂ renderMode (what goes in HTML).
class Island extends StatelessWidget {
  const Island({
    required this.id,
    required this.type,
    this.props = const {},
    this.directive = HydrationDirective.onIdle, // default
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.width,
    this.height, // anti-CLS
    this.placeholder,
    this.errorFallback, // shown when data-hydration="failed"
    this.mediaQuery, // for HydrationDirective.onMedia
    super.key,
  });
  final String id;
  final IslandType type;
  final Map<String, Object?> props; // JSON-safe
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorFallback;
  final String? mediaQuery;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
