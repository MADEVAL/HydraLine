# Hydraline — Руководство разработчика (Level 2)

| Поле | Значение |
|---|---|
| Статус | Draft к реализации |
| Базируется на | `HYDRALINE_SPEC_V3.md` v3.6, `ARCHITECTURE.md` (L1) |
| Назначение | Как настроить среду, писать, тестировать и мёржить код Hydraline |
| Среда | Windows 10/11 + WSL2 (Ubuntu) |
| Уровни обязательности | **ДОЛЖНО** / **СЛЕДУЕТ** / **МОЖЕТ** (RFC 2119) |

> Все инварианты (`I1..I10`, `D1`, `SER*`, `SRV*` и т.д.) — из `ARCHITECTURE.md`.
> Этот документ описывает **процесс**, а не архитектуру.

---

## 0. Навигация

- **§1** — Требования к среде
- **§2** — Топология репозитория (melos + pub workspaces)
- **§3** — Первичная настройка (bootstrap)
- **§4** — Ежедневный рабочий поток
- **§5** — Melos-скрипты (единый интерфейс команд)
- **§6** — Стратегия тестирования (пирамида + где что)
- **§7** — TDD-цикл на примере (red → green → refactor)
- **§8** — Кроссплатформенность Windows/WSL
- **§9** — CI-пайплайн и гейты
- **§10** — Git-конвенции, коммиты, версионирование, публикация
- **§11** — Definition of Done
- **§12** — Траблшутинг

---

## 1. Требования к среде

| Инструмент | Версия | Назначение |
|---|---|---|
| Dart SDK | ≥ 3.6 | pub workspaces, core/server |
| Flutter SDK | ≥ 3.22 (min), CI на min + latest stable (3.44) | `hydraline_flutter`, SSG |
| melos | ≥ 7 | управление monorepo |
| Git | ≥ 2.40 | + корректный `.gitattributes` |
| Node.js | LTS (≥ 20) | сборка/минификация JS-ассетов L1–L2, E2E |
| Playwright | latest | E2E-браузер (Chrome/Firefox/WebKit) |

**Платформы разработки (ДОЛЖНО):**
- Pure-Dart пакеты (`hydraline`, `hydraline_server`) — Windows **и** WSL/Linux.
- `hydraline_flutter` — обе ОС; E2E-браузер — Linux-контейнер CI, локально WSL.

**Проверка среды:**
```powershell
# PowerShell (Windows) и bash (WSL) — одинаково
dart --version        # >= 3.6
flutter --version     # >= 3.22
melos --version       # >= 7
```

---

## 2. Топология репозитория

```
hydraline/                        # корень monorepo
├── pubspec.yaml                  # pub workspace (workspace: [packages/*])
├── melos.yaml                    # melos-конфиг + скрипты §5
├── analysis_options.yaml         # общий строгий линт (наследуется пакетами)
├── .gitattributes                # eol=lf; goldens binary (R8)
├── .github/workflows/ci.yaml     # CI-матрица §9
├── ARCHITECTURE.md               # L1
├── DEVELOPMENT.md                # L2 (этот файл)
├── HYDRALINE_SPEC_V3.md          # ТЗ v3.6
├── packages/
│   ├── hydraline/                # core (pure Dart)
│   │   ├── lib/  test/  api/  example/
│   ├── hydraline_server/         # server (pure Dart)
│   │   ├── lib/  test/  api/  example/
│   └── hydraline_flutter/        # Flutter + web/
│       ├── lib/  test/  api/  example/  web/  integration_test/
├── e2e/                          # Playwright-сценарии (браузер)
├── spikes/                       # одноразовые прототипы (НЕ мёржатся в lib/)
└── tool/                         # вспомогательные скрипты (проверка границ и т.п.)
```

**Правила размещения:**
- `spikes/` — прототипы для снятия неопределённости; в продакшн **не** мёржатся,
  переписываются по TDD.
