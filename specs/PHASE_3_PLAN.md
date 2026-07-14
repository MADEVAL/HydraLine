# Hydraline — Phase 3: Flutter widgets + extraction (L3)

| Поле | Значение |
|---|---|
| Цель | HTML из реального Flutter-дерева (поверхность A) + Dart-мультивью |
| Срок | 4–6 недель |
| Веха | Widget-тесты + мультивью зелёные; `DocumentNode` A↔B идентичен |
| Пакет | `hydraline_flutter` (Flutter) |
| Базис | `ARCHITECTURE.md` §11, спека W-1…W-7, ADR Q1/Q3 |
| Предусловия | Phase 1 gate (нужны collector, узлы, сериализатор) |

> Инварианты: CO2/CO3, IH1, I5. Извлечение — только в среде с `dart:ui` (SSG1, §6.3).

---

## Задачи

| ID | Задача | Зависит | Приёмка | Оценка |
|---|---|---|---|---|
| P3-01 | `HydraApp` + `HydraScope` (InheritedWidget с `SsgCollector`); не заменяет `MaterialApp` | P1-17 | W-3/CO2; widget-тест доступа к scope | 1.5 |
| P3-02 | `SsgSandbox`: заглушки `MediaQuery`/`Navigator`/`Directionality` для build-time | P3-01 | W-4/R2; извлечение не падает без ancestor-контекста | 1.5 |
| P3-03 | `Seo.*`-виджеты (двойная природа): text, image, link, heading, section, list, head/meta — регистрируют семантику в `build()` + рендерят визуал | P3-01 | W-1; widget-тест «визуал + регистрация» на каждый | 4 |
| P3-04 | `Island` виджет + enum'ы `IslandType`/`IslandRenderMode`/`IslandStyleMode`/`HydrationDirective` | P3-01,P1-06 | W-2; регистрация плейсхолдера при извлечении | 2 |
| P3-05 | `IslandHost` (`runWidget` + `ViewCollection` + `View`), мап `FlutterView→остров` по id | P3-04 | W-6/IH1; widget-тест мультивью (N views, 1 движок) | 3 |
| P3-06 | `lib/island_main.dart` entry-point + фабрики + per-island deferred (`deferred as`/`loadLibrary`) | P3-05 | W-7; сборка `--target` даёт island-бандл (без бизнес-логики) | 2 |
| P3-07 | First-class адаптер `go_router` (сверка `GoRoute`-дерева с манифестом) | P1-15 | W-5/Q3; предупреждение при расхождении | 2 |
| P3-08 | Интерфейс `RouteAdapter` + `Navigator2Adapter` (fallback) | P3-07 | W-5; auto_route best-effort через интерфейс | 2 |
| P3-09 | Golden-эквивалентность A↔B (виджеты → `DocumentNode` == pure-Dart билдер) | P3-03,P3-04 | **I5/CO3**; golden-сверка на репрезентативных страницах | 2 |
| P3-10 | Извлечение через `flutter_tester` (spike → TDD): `AutomatedTestWidgetsFlutterBinding` + `SsgCollector` | P3-02,P3-03 | Q1/R2; ≥90% узлов извлечено на эталоне; 100 прогонов стабильно | 3 |

**Итого: ~23 д (нижняя) — до ~30 д с spike-итерациями извлечения.**

---

## Выходной гейт фазы (ДОЛЖНО)
1. `Seo.*` дают тот же `DocumentNode`, что pure-Dart билдер (I5/CO3).
2. `IslandHost` рендерит N островов в N views на одной инстанции движка (IH1).
3. Извлечение стабильно: ≥90% узлов, 100 прогонов без деградации (R2-порог).
4. `go_router`-адаптер сверяет маршруты с манифестом.
5. island entry-point собирается отдельно от основного приложения (W-7).
6. Покрытие flutter ≥ 80% (I9; JS-interop → E2E в Phase 4).

## Приёмочные сценарии, покрываемые
- **A4** (аддитивность: `app`-приложение работает без изменений) — widget/integration.
- Подготовка A3 (hybrid-контент из виджетов) — E2E в Phase 4.

## Риски, затрагиваемые фазой
- **R2** (хрупкость извлечения) — P3-02/P3-10 + поверхность (B) как fallback.
- **R1** (sizing) — учитывается в контракте `IslandHost`, но E2E-проверка в Phase 4.

---

*Следующая фаза: `PHASE_4_PLAN.md` (Islands + SSG + DevTools).*
