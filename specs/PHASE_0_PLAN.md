# Hydraline — Phase 0: Foundation (L3)

| Поле | Значение |
|---|---|
| Цель | Рабочий monorepo с зелёным CI на пустых скелетах |
| Срок | 1–2 недели |
| Веха | CI зелёный на 3 пустых пакетах; границы зависимостей форсируются |
| Пакеты | все (скелеты) |
| Базис | `ARCHITECTURE.md` §2/§3/§15, `DEVELOPMENT.md` §2/§5/§9 |
| Предусловия | нет (стартовая фаза) |

> Формат задачи: `ID | задача | пакет | зависит | приёмка | оценка`.
> Оценки в рабочих днях (д). Инварианты — из `ARCHITECTURE.md §15`.

---

## Задачи

| ID | Задача | Пакет | Зависит | Приёмка | Оценка |
|---|---|---|---|---|---|
| P0-01 | Monorepo-скелет: корневой `pubspec.yaml` (pub workspace), `packages/{hydraline,hydraline_server,hydraline_flutter}` с `lib/`,`test/`,`api/`,`example/` | все | — | `dart pub get` в корне поднимает workspace; `melos list` показывает 3 пакета | 1 |
| P0-02 | `melos.yaml` + скрипты §5 (`analyze`,`format`,`format:check`,`test`,`test:coverage`,`test:golden`,`boundaries`,`precommit`) | инфра | P0-01 | все скрипты запускаются (пусть на пустом) без ошибок конфигурации | 1 |
| P0-03 | Общий `analysis_options.yaml` (строгий), наследуется пакетами | инфра | P0-01 | `melos run analyze` = 0 ошибок на скелетах | 0.5 |
| P0-04 | `.gitattributes` (`* text=auto eol=lf`, `**/goldens/** binary`) + проверка `core.autocrlf` | инфра | — | R8/XP1–XP4: файл в корне; тестовый golden не флейкует между ОС | 0.5 |
| P0-05 | `tool/check_boundaries.dart` — скан запрещённых импортов (core: нет `flutter`/`dart:ui`/`dart:html`; server: нет `flutter`) | инфра | P0-01 | I1: возвращает exit≠0 при внедрённом нарушении (негативный тест) | 1 |
| P0-06 | CI-workflow `.github/workflows/ci.yaml`: матрица §9.1 (core/server × Win/Linux; flutter min 3.22 + latest 3.44; 3.41 informational) | инфра | P0-02,P0-05 | все блокирующие джобы зелёные; 3.41 — non-blocking | 1.5 |
| P0-07 | Гейт покрытия: `test:coverage` + порог (core/server ≥90%, flutter ≥80%) в CI | инфра | P0-02,P0-06 | I9: искусственное падение покрытия → fail | 0.5 |
| P0-08 | Политика версий Flutter: `>=3.22.0` в `hydraline_flutter/pubspec.yaml`; banner про 3.41 в README | flutter | P0-01 | Q7/NF-5: pubspec-констрейнт корректен; документировано | 0.5 |
| P0-09 | pub.dev-скелет каждого пакета: `description`, `CHANGELOG.md`, `LICENSE` (MIT), topics, пустой `example/` | все | P0-01 | NF-11: `dart pub publish --dry-run` без критических warning'ов | 0.5 |
| P0-10 | ADR-шаблон + `docs/adr/` + первый ADR-0000 (структура репо) | docs | P0-01 | DoD-1: шаблон принят, ADR-0000 замёржен | 0.5 |

**Итого: ~7.5 д (нижняя) — до ~10 д с буфером на настройку CI-раннеров.**

---

## Выходной гейт фазы (ДОЛЖНО)

1. `melos run precommit` зелёный локально (Windows + WSL).
2. CI зелёный на всех блокирующих джобах (BS1).
3. Инвариант I1 форсируется (негативный тест проходит).
4. Гейт покрытия I9 подключён и срабатывает.
5. ADR-0000 замёржен; шаблон ADR доступен.

## Риски, затрагиваемые фазой
- **R8** (CRLF/пути) — закрывается P0-04 на старте.
- **R9** (сервер без Flutter) — форсируется P0-05 (компиляционно-ранняя защита).

## Приёмочные сценарии — не в этой фазе
A1–A10 появляются с Phase 1+ (нужен реальный вывод).

---

*Следующая фаза: `PHASE_1_PLAN.md` (Core).*
