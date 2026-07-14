# AGENTS.md — Hydraline

Hydraline: SEO/SSR/prerender + islands для Flutter Web. Dart/Flutter monorepo под
управлением **melos**. Полная спецификация и процесс — в `specs/`.

| Поле | Значение |
|---|---|
| Тип | Dart/Flutter monorepo (pub workspaces + melos) |
| Пакеты | `hydraline` (core, pure Dart) · `hydraline_server` (pure Dart) · `hydraline_flutter` |
| Языки | Dart ≥ 3.6 · Flutter ≥ 3.22 |
| Среда | Windows 10/11 + WSL2 (Ubuntu); shell по умолчанию — PowerShell |
| Источник истины | `specs/HYDRALINE_SPEC_V3.md` (продукт), `specs/ARCHITECTURE.md` (L1), `specs/DEVELOPMENT.md` (L2) |

> Пока код ещё не сгенерирован — в репозитории только `specs/`. По мере
> реализации `packages/*`, `melos.yaml`, `pubspec.yaml` появятся согласно
> `specs/DEVELOPMENT.md §2`.

## Команды (единый интерфейс через melos)

Все команды работают одинаково в PowerShell (Windows) и bash (WSL). Определяются
в `melos.yaml` (`specs/DEVELOPMENT.md §5`).

| Команда | Назначение |
|---|---|
| `dart pub global activate melos` | установить melos |
| `melos bootstrap` (`melos bs`) | связать workspace |
| `melos run analyze` | `dart analyze` во всех пакетах (строгий линт) |
| `melos run format` | `dart format .` (пишет) |
| `melos run format:check` | `dart format --set-exit-if-changed` (CI-гейт) |
| `melos run test` | unit/golden/property/widget-тесты |
| `melos run test:coverage` | тесты + lcov + проверка порога покрытия |
| `melos run test:golden` | только golden (с нормализацией CRLF) |
| `melos run test:server` | integration-тесты сервера (инвариант I3) |
| `melos run e2e` | Playwright-сценарии (Phase 4) |
| `melos run boundaries` | скан запрещённых импортов (I1) |
| `melos run audit` | CLI-аудит example-сайтов (SEO + A8) |
| `melos run precommit` | analyze + format:check + test + boundaries |

**Точечный запуск тестов Dart** (внутри пакета):
```powershell
dart test test/path/to/file_test.dart
dart test --tags security          # property/fuzz XSS-векторы (I2)
flutter test --tags ssg            # SSG-тесты (нужен flutter_tester)
```

## Верификация завершения (обязательно)

Перед любым заявлением о готовности запускай **свежий** `melos run precommit`
(или релевантный подмножество: `melos run analyze` + `melos run test`). Заявление
без вывода команды в этом сообщении = ложь. См. скил
`.opencode/skills/verification-before-completion.md`.

## Границы зависимостей (HARD, I1)

- `hydraline` (core): **запрещены** импорты `flutter`, `dart:ui`, `dart:html`.
- `hydraline_server`: **запрещён** импорт `flutter`.
- Flutter/`dart:ui`-логика живёт только в `hydraline_flutter`.
- Проверяется `melos run boundaries` (`tool/check_boundaries.dart`).

## Правила разработки

- **TDD обязателен:** ни строки продакшн-логики без предшествующего падающего
  теста (`specs/DEVELOPMENT.md §7`). См. скил `test-driven-development.md`.
- **Кроссплатформенность:** переносы строк `\n`; пути через `package:path`;
  сравнения culture-invariant; golden-файлы `binary` в `.gitattributes`
  (`specs/DEVELOPMENT.md §8`).
- **Покрытие (I9):** core/server ≥ 90%, flutter ≥ 80%.
- **Временные артефакты** — в `TEMP/`, прототипы — в `spikes/` (не мёржатся в `lib/`).
- **Комментарии** — только по необходимости; публичный API документируется dartdoc.

## Git-конвенции

- Ветки: `feat/<phase-id>-<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`.
- **Conventional Commits:** `type(scope): summary`
  (`type`: feat|fix|docs|test|refactor|perf|build|ci|chore;
  `scope`: core|server|flutter|web|ci|docs).
- Коммит/пуш/PR — только по явной просьбе пользователя.

## Definition of Done

Полный чек-лист — `specs/DEVELOPMENT.md §11`. Кратко: TDD-история видна, покрытие
≥ порога, `analyze`/`format:check` чисты, границы (I1) соблюдены, затронутые
инварианты (`specs/ARCHITECTURE.md §15`) покрыты тестом, обновлены `example/` и
`CHANGELOG`.
