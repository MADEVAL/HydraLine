# Hydraline — JS/DOM Runtime Contract (L4)

| Поле | Значение |
|---|---|
| Пакет | `hydraline_flutter/web/` |
| Реализация | PHASE_4 (P4-01…P4-06, P4-13, P4-14) |
| Базис | `ARCHITECTURE.md` §12, спека W-8…W-13, §7.1/§7.2/§7.9 |
| Назначение | Заморозка контракта клиентского рантайма: HTML-элементы, атрибуты, события, глобальный JS-API |

> Клиентский рантайм — единственный собственный JS уровня 2. Контракт ниже
> фиксирует границу «HTML ↔ браузерный рантайм» до реализации. Бюджеты (min+gzip):
> Custom Element ≤ 2 KB, диспетчер ≤ 2 KB, Service Worker ≤ 2 KB, virtual ≤ 2 KB.

---

## 1. Custom Element `<hydraline-island>` (W-8)

### 1.1 Разметка (эмитится сериализатором для `IslandType.flutter`)

```html
<hydraline-island
  id="calculator"
  data-directive="hydrateOnVisible"
  data-render-mode="ssr"                       <!-- ssr | skeletonOnly -->
  data-style-mode="shadow"                      <!-- shadow | scoped -->
  data-state='{"price":89990,"currency":"RUB"}' <!-- JSON, HTML-escaped, ≤10 KB -->
  data-hydration="pending"                      <!-- ставится рантаймом -->
  role="region" aria-busy="true" aria-label="Калькулятор, загружается">
  <template shadowrootmode="open">
    <style>:host{display:block;contain:layout style paint}
           .host{width:640px;height:480px}</style>
    <div class="host"><slot>
      <!-- SSR-fallback / skeleton (виден без JS) -->
    </slot></div>
  </template>
</hydraline-island>
```

