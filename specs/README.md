# Hydraline

**SEO / SSR / prerender + islands для Flutter Web.** Настоящий семантический HTML
в первом HTTP-ответе + гидрация интерактивных зон (островов) поверх — **без
переписывания приложения и без нового фреймворка**.

| | |
|---|---|
| Статус | В разработке (pre-MVP; см. дорожную карту) |
| Пакеты | `hydraline` · `hydraline_server` · `hydraline_flutter` |
| Платформа | Flutter Web (CanvasKit/Skwasm) + Dart-серверы (shelf / Dart Frog) |
| Лицензия | MIT |
| Dart/Flutter | Dart ≥ 3.6 · Flutter ≥ 3.22 |

---

> ## ⚠️ Прочтите первым: Hydraline **не исполняет Flutter-виджеты на сервере**
>
> **SSR в Hydraline рендерит HTML из pure-Dart `DocumentNode`-билдеров, а не из
> Flutter-виджетов.** Flutter-виджеты работают:
> - в **SSG** (build-time, есть `dart:ui`) — поверхность (A);
> - в **браузере** (runtime islands) — гидрация поверх HTML.
>
> На «голом» Dart-сервере (shelf/Dart Frog) `dart:ui` отсутствует, поэтому для
> динамического SSR используйте **pure-Dart `DocumentNode` builder** (поверхность B).
> Это не ограничение, а корректная модель — см. `ARCHITECTURE.md §3` и `HYDRALINE_SPEC_V3.md §6.3`.

---

## Проблема

Flutter Web рендерит UI в `<canvas>`. Первый HTTP-ответ — пустой app-shell.
Соц-краулеры (Facebook, X, Telegram, WhatsApp, LinkedIn, Slack, Discord) **не
исполняют JS** → превью не строится; поисковики индексируют хуже. Существующие
пакеты делают runtime DOM-инъекцию — тегов **нет** в `view-source`.

## Решение

1. **Настоящий HTML в первом ответе** для `document`/`hybrid`-маршрутов —
   доступен в `view-source`, без JS.
2. **Flutter гидрирует острова поверх** через multi-view API — статический контент
   не перерисовывается.
3. **Три уровня интерактивности** — движок Flutter грузится только когда реально нужен:

```
Уровень 0  Статический HTML            FCP <100ms, без JS
Уровень 1  Vanilla (~8KB) + HTMX (~14KB)  TTI ~50ms, без Flutter
Уровень 2  Flutter-острова (CanvasKit)    движок по триггеру острова
```

## Режимы маршрута (пер-маршрут, сосуществуют)

| Режим | Владелец контента | Для чего |
|---|---|---|
| `app` | CanvasKit (как сейчас) | дашборды, редакторы, приватные экраны |
| `document` | семантический HTML | блог, docs, лендинги, карточки |
| `hybrid` | HTML + Flutter-острова | товар с калькулятором, статья с виджетом |

## Никакого cloaking

Боту и пользователю — **побайтово идентичное тело** документа. Отличается только
транспорт: buffered (боты) vs chunked-streaming (люди). Билдер контента **UA-слеп**
(API не принимает User-Agent). Инвариант проверяется в CI (`I3`/`A8`).

---

## Карта документации

**Спецификация**
- `HYDRALINE_SPEC_V3.md` — **итоговое ТЗ v3.6** (единственный источник истины по продукту)

**Инженерная документация**
- `ARCHITECTURE.md` — **L1**: компоненты, контракты, инварианты, потоки данных
- `packages/*/api/` — **L4**: замороженные API-контракты + `JS_RUNTIME_CONTRACT.md`

**Качество и трассируемость**
- `REQUIREMENTS_TRACEABILITY.md` — покрытие всех требований
- `ACCEPTANCE_TESTS.md` — сценарии A1–A10
- `PERFORMANCE.md` — бюджеты и их измерение
- `SECURITY.md` — модель угроз и политика раскрытия
- `EXAMPLES.md` — 4 эталонных примера (они же E2E-фикстуры)

## С чего начать разработчику Hydraline

```powershell
dart pub global activate melos
melos bootstrap
melos run test          # все тесты
```

## Дорожная карта

| Фаза | Содержание | Срок |
|---|---|---|
| 0 | Monorepo, CI, границы зависимостей | 1–2 нед |
| 1 | Core: модель, сериализатор, escaping, SEO-артефакты | 5–7 нед |
| 2 | Server: SSR, HTMX, bot-aware доставка | 3–5 нед |
| 3 | Flutter: виджеты, извлечение, IslandHost | 4–6 нед |
| 4 | Острова, SSG, devtools, E2E | 5–7 нед |

**MVP: 18–27 недель.** Детали — `HYDRALINE_SPEC_V3.md §16`.

## Что Hydraline НЕ делает (границы)

Не фреймворк · не владеет `main()` · не конвертирует произвольные виджеты в HTML ·
не cloaking · не ORM/CMS · не исполняет Flutter-виджеты на сервере · не возрождает
HTML-renderer.

---

*Обратная связь и баги — через issues. Лицензия — MIT.*
