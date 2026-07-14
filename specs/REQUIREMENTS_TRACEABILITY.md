# Hydraline — Матрица трассируемости требований

| Поле | Значение |
|---|---|
| Назначение | Доказать, что каждое требование спеки покрыто фазой/задачей и проверкой |
| Базис | `HYDRALINE_SPEC_V3.md` v3.6, `ARCHITECTURE.md`, `PHASE_*_PLAN.md` |
| Обозначения | `C-*` core, `S-*` server, `W-*` flutter, `NF-*` нефункц., `A*` приёмка, `R*` риски |
| Инварианты | из `ARCHITECTURE.md §15` (`I1..I10`) + локальные (`N*/S*/SER*/SRV*/CO*/DS*/IH1/SSG*/SM1/RM1/AS1/XP*`) |
| Правило | Каждая строка ДОЛЖНА иметь задачу и проверку. Пустая ячейка «Задача/Проверка» → пробел в плане. |

---

## 1. Core — `hydraline` (C-1…C-13)

| Треб. | Обяз. | Задача | Проверка / инвариант | Приёмка |
|---|---|---|---|---|
| C-1 DocumentNode (все узлы) | ДОЛЖНО | P1-01,03,04,05,06,07 | unit + golden; N1–N5 | A1,A7 |
| C-2 Метаданные (OG/Twitter/hreflang) | ДОЛЖНО | P1-11 | golden `<head>`; SEO-1,2,3,8 | A1,A2 |
| C-3 JSON-LD билдеры | ДОЛЖНО | P1-12 | golden `ld+json`; SEO-4 | A1,A2 |
| C-4 Сериализатор (3 режима) | ДОЛЖНО | P1-08,09,10 | golden; SER1–SER5, I4 | A1 |
| C-5 Escaping + URL-санитайз | ДОЛЖНО | P1-02 | property/fuzz; S1–S5, I2 | — |
| C-6 sitemap + robots (+split) | ДОЛЖНО | P1-13,14 | unit; SM1; SEO-5,6 | A5 |
| C-7 Island-манифест | ДОЛЖНО | P1-16 | property; DS1–DS4 | A3 |
| C-8 Route-манифест (YAML+Dart) | ДОЛЖНО | P1-15 | round-trip; RM1 | A5 |
| C-9 SsgCollector | ДОЛЖНО | P1-17 | unit; CO1–CO4 | — |
| C-10 SEO-валидаторы | СЛЕДУЕТ | P1-18 | unit; SEO-11 | A2 |
| C-11 CLI-аудит (2 режима) | ДОЛЖНО | P1-19,20 | CLI e2e; I3 (integr.) | A1,A2,A8 |
| C-12 Web-ассеты L0–L1 (standalone) | ДОЛЖНО | P1-22 | бюджет ≤8 KB; §13 | A3,A10 |
| C-13 Ноль зависимостей от Flutter | ДОЛЖНО | P0-05 | скан импортов; I1 | — |

## 2. Server — `hydraline_server` (S-1…S-11)

| Треб. | Обяз. | Задача | Проверка / инвариант | Приёмка |
|---|---|---|---|---|
| S-1 Middleware shelf + Dart Frog | ДОЛЖНО | P2-01,10 | integration | — |
| S-2 Маршрутизация + app-дефолты | ДОЛЖНО | P2-01,11 | unit; SRV4; §4.1 | A6 |
| S-3 Билдер контента (UA-слеп) | ДОЛЖНО | P2-02 | компиляц. запрет UA; SRV1 | A8 |
| S-4 Single-pass in-order streaming | ДОЛЖНО | P2-03 | порядок чанков; SRV3 | A1 |
| S-5 Bot-aware доставка + идентичность | ДОЛЖНО | P2-04 | SRV2, **I3** | **A8** |
| S-6 HTMX-хелперы | ДОЛЖНО | P2-07 | unit | A10 |
| S-7 HTTP-семантика | ДОЛЖНО | P2-05 | integration; SEO-9 | A6 |
| S-8 Кэширование | ДОЛЖНО | P2-06 | hit/miss/ETag | — |
| S-9 Отдача sitemap/robots + L0–L1 | ДОЛЖНО | P2-08 | content-type/кэш | A5 |
| S-10 Island-манифест + абс. пути | ДОЛЖНО | P2-09 | пути абсолютны на вложенных | — |
| S-11 Не исполнять Flutter-виджеты | НЕ ДОЛЖНО | P0-05 | скан импортов; I1 | — |

