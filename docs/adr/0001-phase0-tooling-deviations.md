# ADR-0001: Отклонения инструментовки Phase 0 (melos 8 + pub workspaces, CI, формат)

- **Статус:** Accepted
- **Дата:** 2026-07-14
- **Контекст фазы:** Phase 0
- **Связано:** `DEVELOPMENT.md §1/§2/§5/§9`, `PHASE_0_PLAN.md` (P0-02/P0-06), инвариант I1

## Контекст

`DEVELOPMENT.md` (L2) писался в расчёте на melos ≤ 6 (отдельный `melos.yaml`) и
матрицу CI, где джобы core/server не имеют Flutter. При реализации выяснилось:

1. Требование `melos ≥ 7` в связке с Dart pub workspaces приводит к melos 8, где
   конфигурация (в т.ч. `scripts`) читается из корневого `pubspec.yaml` (ключ
   `melos:`), а standalone `melos.yaml` со скриптами не подхватывается.
2. Единый pub workspace включает Flutter-пакет (`hydraline_flutter`), поэтому
   `dart pub get` в корне на «чисто-Dart» раннере без Flutter SDK не резолвится.
3. `dart format .` заходит в `specs/packages/**/api/*.dart` — замороженные L4-контракты
   (источник истины), переформатирование которых нежелательно.
4. melos-скрипты со связкой `exec` + `packageFilters` в неинтерактивном шелле
   вызывают package-selection prompt и падают (`StdinException`).

## Рассмотренные варианты

1. **Понизить melos до 6 / держать `melos.yaml`** — нарушает требование `≥ 7`
   (`AGENTS.md`, `DEVELOPMENT §1`).
2. **Разнести пакеты по отдельным резолюциям (без единого workspace)** — теряется
   смысл pub workspaces и усложняется bootstrap.
3. **Адаптировать инструментовку под реальность melos 8 + pub workspaces**,
   сохранив намерение спецификации (единый интерфейс команд §5, матрица §9, I1).

## Решение

Принят вариант 3:

- **Конфиг melos — в корневом `pubspec.yaml`** (`melos:` секция); `melos.yaml`
  не используется. Набор скриптов §5 сохранён 1:1.
- **CI ставит Flutter на всех джобах** (Flutter включает Dart) ради резолва
  workspace. «Чистота» core/server (отсутствие `flutter`/`dart:ui`/`dart:html`)
  гарантируется статическим гейтом **I1** (`melos run boundaries`,
  `tool/check_boundaries.dart`), а не отсутствием Flutter на раннере. Кросс-ОС
  матрица (Windows/Linux) для core/server сохранена (R8/I10).
- **`format`/`format:check` ограничены каталогами `packages tool test`**; `specs/`
  исключён, чтобы не трогать замороженные контракты.
- **Скрипты используют форму `run: melos exec <filters> -- <cmd>`** вместо
  `exec` + `packageFilters`, что устраняет интерактивный prompt (работает в CI и
  локально в неинтерактивном шелле).

## Последствия

- **Плюсы:** совместимость с актуальным melos; единый bootstrap `dart pub get`;
  I1 форсируется компиляционно-статически; стабильные скрипты без prompt.
- **Минусы / компромиссы:** core/server-джобы формально имеют Flutter в окружении
  (митигируется гейтом I1); `DEVELOPMENT.md` следует обновить под melos 8
  (задача update-docs).
- **Влияние на инварианты:** I1 усилен как основная гарантия границ; I9/I10 без
  изменений.

## Проверка

- `melos run boundaries` (I1) — негативный тест в `test/check_boundaries_test.dart`.
- `melos run precommit` зелёный локально (analyze + format:check + test + boundaries).
- CI-матрица `.github/workflows/ci.yaml` (проверяется после первого push).