- `api/` в каждом пакете — L4-контракты (сигнатуры до реализации).
- Временные артефакты — в `TEMP/` (см. `AGENTS.md`), не в пакетах.

---

## 3. Первичная настройка (bootstrap)

```powershell
# 1. Установить melos глобально
dart pub global activate melos

# 2. Из корня репозитория — связать workspace
melos bootstrap        # алиас: melos bs

# 3. Проверить, что всё поднялось
melos run analyze
melos run test
```

**Инвариант BS1:** после `melos bootstrap` в CI и локально `melos run analyze`
проходит без ошибок на пустых скелетах (веха Phase 0).

---

## 4. Ежедневный рабочий поток

```
1. git pull → melos bootstrap (если менялись pubspec)
2. Взять задачу из PHASE_*_PLAN.md (L3), создать ветку feat/<id>-<slug>
3. Написать падающий тест (RED) — §7
4. Минимальная реализация (GREEN)
5. Рефакторинг (REFACTOR) при зелёных тестах
6. melos run precommit  (analyze + format-check + test)
7. Commit (Conventional Commits, §10)
8. Push → PR → CI-гейты §9 → ревью → merge
```

**Правило (ДОЛЖНО):** ни строки продакшн-логики без предшествующего падающего теста.

---

## 5. Melos-скрипты (единый интерфейс)

Все команды работают одинаково в PowerShell и bash. Определяются в `melos.yaml`.

| Скрипт | Что делает | Когда |
|---|---|---|
| `melos run analyze` | `dart analyze` во всех пакетах (строгий) | перед коммитом, CI |
| `melos run format` | `dart format .` (пишет) | локально |
| `melos run format:check` | `dart format --set-exit-if-changed` | CI-гейт |
| `melos run test` | unit/golden/property/widget во всех пакетах | постоянно |
| `melos run test:coverage` | тесты + lcov, проверка порога §6.4 | CI-гейт |
| `melos run test:golden` | только golden (с нормализацией CRLF) | при правках сериализатора |
| `melos run test:server` | integration-тесты сервера (вкл. инвариант I3) | Phase 2+ |
| `melos run e2e` | Playwright-сценарии (гидрация, CLS, sizing) | Phase 4 |
| `melos run boundaries` | скан запрещённых импортов (I1) | CI-гейт |
| `melos run audit` | CLI-аудит example-сайтов (SEO + A8) | Phase 1+ |
| `melos run precommit` | analyze + format:check + test + boundaries | локально/хук |

**Инвариант SC1:** `precommit` — надмножество локальных CI-гейтов; зелёный
`precommit` ⇒ высокая вероятность зелёного CI.

---

## 6. Стратегия тестирования

### 6.1 Пирамида

| Уровень | Пакет | Инструмент | Покрывает | Инвариант |
|---|---|---|---|---|
| Unit | core, server | `dart test` | модель, escaping, sitemap/robots, манифесты | N*, S* |
| Golden (HTML) | core | `dart test` + эталоны | детерминированный HTML | SER2, I4 |
| Property/fuzz | core | `dart test` (glados) | 0 XSS на 10^6 входов | S4, I2 |
| Widget | flutter | `flutter test` | двойная природа `Seo.*`, `IslandHost`/мультивью | CO3, I5 |
| Integration | server | `dart test` + shelf/Frog harness | статусы, кэш, стриминг, **A8** | SRV2, I3 |
| Build/SSG | flutter | `flutter test`/CLI e2e | `dist/`, sitemap, копирование ассетов | SSG1–SSG3 |
| E2E (браузер) | e2e | Playwright | гидрация, no-JS, CLS, sizing, zero-JS | I6–I8 |
| Audit | core | CLI | «что видит краулер», exit-code | I3 |

### 6.2 Golden-тесты (правила)
- Эталоны в `packages/hydraline/test/goldens/**`.
- Вывод сериализатора — всегда `\n` (SER5); при сравнении нормализовать вход.
- `.gitattributes`: `**/goldens/** binary` — git не трогает переносы.
- Обновление эталонов — только осознанно, с ревью diff.

