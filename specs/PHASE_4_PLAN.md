# Hydraline — Phase 4: Islands + SSG + DevTools (L3)

| Поле | Значение |
|---|---|
| Цель | Полный hybrid-маршрут: HTML + vanilla-острова + Flutter-острова |
| Срок | 5–7 недель |
| Веха | E2E зелёные (гидрация, no-JS, CLS, sizing, zero-JS, a11y); самодостаточный `dist/` |
| Пакет | `hydraline_flutter` (JS-рантайм + SSG + devtools) |
| Базис | `ARCHITECTURE.md` §11–§14, спека W-8…W-19, §7 |
| Предусловия | Phase 2 gate (доставка) + Phase 3 gate (виджеты/IslandHost) |

> Инварианты: AS1, SSG1–SSG3, I6/I7/I8. Приёмка — A3/A9/A10 + весь E2E-набор.

---

## Задачи

| ID | Задача | Зависит | Приёмка | Оценка |
|---|---|---|---|---|
| P4-01 | Custom Element `<hydraline-island>` с Declarative Shadow DOM (использует существующий Shadow Root, без FOUC) | P3-05 | W-8; e2e: остров рендерит DSD-скелетон без JS | 3 |
| P4-02 | `viewConstraints` (фикс. px, `min==max`) + `ResizeObserver`-корректор (rAF-коалесинг, debounce, no-op на 3.41.x) | P4-01 | W-8/R1/**I7**: `canvas−host ≤1px` на ≥3 островах в Chrome/FF/WebKit | 2.5 |
| P4-03 | `scoped`-режим стилей (стили 1× в `<head>`, scope-атрибут) для массовых островов | P4-01 | §7.6; e2e: N одинаковых островов без дублей стилей | 2 |
| P4-04 | Диспетчер (Qwikloader-style, ≤2 KB): все директивы, 1×IO/1×idle/делегирование, `window.hydraline.*`, состояния `data-hydration`, тайм-аут/retry/`island-error` | P4-01 | W-9/§7.2/§7.9; e2e на каждую директиву + сбой-сценарий | 4 |
| P4-05 | Переиспользование vanilla islands из core (не дублировать JS) | P1-22 | W-10/§13; ссылка на core-бандл, не копия | 1 |
| P4-06 | Service Worker (≤2 KB) + WASM streaming + `<link rel="preload">`/modulepreload | P4-04 | W-11; тёплый визит TTI ~1с (замер) | 2 |
| P4-07 | SSG-раннер: обход манифеста → извлечение (flutter_tester) → запись `dist/` (`**.html`,sitemap,robots,манифесты) + **копирование** island-бандла и `web/`-ассетов | P3-10,P4-01 | W-14/**SSG1–SSG3**; детерминированный `dist/`; копирование только при `IslandType.flutter` | 4 |
| P4-08 | SSG CLI `dart run hydraline_flutter:build` (инкапсулирует flutter_tester-среду) | P4-07 | W-16/SSG1; запуск не через plain `dart`; документировано | 1.5 |
| P4-09 | Динамические сегменты (`/blog/:slug` × N) | P4-07 | W-15; N файлов из набора параметров | 1 |
| P4-10 | Хостинг-рецепты: rewrite/fallback для Firebase/Netlify/Cloudflare/GitHub Pages (path-routing, SPA-фолбэк `app`) | P4-07 | W-17; docs + пример на каждый хостинг | 1 |
| P4-11 | DevTools-оверлей: подсветка островов/директив/границ, диагностика гидрации, warning'и anti-CLS и props>10 KB | P4-04 | W-18/DS4; dev-режим показывает острова | 2.5 |
| P4-12 | Сверка «SSG-HTML ↔ гидрированный DOM» | P4-11 | W-19/R6; расхождение >5% текстовых узлов → warning | 1.5 |
| P4-13 | Virtual views (deferred, ≤2 KB): автосегментация высоких островов + IO-управление `addView/removeView` | P4-04 | W-13/R10; e2e скролл-тест сегментов | 2 |
| P4-14 | Zero-overhead проверка: нет `IslandType.flutter` → нет `flutter_bootstrap.js`/движка | P4-04,P4-07 | W-12/AS1/**I6/A9**; e2e | 1 |
| P4-15 | E2E-набор (Playwright): A3, A7, A9, A10 + CLS(I8) + sizing(I7) + a11y островов (axe/pa11y) | P4-02,P4-04,P4-06,P4-14 | A3/A7/A9/A10, I7/I8, NF-7; зелёные в CI | 4 |

**Итого: ~33 д (нижняя) — до ~35+ д со стабилизацией E2E.**

---

## Выходной гейт фазы = релиз MVP (ДОЛЖНО)
1. Полный hybrid-маршрут: статика мгновенно + vanilla мгновенно + Flutter-остров по директиве, CLS≈0 (A3/I8).
2. **I6/A9**: страница без Flutter-островов не грузит `flutter_bootstrap.js`.
3. **I7**: `canvas−host ≤1px` на ≥3 островах в 3 браузерах.
4. **A10**: HTMX-остров заменяет DOM без перезагрузки и без движка.
5. Самодостаточный `dist/` деплоится на 4 хостинга (W-17); SSG детерминирован (SSG3).
6. a11y островов покрыта E2E (NF-7).
7. Все 10 приёмочных сценариев A1–A10 зелёные.

## Приёмочные сценарии, покрываемые
- **A3, A7, A9, A10** — полностью (E2E).
- A1/A2/A5/A6/A8/A4 — регрессионно подтверждаются на полном стеке.

## Риски, затрагиваемые фазой
- **R1** (sizing #185034) — P4-02 + single-view fallback при регрессии.
- **R3** (старт движка) — диспетчер + deferred + SW + preload (P4-04/P4-06).
- **R10** (OffscreenCanvas limit) — P4-13 virtual views.
- **R6** (SSG↔hydrated рассинхрон) — P4-12.

---

*MVP завершён. Post-MVP (§16.1 спеки): server islands, advanced streaming (out-of-order/DPU),
инкрементальная SSG, расширенные таблицы, View Transitions, кодоген `@HydraPage`/`@HydraIsland`.*
