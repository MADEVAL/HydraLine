// Hydraline — API-контракт (L4) · packages/hydraline_server/api/server.dart
//
// SSR/HTMX/bot-aware доставка. Реализация — PHASE_2 (P2-01…P2-12).
// ARCHITECTURE.md §10. Инварианты: SRV1 (билдер UA-слеп), SRV2/I3 (идентичность
// тела), SRV3 (in-order), SRV4 (app-дефолты). Пакет НЕ импортирует flutter (I1).
//
// ignore_for_file: unused_element

// Псевдо-импорты контракта (реальные: package:shelf, package:hydraline/*).
import 'dart:async';

typedef Request = Object; // shelf.Request
typedef Response = Object; // shelf.Response
typedef Handler = FutureOr<Response> Function(Request request);
typedef Middleware = Handler Function(Handler inner);

typedef DocumentNode = Object; // hydraline.DocumentNode
typedef RouteManifest = Object; // hydraline.RouteManifest

// ── Билдер контента (SRV1: сигнатура БЕЗ User-Agent) ──────────────────────────

/// Точка расширения для динамических маршрутов. Компиляционно не получает UA →
/// архитектурный запрет cloaking (R7). `data` — данные из БД/API разработчика.
typedef DocumentBuilder = FutureOr<DocumentNode> Function(Request request, Object? data);

// ── Middleware / handler (S-1, S-2) ────────────────────────────────────────────

class HydralineConfig {
  const HydralineConfig({
    required this.manifest,
    this.builders = const {}, // path → DocumentBuilder (поверхность B)
    this.cache,
    this.botUserAgentPattern, // для выбора доставки (не контента!)
  });
  final RouteManifest manifest;
  final Map<String, DocumentBuilder> builders;
  final HydralineCache? cache;
  final Pattern? botUserAgentPattern;
}

/// shelf-middleware. Матч по манифесту: document/hybrid → рендер; app → shell.
Middleware hydralineMiddleware(HydralineConfig config) => throw UnimplementedError();

/// Адаптер Dart Frog поверх той же логики (S-1).
abstract final class DartFrogAdapter {
  static Handler middleware(HydralineConfig config) => throw UnimplementedError();
}

// ── Доставка (S-4/S-5, SRV2/SRV3, I3) ─────────────────────────────────────────

enum DeliveryMode { buffered, chunked }

/// Двухслойность §6.5: контент (UA-слеп) отделён от транспорта (может читать UA).
/// Инвариант I3: `bytes(buffered) == bytes(concat(chunks))` на детерм. входе.
abstract interface class ResponseDelivery {
  /// Боты: весь HTML сразу (Content-Length).
  Response buffered(DocumentNode root, {int status = 200, Map<String, String> headers});

  /// Юзеры: тот же поток чанками (Transfer-Encoding: chunked), in-order flush.
  Response chunked(DocumentNode root, {int status = 200, Map<String, String> headers});
}

// ── HTTP-семантика (S-7) ───────────────────────────────────────────────────────

abstract final class Http {
  static Response redirect(String location, {int status = 301}) => throw UnimplementedError();
  static Response notFound({DocumentNode? body}) => throw UnimplementedError(); // 404
  static Response gone() => throw UnimplementedError(); // 410
  static Response withRobots(Response base, {bool noindex = false, bool nofollow = false}) =>
      throw UnimplementedError(); // X-Robots-Tag
  static String canonicalizePath(String path) => throw UnimplementedError(); // без hash
}

// ── HTMX-хелперы (S-6) ───────────────────────────────────────────────────────

class HtmxTrigger {
  const HtmxTrigger(this.value); // напр. 'load', 'click', 'revealed'
  final String value;
}

abstract final class Htmx {
  /// Фрагмент без <html>/<head> (serializeFragment).
  static Response renderFragment(DocumentNode fragment, {int status = 200}) =>
      throw UnimplementedError();
}

class HtmxResponse {
  const HtmxResponse({required this.body, this.trigger, this.retarget, this.reswap});
  final DocumentNode body;
  final HtmxTrigger? trigger; // HX-Trigger
  final String? retarget; // HX-Retarget
  final String? reswap; // HX-Reswap
}

// ── Кэш (S-8) ────────────────────────────────────────────────────────────────

abstract interface class HydralineCache {
  Future<String?> get(String key);
  Future<void> set(String key, String html, {Duration? ttl, String? etag});
}

// ── Ассеты (S-9, S-10) ───────────────────────────────────────────────────────

abstract final class Assets {
  /// Отдача sitemap/robots + L0–L1 core-ассетов (vanilla, self-hosted HTMX). S-9.
  static Handler serveCoreAssets() => throw UnimplementedError();

  /// Встраивание island-манифеста + АБСОЛЮТНЫХ путей к движку (S-10):
  /// `/flutter_bootstrap.js`, `/main.dart.js`, `/canvaskit/` или через <base href>.
  /// Только для маршрутов с IslandType.flutter.
  static DocumentNode injectFlutterAssets(DocumentNode root, {String baseHref = '/'}) =>
      throw UnimplementedError();
}