## 3. Flutter — `hydraline_flutter` (W-1…W-19)

| Треб. | Обяз. | Задача | Проверка / инвариант | Приёмка |
|---|---|---|---|---|
| W-1 Seo.* (двойная природа) | ДОЛЖНО | P3-03 | widget; CO2 | A4 |
| W-2 Island + оси | ДОЛЖНО | P3-04 | widget; DS1–DS5 | A3 |
| W-3 HydraApp/HydraScope | ДОЛЖНО | P3-01 | widget | A4 |
| W-4 SsgSandbox | ДОЛЖНО | P3-02 | извлечение без ancestor; R2 | — |
| W-5 go_router + RouteAdapter | ДОЛЖНО | P3-07,08 | сверка манифеста; Q3 | — |
| W-6 IslandHost/ViewCollection | ДОЛЖНО | P3-05 | мультивью; IH1 | A3 |
| W-7 Island entry-point + deferred | ДОЛЖНО | P3-06 | сборка `--target`; NF-4a | — |
| W-8 Custom Element (DSD, constraints, scoped) | ДОЛЖНО | P4-01,02,03 | E2E; I7, R1 | A3 |
| W-9 Диспетчер | ДОЛЖНО | P4-04 | E2E директив; §7.9 | A3 |
| W-10 Переиспользование vanilla | СЛЕДУЕТ | P4-05 | ссылка на core-бандл | A3 |
| W-11 Service Worker | ДОЛЖНО | P4-06 | тёплый TTI ~1с | — |
| W-12 Zero-overhead проверка | ДОЛЖНО | P4-14 | E2E; AS1, **I6** | **A9** |
| W-13 Virtual views | СЛЕДУЕТ | P4-13 | скролл-тест; R10 | — |
| W-14 SSG-раннер + копирование | ДОЛЖНО | P4-07 | SSG1–SSG3 | A3 |
| W-15 Динамические сегменты | ДОЛЖНО | P4-09 | N файлов из набора | A5 |
| W-16 CLI build | ДОЛЖНО | P4-08 | не plain `dart`; SSG1 | — |
| W-17 Совместимость с хостингами | ДОЛЖНО | P4-10 | docs + пример ×4 | — |
| W-18 DevTools-оверлей | ДОЛЖНО | P4-11 | dev-режим; DS4 | — |
| W-19 SSG↔DOM сверка | СЛЕДУЕТ | P4-12 | >5% → warning; R6 | — |

## 4. Нефункциональные (NF-1…NF-11)

| Треб. | Задача | Проверка / инвариант |
|---|---|---|
| NF-1 SSR median <50ms | P2-03 | бенч (PERFORMANCE.md) |
| NF-2 TTFB <100ms | P2-03 | бенч стриминга |
| NF-3 Core Web Vitals (LCP/CLS/TTI/Lighthouse≥70/skeleton<50KB) | P4-15 | Lighthouse CI; I8 |
| NF-4 JS-бюджеты (hard-cap) | P0-07, P4-* | bundle-size gate |
| NF-4a Бюджет бандла островов (≈450KB, +5% регресс) | P3-06, P4-07 | регресс-тест размера |
| NF-5 Матрица версий Flutter | P0-06,08 | CI min+latest; 3.41 info; Q7 |
| NF-6 Безопасность (48ч фикс) | P1-21 | I2; SECURITY.md |
| NF-7 a11y | P4-15 | axe/pa11y в E2E |
| NF-8 Кроссплатформа Win/WSL | P0-04 | XP1–XP4, R8, I10 |
| NF-9 Observability (логи, exit-codes) | P2-*, P1-19 | integration |
| NF-10 Версионирование (SemVer) | P0-09 | melos version |
| NF-11 Лицензия/публикация | P0-09 | `publish --dry-run` |