### 6.3 Property/fuzz (безопасность)
- Библиотека: `glados` (генеративные) + собственный fuzz-раннер.
- Вход: юникод, escape-последовательности, OWASP XSS-векторы, случайные байты.
- Критерий: после `serialize → parse DOM → извлечь текст == исходный`, без исполнения
  скриптов (I2). Тег `@Tags(['security'])`, запуск `dart test --tags security`.

### 6.4 Пороги покрытия (блокирующие, I9)
- `hydraline`, `hydraline_server`: **≥ 90%** строк/веток.
- `hydraline_flutter`: **≥ 80%** (обоснованные исключения для JS-interop → покрыто E2E).
- Падение ниже порога → fail CI.

---

## 7. TDD-цикл на примере

Задача: `HeadingNode` (h1–h6) в `hydraline`.

**RED — падающий тест первым:**
```dart
// packages/hydraline/test/document_node/heading_node_test.dart
import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('HeadingNode', () {
    test('сериализуется в h2 с экранированным текстом', () {
      final node = HeadingNode(level: 2, children: [TextNode('A & <B>')]);
      final html = const HtmlSerializer().serialize(node);
      expect(html, '<h2>A &amp; &lt;B&gt;</h2>');   // I4 + S2
    });

    test('отвергает level вне 1..6', () {
      expect(() => HeadingNode(level: 7, children: const []),
             throwsA(isA<AssertionError>()));       // N-инвариант диапазона
    });
  });
}
```
```powershell
melos run test    # RED: HeadingNode ещё не существует
```

**GREEN — минимальная реализация:**
```dart
// packages/hydraline/lib/src/document_node/heading_node.dart
final class HeadingNode extends DocumentNode {
  const HeadingNode({required this.level, required this.children})
      : assert(level >= 1 && level <= 6);
  final int level;
  @override final List<DocumentNode> children;
}
```
```powershell
melos run test    # GREEN
```

**REFACTOR — при зелёных тестах:** вынести общий код визитора, добавить property-тест
на произвольный текст (I2), затем golden на реальный документ. Тесты остаются зелёными.

---

## 8. Кроссплатформенность Windows/WSL

