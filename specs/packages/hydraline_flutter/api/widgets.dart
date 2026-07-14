// Hydraline — API-контракт (L4) · packages/hydraline_flutter/api/widgets.dart
//
// Flutter-виджеты (поверхность A) + Island. Реализация — PHASE_3 (P3-01…P3-04).
// ARCHITECTURE.md §11.1. Соответствие W-1…W-4.
//
// ignore_for_file: unused_element, undefined_class, uri_does_not_exist

import 'package:flutter/widgets.dart';
import 'package:hydraline/hydraline.dart'
    show SsgCollector, SectionRole, IslandType, HydrationDirective, IslandRenderMode, IslandStyleMode, SeoMeta;

// ── Интеграция (W-3, W-4) ─────────────────────────────────────────────────────

/// Интеграционная обёртка. Предоставляет [HydraScope]. НЕ заменяет MaterialApp.
class HydraApp extends StatelessWidget {
  const HydraApp({required this.child, this.collector, super.key});
  final Widget child;
  final SsgCollector? collector; // null в runtime-режиме
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// InheritedWidget с коллектором (CO2: единственная точка доступа из виджетов).
class HydraScope extends InheritedWidget {
  const HydraScope({required this.collector, required this.isSsgMode, required super.child, super.key});
  final SsgCollector? collector;
  final bool isSsgMode;
  static HydraScope of(BuildContext context) => throw UnimplementedError();
  @override
  bool updateShouldNotify(covariant HydraScope oldWidget) => throw UnimplementedError();
}

/// Обёртка build-time извлечения: заглушки MediaQuery/Navigator/Directionality (R2).
class SsgSandbox extends StatelessWidget {
  const SsgSandbox({required this.collector, required this.child, super.key});
  final SsgCollector collector;
  final Widget child;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// ── Seo.* виджеты (W-1, двойная природа) ──────────────────────────────────────

/// Namespace-фабрики. Каждый: (1) визуальный виджет, (2) self-registering в build().
abstract final class Seo {
  static Widget text(String text, {int? headingLevel, Key? key}) => throw UnimplementedError();
  static Widget heading(String text, {required int level, Key? key}) => throw UnimplementedError();
  static Widget image(String src, {required String alt, int? width, int? height, Key? key}) => throw UnimplementedError();
  static Widget link({required String href, required Widget child, Key? key}) => throw UnimplementedError();
  static Widget section({required SectionRole role, required List<Widget> children, Key? key}) => throw UnimplementedError();
  static Widget list({required bool ordered, required List<Widget> items, Key? key}) => throw UnimplementedError();
  static Widget head(SeoMeta meta) => throw UnimplementedError();
}

// ── Island (W-2) ─────────────────────────────────────────────────────────────

/// Две ортогональные оси: directive (когда гидрировать) ⟂ renderMode (что в HTML).
class Island extends StatelessWidget {
  const Island({
    required this.id,
    required this.type,
    this.props = const {},
    this.directive = HydrationDirective.onIdle, // дефолт (§7.2)
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.width,
    this.height, // anti-CLS (I8)
    this.placeholder,
    this.errorFallback, // показывается при data-hydration="failed" (§7.9)
    this.mediaQuery, // для HydrationDirective.onMedia
    super.key,
  });
  final String id;
  final IslandType type;
  final Map<String, Object?> props; // JSON-safe (DS2)
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