## 5. Приёмочные сценарии (A1…A10)

| # | Сценарий | Покрывающая фаза | Инвариант |
|---|---|---|---|
| A1 | Валидный HTML без JS (view-source) | P1-19 → P2 → P4-15 | I4 |
| A2 | OG/Twitter в исходнике | P1-19 | — |
| A3 | Hybrid: статика+vanilla мгновенно, Flutter по директиве, CLS≈0 | P4-15 | I8 |
| A4 | `app`-приложение без изменений | P3 | — |
| A5 | sitemap/robots валидны | P1-13,14 + P2-08 | SM1 |
| A6 | Статусы/редиректы/noindex | P2-05 | — |
| A7 | No-JS осмысленность | P4-15 | — |
| A8 | Идентичность тела бот↔юзер | P2-04,12 | **I3** |
| A9 | Нет островов → нет bootstrap | P4-14 | **I6** |
| A10 | HTMX-фрагмент без перезагрузки/движка | P2-07 + P4-15 | — |

## 6. Риски → митигация → проверка (R1…R10)

| # | Митигирующие задачи | Порог/проверка (§14.1) |
|---|---|---|
| R1 sizing #185034 | P4-02 | canvas−host ≤1px; I7; single-view fallback |
| R2 хрупкое извлечение | P3-02,10 | ≥90% узлов; 100 прогонов |
| R3 старт движка | P4-04,06 + §4.3 уровни | LCP<2.5, Lighthouse≥70, skeleton<50KB |
| R4 #187663 догонит | — (мониторинг) | ежекварт. обзор; O(N)-конверсия |
| R5 XSS | P1-02,07,21 | 0 XSS/10^6; I2 |
| R6 SSG↔hydrated | P4-12 | >5% → warning |
| R7 cloaking | P2-02,04,12 | I3; SRV1 |
| R8 CRLF/пути | P0-04 | 0 флейков/30дн; I10 |
| R9 сервер без Flutter | P0-05 + README | I1; 0 issues |
| R10 OffscreenCanvas | P4-13 | >лимита без virtual → warning |

## 7. Отклонённые идеи (закрыты осознанно, §16.2)

| Идея | Источник | Статус |
|---|---|---|
| Compile-time separation (кодоген) | Marko | Отклонено для MVP → post-MVP `@HydraPage` |
| `@HydraIsland` аннотация | Spark | Отклонено для MVP |
| Streaming Partials (навигация) | Fresh | Частично (HTMX §9); полное отклонено (NG1) |
| Template inheritance | Trellis | Отклонено (билдеры/виджеты) |
| Functional `html`-DSL | Enhance | Отклонено (P3 safety) |
| `adoptedStyleSheets` для scoped | Spark | Отклонено → CSS `@scope` |
| `prerender: true` флаг | Fresh | Отклонено → route-манифест YAML |

## 8. Post-MVP (§16.1, вне текущих фаз)

Server islands • Advanced streaming (out-of-order/DPU/fastest-first) • инкрементальная
SSG • расширенные таблицы (colspan/rowspan) • View Transitions • кодоген `@HydraPage`/`@HydraIsland`.

---

## 9. Итог покрытия

| Категория | Всего | Покрыто задачей | Покрыто проверкой |
|---|---|---|---|
| Core `C-*` | 13 | 13 | 13 |
| Server `S-*` | 11 | 11 | 11 |
| Flutter `W-*` | 19 | 19 | 19 |
| NF `NF-*` | 12 | 12 | 12 |
| Приёмка `A*` | 10 | 10 | 10 |
| Риски `R*` | 10 | 10 (R4 — мониторинг) | 10 |

**Вывод:** 100% требований спеки имеют задачу и проверку. Пробелов нет. При изменении
спеки/планов эта матрица обновляется первой (single source of coverage).