**Инварианты (ДОЛЖНО, NF-8, R8):**
- **XP1.** Переносы строк: код и вывод — `\n`; `.gitattributes` `* text=auto eol=lf`.
- **XP2.** Пути — только через `package:path` (`path.posix` для сравнения); без
  хардкода `\`/`/`.
- **XP3.** Сравнения/сортировки — culture-invariant (без зависимости от локали).
- **XP4.** Golden-файлы — `binary` в `.gitattributes`.

**`.gitattributes` (корень):**
```gitattributes
* text=auto eol=lf
**/test/**/goldens/** binary
*.png binary
```

**Локальная проверка перед пушем на Windows:**
```powershell
git config core.autocrlf     # ожидаем: false или input, НЕ true
melos run test:golden        # предупредит при некорректном autocrlf
```

---

## 9. CI-пайплайн и гейты

### 9.1 Матрица

| Джоб | ОС | Flutter | Блокирующий? |
|---|---|---|---|
| core+server (Windows) | windows-latest | — | Да |
| core+server (Linux) | ubuntu-latest | — | Да |
| flutter min | ubuntu-latest | 3.22 | Да |
| flutter latest | ubuntu-latest | 3.44 | Да |
| flutter known-issue | ubuntu-latest | 3.41.x | **Нет** (informational) |
| e2e-браузер | ubuntu-latest (контейнер) | latest | Да (Phase 4+) |

### 9.2 Гейты (порядок в пайплайне)
```
1. boundaries      → I1  (запрещённые импорты) — fail fast
2. format:check    → форматирование
3. analyze         → 0 ошибок линта
4. test:coverage   → I9 (порог покрытия)
5. test:golden     → I4/I10 (на Windows + Linux)
6. security        → I2 (property/fuzz)
7. test:server     → I3 (A8: bytes(buffered)==bytes(concat(chunks)))
8. e2e             → I6/I7/I8 (zero-JS, sizing, CLS)
```

**Правило (ДОЛЖНО):** PR не мёржится при красном блокирующем джобе. Джоб 3.41
может быть красным (informational) — не блокирует, но фиксируется в отчёте.

### 9.3 Проверка границ (I1) — реализация Phase 0
`tool/check_boundaries.dart`: статически сканирует импорты `packages/hydraline/lib/**`
(запрет `flutter`/`dart:ui`/`dart:html`) и `packages/hydraline_server/lib/**`
(запрет `flutter`). Ненулевой exit-code → fail.

---

## 10. Git-конвенции

### 10.1 Ветки
`feat/<phase-id>-<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`.
Пример: `feat/p1-01-document-node`.

### 10.2 Conventional Commits (ДОЛЖНО)
```
<type>(<scope>): <summary>

type:  feat | fix | docs | test | refactor | perf | build | ci | chore
scope: core | server | flutter | web | ci | docs  (имя пакета/области)
```
Примеры:
```
feat(core): add HeadingNode with level assertion and golden test
fix(server): keep body bytes identical between buffered and chunked (I3)
test(core): property-based XSS fuzzing for escapeHtmlText (I2)
```

### 10.3 Версионирование и публикация
- SemVer; changelog автоген через `melos version` (Conventional Commits).
- Публикация: `melos publish --dry-run` в CI; реальный `publish` — вручную на релизе.
- Каждый пакет — pub.dev-готов (NF-11): `description`, `example/`, dartdoc публичного
  API, корректные `>=`-ограничения SDK/зависимостей, `CHANGELOG.md`, topics.
- Security-фикс: patch-версия ≤ 48 ч + advisory + регрессионный тест на вектор (NF-6).

---

## 11. Definition of Done (на фичу/задачу)

Задача считается завершённой, только если (ДОЛЖНО):
1. Есть design-note/ADR при нетривиальном решении.
2. Публичный API заморожен и задокументирован (dartdoc).
3. TDD-история видна (тесты предшествуют коду).
4. Покрытие ≥ порога (§6.4), CI зелёный на Windows и WSL/Linux.
5. `analyze` без ошибок, `format:check` проходит.
6. Границы зависимостей соблюдены (I1).
7. Обновлены `example/` и `CHANGELOG`-энтри.
8. Для UI/гидрации — E2E и devtools-аудит проходят.
9. Затронутые инварианты (`ARCHITECTURE.md §15`) покрыты тестом.

---

## 12. Траблшутинг

| Симптом | Причина | Решение |
|---|---|---|
| Golden падает на Windows, зелен на Linux | CRLF в checkout | `git config core.autocrlf false`; проверить `.gitattributes`; `melos run test:golden` |
| `dart run hydraline_flutter:build` падает с «dart:ui not found» | SSG требует flutter_tester (SSG1) | запускать через `flutter test --tags ssg` или Flutter-executable, не plain `dart` |
| CI boundaries fail | импорт `flutter`/`dart:ui` в core/server | убрать импорт; логику вынести в `hydraline_flutter` |
| Coverage-гейт красный | новый код без тестов | добавить тесты до порога §6.4 |
| Остров «прыгает» при гидрации (CLS) | не заданы px-размеры (I8) | задать `Island(size: ...)`; devtools-валидатор подсветит |
| canvas ≠ host на 3.41.x | регрессия #185034 (R1) | явные `viewConstraints`; 3.41 — informational-джоб |
| A8-инвариант красный | тело различается buffered/chunked (I3) | билдер должен быть UA-слепым (SRV1); чанки = сегментация того же потока |

---

*Level 2 завершён. Следующий шаг: L3 — `PHASE_0_PLAN.md` (декомпозиция Phase 0
на задачи с приёмкой), затем `PHASE_1_PLAN.md`. Изменения процесса — через
версионирование этого файла.*
