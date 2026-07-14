# Hydraline — Эталонные примеры (Reference Examples)

| Поле | Значение |
|---|---|
| Назначение | 4 эталонных приложения: демонстрация + **E2E-фикстуры** + материал adoption |
| Базис | `HYDRALINE_SPEC_V3.md` §17 (A1–A10) |
| Размещение | `packages/hydraline_flutter/example/<name>/` (+ серверные — `packages/hydraline_server/example/`) |
| Двойная роль | Каждый пример покрывает конкретные приёмочные сценарии и режимы |

> Примеры — не «витрина», а **исполняемые фикстуры**: на них гоняются E2E (P4-15),
> аудит (C-11) и Lighthouse CI (NF-3). Каждый пример = минимально достаточный,
> детерминированный, деплоится на статик-хостинг.

---

## Матрица покрытия примерами

| Пример | Режимы | Уровни | Доставка | Покрывает A* |
|---|---|---|---|---|
| 1. Blog | document | 0 | SSG | A1,A2,A5,A7 |
| 2. Docs | document | 0,1 (vanilla) | SSG | A1,A5,A7,A9 |
| 3. Landing | document/hybrid | 0,1 (vanilla+HTMX) | SSG + SSR-фрагменты | A1,A3,A10 |
| 4. Product | hybrid | 0,1,2 (Flutter-остров) | SSR (streaming) | A1,A3,A4,A6,A8,A9,A10 |

---

## 1. Blog (SSG, чистый document)

**Цель:** доказать базовый SEO без Flutter-движка на странице.

- Маршруты: `/`, `/blog/:slug` (динамические сегменты), `/about`.
- Контент: заголовки, параграфы, изображения с `alt`, ссылки, `<time>`, JSON-LD `Article`.
- Метаданные: title/description/canonical, OG, Twitter, hreflang (ru/en).
- Артефакты: `sitemap.xml` (с автосплитом на синтетическом наборе >50k — отдельный тест),
  `robots.txt`.
- **E2E:** `view-source` содержит все теги без JS (A1); OG строится симулятором бота (A2);
  sitemap валиден (A5); навигация без JS (A7).
- **Без Flutter:** `flutter_bootstrap.js` не подключается (проверка zero-overhead).

## 2. Docs (SSG + vanilla-острова)

**Цель:** уровень 1 без Flutter — интерактив на ~8 KB JS.

- Маршруты: `/docs/:section/:page`.
- Острова (vanilla): `accordion` (на `<details>`), `tabs` (`:target`-fallback),
  `copy-button` (копирование кода), `theme` (переключатель темы).
- No-JS fallback у каждого острова (см. `JS_RUNTIME_CONTRACT.md §3`).
- **E2E:** vanilla-острова оживают на `DOMContentLoaded`; без JS страница осмысленна (A7);
  Flutter-движок не грузится (A9); аккордеон работает как `<details>` без JS.

## 3. Landing (hybrid, vanilla + HTMX)

**Цель:** серверные HTML-фрагменты без клиентского роутера и без Flutter.

- Маршруты: `/` (лендинг), эндпоинт `/api/lead` (HTMX-форма), `/api/faq` (ленивая подгрузка).
- Острова: HTMX-форма подписки (`hx-post`), HTMX-FAQ (`hx-get`, `hx-trigger=revealed`),
  vanilla-carousel.
- Сервер: `serializeFragment()` возвращает фрагменты; HTMX-скрипт self-hosted.
- **E2E:** HTMX-остров заменяет DOM без перезагрузки и без движка (A10); hybrid-статика
  видна сразу, CLS≈0 (A3).

## 4. Product (hybrid, Flutter-остров) — флагманский

**Цель:** полный стек: SSR streaming + Flutter-остров + bot-aware доставка.

- Маршруты: `/product/:id` (SSR, per-request данные), `/api/reviews/:id` (HTMX).
- Контент (document, поверхность B — pure-Dart builder): заголовок, описание, цена,
  характеристики (таблица), JSON-LD `Product`+`BreadcrumbList`+`Review`.
- Острова:
  - Flutter `calculator` (`hydrateOnVisible`, `renderMode: ssr`, `data-state` с ценой) —
    рассрочка/конфигуратор;
  - HTMX `reviews` (`hx-trigger=load`);
  - vanilla `gallery-carousel`.
- Сервер: streaming in-order (shell→статика→острова); bot-aware (buffered боту, chunked юзеру).
- Сборка: island entry-point (`--target=lib/island_main.dart`), deferred-чанк калькулятора,
  Service Worker.
- **E2E (полный набор):** валидный HTML без JS (A1); hybrid + CLS≈0 (A3); базовое
  `app`-приложение рядом работает без изменений (A4); статусы/редиректы/noindex (A6);
  **идентичность тела бот↔юзер (A8/I3)**; страница без островов не грузит bootstrap (A9);
  HTMX-фрагмент (A10); sizing canvas−host ≤1px (I7); a11y островов (axe/pa11y, NF-7).

---

## Общие требования к примерам (ДОЛЖНО)

- **Детерминизм:** фиксированные данные (без `DateTime.now()`/random в рендере, DS3),
  чтобы golden/аудит были стабильны.
- **Хостинг-рецепты:** каждый деплоится минимум на 2 из {Firebase, Netlify, Cloudflare
  Pages, GitHub Pages} с rewrite/fallback (W-17).
- **CI:** примеры собираются и прогоняются в E2E-джобе (P4-15); аудит (C-11) даёт exit 0.
- **Документируют паттерн:** каждый — с кратким README «что демонстрирует и почему так».

## Трассируемость примеров → фазы

| Пример | Готов к сборке после | E2E-задача |
|---|---|---|
| Blog | Phase 1 (core) + Phase 4 (SSG-раннер) | P4-15 |
| Docs | + vanilla islands (P4-05) | P4-15 |
| Landing | + Phase 2 (HTMX) | P4-15 |
| Product | + Phase 2 (streaming/bot-aware) + Phase 3/4 (Flutter-остров) | P4-15 |

---

*Примеры — часть Definition of Done продукта (NF-11: `example/` обязателен). Изменение
контракта примеров синхронизируется с `ACCEPTANCE_TESTS.md`.*