### 1.2 Контракт поведения (ДОЛЖНО)
- **CE1.** Использует **существующий** Shadow Root из DSD (не вызывает `attachShadow` повторно → нет FOUC).
- **CE2.** Размеры host — фиксированные px (из `IslandSize`, anti-CLS I8).
- **CE3.** При монтировании передаёт в `addView()` явные `viewConstraints` с `min==max` (обход #185034, I7).
- **CE4.** `ResizeObserver`-корректор: пересчитывает pinned-констрейнты только при committed-ресайзе; коалесинг всех view в один `requestAnimationFrame`; debounce; **no-op на Flutter 3.41.x**.
- **CE5.** `scoped`-режим (`data-style-mode="scoped"`): стили выносятся 1× в `<head>`, острова получают scope-атрибут.

### 1.3 Virtual segments (W-13, высокие острова, R10)
```html
<hydraline-island-segment data-virtual="calc" data-offset="0"    data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
<hydraline-island-segment data-virtual="calc" data-offset="4000" data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
```
- **VS1.** Сегменты в viewport (+`rootMargin`) → `addView()`; вышедшие → `removeView()`.
- **VS2.** Активируется только при `IslandType.flutter` выше порога (~4000px); иначе нулевой оверхед.

---

## 2. Диспетчер `window.hydraline` (W-9)

### 2.1 Глобальный API
```ts
interface HydralineGlobal {
  hydrate(id: string): Promise<void>;   // ручная гидрация одного острова
  hydrateAll(): Promise<void>;          // все островы с directive=manual
  readonly version: string;
}
declare const hydraline: HydralineGlobal; // window.hydraline
```
- **DP1.** Работает на `document`/`hybrid`-страницах, где `MaterialApp` НЕ запущен (для `hydrateManual`, §7.9).
- **DP2.** Один `IntersectionObserver` на все `hydrateOnVisible`; один `requestIdleCallback` на все `hydrateOnIdle`; одно делегирование `click`/`focusin` на `hydrateOnInteraction`; `matchMedia` на `hydrateOnMedia`.
- **DP3.** Flutter-движок грузится **только** при первом триггере любого острова (P8/AS1).
- **DP4.** Порядок гидрации — top-down (родитель раньше вложенного).

### 2.2 Директивы (значения `data-directive`)
| Значение | Триггер | Браузерное API |
|---|---|---|
| `hydrateOnLoad` | немедленно на DOMContentLoaded | `DOMContentLoaded` |
| `hydrateOnIdle` | простой (дефолт) | `requestIdleCallback` (+fallback) |
| `hydrateOnVisible` | viewport | `IntersectionObserver` |
| `hydrateOnInteraction` | первое взаимодействие | глобальное делегирование |
| `hydrateOnMedia` | совпадение media-query | `matchMedia` (`data-media`) |
| `hydrateManual` | `window.hydraline.hydrate(id)` | — |

### 2.3 Жизненный цикл (`data-hydration`, §7.9)
```
pending → hydrating → hydrated
                    ↘ failed   (тайм-аут / ошибка загрузки движка или deferred-чанка)
```
- **DP5.** При терминальном сбое: fallback/скелетон **остаётся видимым**; ставится `data-hydration="failed"`; снимается `aria-busy`.
- **DP6.** Ограниченный retry с тайм-аутом на загрузку движка и per-island чанка.

### 2.4 Событие ошибки
```ts
// dispatchEvent на host-элементе, всплывает
new CustomEvent('hydraline:island-error', { bubbles: true, detail: { id: string, reason: string } })
```

### 2.5 Передача во Flutter (граница JS→Dart)
```ts
// initialData несёт id → IslandHost (Dart) мапит на фабрику (IH1)
flutterApp.addView({
  hostElement,
  viewConstraints: { minWidth: w, maxWidth: w, minHeight: h, maxHeight: h }, // CE3
  initialData: { id, state /* JSON.parse(data-state) */, directive },
});
```
- **DP7.** `data-state` парсится только через `JSON.parse` (DS1). Запрещены `eval`/`Function`/`DOMParser`.

---

## 3. Vanilla islands (уровень 1, ассеты из core C-12)

### 3.1 Разметка
```html
<div class="hydraline-island" data-island="accordion" data-island-level="vanilla">
  <details><summary>…</summary><p>…</p></details>
</div>
```
### 3.2 Типы и no-JS fallback
| `data-island` | Действие | Fallback без JS |
|---|---|---|
| `accordion` | анимация + aria над `<details>` | `<details>` работает |
| `tabs` | переключение панелей | `:target` через якоря |
| `carousel` | листание слайдов | статичная лента |
| `theme` | переключение `data-theme` | `prefers-color-scheme` |
| `copy-button` | копирование в буфер | обычная кнопка |
| `lazy-image` | ленивая загрузка | `<img loading="lazy">` |

- **VA1.** Монтируются на `DOMContentLoaded`; не зависят от Flutter-движка.
- **VA2.** Пакет `hydraline_flutter` **переиспользует** этот бандл из core (W-10), не дублируя.

---

## 4. HTMX-острова (уровень 1)

### 4.1 Разметка
```html
<div class="hydraline-island" data-island="htmx" data-island-level="htmx"
     hx-get="/api/reviews/iphone15" hx-trigger="load" hx-swap="innerHTML">
  <div class="skeleton">Загрузка отзывов...</div>
</div>
```
- **HX1.** HTMX-скрипт (~14 KB) вендорится как first-party (совместимо с CSP `script-src 'self'`), грузится только при наличии HTMX-островов.
- **HX2.** Сервер отвечает HTML-фрагментом (`serializeFragment`) — без `<html>/<head>`, без Flutter-движка (A10).

---

## 5. Service Worker (W-11)

- **SW1.** Кэширует `main.dart.js` + `canvaskit.wasm`.
- **SW2.** Прогрев через `WebAssembly.instantiateStreaming()` + `<link rel="preload">`/`modulepreload`.
- **SW3.** Тёплый повторный визит: TTI ~1 с.

---

## 6. Zero-overhead инвариант (W-12 / AS1 / I6)

- **ZO1.** Если на странице нет `IslandType.flutter` → `flutter_bootstrap.js` **не вставляется**, базовый L2-JS (Custom Element/диспетчер/SW) не грузится.
- **ZO2.** Уровни 0–1 (статика, vanilla, HTMX) работают без Flutter вовсе.
- **ZO3.** Проверка — на уровне SSR/SSG-генератора и диспетчера; E2E-сценарий A9.

---

## 7. Сводка DOM-контракта (заморожено)

**Элементы:** `<hydraline-island>`, `<hydraline-island-segment>`.
**Атрибуты:** `data-directive`, `data-render-mode`, `data-style-mode`, `data-state`,
`data-hydration`, `data-media`, `data-island`, `data-island-level`, `data-virtual`,
`data-offset`, `data-height`.
**События:** `hydraline:island-error`.
**Глобаль:** `window.hydraline.hydrate(id)`, `window.hydraline.hydrateAll()`, `window.hydraline.version`.

---

*L4 завершён по всем трём пакетам + JS-рантайм. Изменения контракта — только через
версионирование и синхронизацию с `HYDRALINE_SPEC_V3.md` + `ARCHITECTURE.md`.*
