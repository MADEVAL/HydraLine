# Contributing to Hydraline

Спасибо за интерес! Этот документ описывает процесс вклада. Он опирается на
`DEVELOPMENT.md` (процесс) и `ARCHITECTURE.md` (границы) — прочтите их перед PR.

---

## 1. Прежде чем начать

- Прочтите `README.md` — особенно блок «SSR ≠ Flutter-виджеты на сервере» (R9).
- Ознакомьтесь с `ARCHITECTURE.md §15` (инварианты) и `DEVELOPMENT.md` (среда, тесты, CI).
- Для новой фичи — сверьтесь с `HYDRALINE_SPEC_V3.md` и `REQUIREMENTS_TRACEABILITY.md`:
  вклад не должен нарушать не-цели (§2.2 спеки) и обязан иметь проверку.

## 2. Настройка среды

```powershell
dart pub global activate melos
melos bootstrap
melos run precommit
```
Требования: Dart ≥ 3.6, Flutter ≥ 3.22, melos ≥ 7, Node LTS (для JS-ассетов/E2E).
Работает на Windows и WSL/Linux (см. `DEVELOPMENT.md §8`).

## 3. Рабочий процесс

1. Issue: опишите задачу/баг (шаблоны в `.github/ISSUE_TEMPLATE/`).
2. Ветка: `feat/<phase-id>-<slug>` | `fix/<slug>` | `docs/<slug>` | `chore/<slug>`.
3. **TDD (обязательно):** сначала падающий тест, затем реализация (`DEVELOPMENT.md §7`).
4. Локально зелёный `melos run precommit`.
5. PR по шаблону; свяжите с issue; опишите затронутые инварианты.

## 4. Требования к PR (Definition of Done)

PR не будет смёржен, пока не выполнено (`DEVELOPMENT.md §11`):

- [ ] Тесты предшествуют коду (TDD видно в истории).
- [ ] Покрытие ≥ порога: core/server ≥ 90%, flutter ≥ 80% (`I9`).
- [ ] `melos run analyze` без ошибок; `format:check` проходит.
- [ ] Границы зависимостей соблюдены: core/server без Flutter (`I1`).
- [ ] Затронутые инварианты (`ARCHITECTURE.md §15`) покрыты тестом.
- [ ] Обновлены `example/`, dartdoc публичного API, `CHANGELOG`-энтри.
- [ ] Для UI/гидрации — E2E и devtools-аудит проходят.
- [ ] CI зелёный на Windows и WSL/Linux (джоб 3.41.x — informational).

## 5. Стиль кода и коммитов

- **Conventional Commits:** `type(scope): summary`
  (`type`: feat|fix|docs|test|refactor|perf|build|ci|chore; `scope`: core|server|flutter|web|ci|docs).
- `dart format` обязателен; строгий `analysis_options`.
- Без комментариев ради комментариев; публичный API — dartdoc.
- Изменение публичного API = обновить контракт в `packages/*/api/` и, при необходимости,
  `ARCHITECTURE.md`.

## 6. Архитектурные решения (ADR)

Нетривиальное решение фиксируется как ADR в `docs/adr/` по шаблону
`docs/adr/TEMPLATE.md`. Изменение существующего решения — новый ADR со ссылкой
«Supersedes ADR-XXXX».

## 7. Безопасность

**Не** открывайте публичный issue для уязвимостей — см. `SECURITY.md` (приватный
GitHub Security Advisory). XSS-регрессии сопровождаются тестом на вектор.

## 8. Что не принимается

- Нарушение не-целей спеки (фреймворк, автоконвертация виджетов, cloaking, C/C++/FFI).
- Импорт `flutter`/`dart:ui` в `hydraline`/`hydraline_server`.
- Код без тестов или снижающий покрытие ниже порога.
- Обход `SafeUrl`/экранирования вне `UnsafeHtmlNode`.

## 9. Лицензия вклада

Отправляя PR, вы соглашаетесь на распространение вклада под лицензией **MIT**.

---

*Спасибо за вклад в Hydraline!*
