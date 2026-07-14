// Hydraline — API-контракт (L4) · packages/hydraline_flutter/api/runtime_ssg.dart
//
// IslandHost/мультивью, props-приём, роутинг-адаптеры, SSG-раннер/CLI, devtools.
// Реализация — PHASE_3 (P3-05…P3-10) и PHASE_4 (P4-07…P4-12, P4-15).
// ARCHITECTURE.md §11.2/§11.3. Инварианты: IH1, SSG1–SSG3, I5.
//
// ignore_for_file: unused_element, undefined_class, uri_does_not_exist

import 'package:flutter/widgets.dart';

// ── IslandHost (W-6, W-7) ─────────────────────────────────────────────────────

typedef IslandFactory = Future<Widget> Function(Map<String, Object?> props);

/// Корневой мультивью-виджет Dart-стороны (runWidget + ViewCollection + View).
/// IH1: одна инстанция движка — N views. Мап view→остров по id из initialData.
class IslandHost extends StatelessWidget {
  const IslandHost({required this.factories, super.key});

  /// Реестр фабрик; тяжёлые — через deferred loadLibrary() внутри фабрики (§7.3).
  final Map<String, IslandFactory> factories;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Типобезопасный доступ к initialData острова (DS5).
abstract interface class IslandProps {
  static IslandProps of(Object view /* FlutterView */) => throw UnimplementedError();
  String get id;
  Map<String, Object?> get state;
  T? get<T>(String key);
}

// ── Роутинг-адаптеры (W-5) ────────────────────────────────────────────────────

class RouteInfo {
  const RouteInfo({required this.path, this.name});
  final String path;
  final String? name;
}

/// Общий интерфейс: связь роутера с route-манифестом для build-time обхода.
abstract interface class RouteAdapter {
  List<RouteInfo> get routes;
  Future<void> navigateToForExtraction(RouteInfo route);
}

/// First-class адаптер go_router (сверяет GoRoute-дерево с манифестом).
abstract interface class GoRouterAdapter implements RouteAdapter {
  factory GoRouterAdapter(Object goRouter) => throw UnimplementedError();
}

/// Fallback для сырого Navigator 2.0 (beamer не поддерживается — Q3).
abstract interface class Navigator2Adapter implements RouteAdapter {}

// ── SSG-раннер + CLI (W-14, W-16) ─────────────────────────────────────────────

class SsgResult {
  const SsgResult({required this.pagesWritten, required this.assetsCopied});
  final int pagesWritten;
  final bool assetsCopied; // true только при наличии IslandType.flutter
}

/// SSG1: ТРЕБУЕТ dart:ui → исполняется внутри flutter_tester-харнесса
/// (`flutter test --tags ssg`) или Flutter-скомпилированного executable
/// (AutomatedTestWidgetsFlutterBinding). НЕ запускается plain `dart run`.
abstract interface class SsgRunner {
  factory SsgRunner({
    required Object routeManifest,
    required RouteAdapter routeAdapter,
    required Map<String, IslandFactory> islandFactories,
  }) => throw UnimplementedError();

  /// SSG2: единственный ответственный за копирование island-бандла + web/-ассетов
  /// из build/web в dist (только если есть Flutter-острова, иначе шаг пропущен).
  /// SSG3: детерминированный вывод (стабильные пути/порядок).
  Future<SsgResult> run({required String outputDir /* dist/ */});
}

// CLI-энтрипоинт: `dart run hydraline_flutter:build` (инкапсулирует среду SSG1).

// ── DevTools (W-18, W-19) ─────────────────────────────────────────────────────

/// Оверлей: подсветка островов/директив/границ, диагностика гидрации,
/// warning'и anti-CLS (нет размеров) и props>10 KB (DS4).
class HydraDevtoolsOverlay extends StatelessWidget {
  const HydraDevtoolsOverlay({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// W-19/R6: сверка «SSG-HTML ↔ гидрированный DOM» (расхождение >5% → warning).
abstract final class HydrationDiagnostics {
  static Future<List<String>> diffSsgVsHydrated({required String ssgHtml, required Object liveDom}) =>
      throw UnimplementedError();
}
