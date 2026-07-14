# Hydraline — Революционные идеи из индустрии

**Версия:** 1.0 | **Дата:** 2026-07-13

> Документ содержит оригинальные архитектурные идеи, найденные при исследовании
> передовых решений в веб-индустрии (2024-2026). Каждая идея оценена на
> применимость к Flutter/Dart и к архитектуре Hydraline.

---

## 1. Qwik: Resumability вместо Hydration

**Источник:** [qwik.dev](https://qwik.dev/docs/concepts/resumable/),
[qwikloader.ts](https://github.com/BuilderIO/qwik/blob/main/packages/qwik/src/qwikloader.ts)

### Идея

Qwik не делает hydration. Вместо этого он **сериализует состояние приложения в HTML**
на сервере и **возобновляет** (resume) исполнение на клиенте без повторного запуска
кода. Ключевой механизм:

1. Обработчики событий сериализуются в HTML-атрибуты:
```html
<button on:click="./chunk-a.js#Counter_button_onClick[0]">0</button>
```

2. Qwikloader (~1 KB) регистрирует **один глобальный слушатель** на все события.
3. При клике — читает атрибут, загружает нужный чанк, исполняет обработчик.
4. **Никакой hydration-проход не нужен.** Код загружается только при взаимодействии.

### Как применить к Hydraline

**Концепция: Resumable Flutter Islands**

Вместо того чтобы загружать Flutter-движок и исполнять widget tree для каждого острова,
сериализуем **состояние острова** в HTML и загружаем код острова только при первом
взаимодействии пользователя с ним.

```html
<!-- SSR/SSG вывод: -->
<hydraline-island
  id="calculator"
  data-state='{"price":1000,"currency":"RUB","quantity":1}'
  data-widget="chunks/calculator.dart.js#CalculatorIsland"
  data-directive="hydrateOnInteraction"
>
  <!-- Статический fallback (рендерится на сервере в HTML) -->
  <div class="hydraline-island-fallback">
    <span class="price">1 000 ₽</span>
    <span class="label">Цена рассчитается при загрузке...</span>
  </div>
</hydraline-island>
```

**Архитектура загрузчика:**

```js
// hydraline-loader.js (~2 KB) — аналог Qwikloader
class HydralineLoader {
  constructor() {
    // Один глобальный слушатель на ВСЕ события (всплытие)
    document.addEventListener('click', this.onInteract.bind(this), {capture: true});
    document.addEventListener('focusin', this.onInteract.bind(this), {capture: true});
    // ... другие события для разных директив
  }

  onInteract(ev) {
    const island = ev.target.closest('[data-directive="hydrateOnInteraction"]');
    if (!island || island.dataset.hydrated) return;

    // 1. Загружаем чанк с кодом острова
    const chunk = island.dataset.widget; // "chunks/calculator.dart.js#CalculatorIsland"
    const [url, symbol] = chunk.split('#');

    // 2. Загружаем Flutter-движок (если ещё не загружен)
    // 3. Парсим состояние из data-state
    // 4. Монтируем FlutterView в host-элемент
    // 5. Передаём состояние как initialData → виджет возобновляется без пересчёта

    island.dataset.hydrated = 'true';
    this.mountFlutterView(island, url, symbol);
  }
}

new HydralineLoader();
```

**Что это даёт:**
- **Нулевой JS на старте**, если пользователь не взаимодействует с островом
- **Мгновенный FCP** — HTML уже содержит fallback-контент
- **Загрузка движка только при первой интеракции** с любым островом
- **Состояние не пересчитывается** — оно уже в HTML, виджет просто «продолжает»

**Отличие от текущего подхода в MITIGATION_PLAN:**
Сейчас: все острова ждут загрузки Flutter-движка → потом монтируются.
С resumability: движок не загружается, пока пользователь не кликнет на остров.
HTML уже содержит статический контент. Flutter — только для интерактива.

---

## 2. Chrome Declarative Partial Updates — Out-of-Order Streaming без JavaScript

**Источник:** [Chrome for Developers](https://developer.chrome.com/blog/declarative-partial-updates),
[WICG Explainer](https://github.com/WICG/declarative-partial-updates)

### Идея

Chrome 148+ (2026) поддерживает **декларативные частичные обновления** —
механизм, позволяющий HTML-потоку обновлять разные части DOM без JavaScript:

```html
<!-- Страница стримится в браузер -->
<header>...</header>

<!-- Placeholder для медленного контента -->
<template shadowrootmode="open">
  <div id="product-detail">
    <?start name="price">
      <div class="skeleton">Загрузка цены...</div>
    <?end>
  </div>
</template>

<!-- ПОЗЖЕ в этом же HTML-потоке: -->
<template for="price">
  <!-- Заменяет skeleton на реальный контент без JS -->
  <span class="price">950 ₽</span>
  <span class="discount">Скидка 5%</span>
</template>
```

Элементы `<template for="...">` **заменяют** содержимое целевого placeholder'а
без JavaScript. Замены могут приходить **вне порядка** — та, что зарезолвилась
первой, стримится первой.

### Как применить к Hydraline

**Концепция: Streaming SSR с out-of-order Flutter-островами**

Hydraline-сервер стримит HTML. Сначала — статический контент (head, meta, текст, ссылки).
Затем — острова по мере готовности, **вне порядка**:

```
HTTP Response Stream (chunked transfer-encoding):

[chunk 1 — TTFB ~50ms]
<!DOCTYPE html><html><head>
  <title>Товар: iPhone 15</title>
  <meta name="description" content="...">
  <meta property="og:title" content="...">
  <script type="application/ld+json">{...}</script>
</head><body>
  <h1>iPhone 15</h1>
  <p>Описание товара...</p>
  <img src="/iphone15.jpg" alt="iPhone 15">

  <!-- Placeholder'ы для островов -->
  <div id="island-price">
    <?start name="price"><?end>
    <div class="skeleton skeleton-price"></div>
  </div>
  <div id="island-reviews">
    <?start name="reviews"><?end>
    <div class="skeleton skeleton-reviews"></div>
  </div>
  <div id="island-calculator">
    <?start name="calculator"><?end>
    <div class="skeleton skeleton-calc"></div>
  </div>

[chunk 2 — +200ms, цена зарезолвилась первой]
  <template for="price">
    <hydraline-island id="price" data-state='{"price":89990,"oldPrice":99990}'>
      <span class="current-price">89 990 ₽</span>
      <span class="old-price">99 990 ₽</span>
    </hydraline-island>
  </template>

[chunk 3 — +1500ms, калькулятор зарезолвился]
  <template for="calculator">
    <hydraline-island id="calculator" data-state='{"price":89990}'
      data-directive="hydrateOnInteraction">
      <div class="calculator-skeleton">
        <button disabled>Рассчитать рассрочку</button>
      </div>
    </hydraline-island>
  </template>

[chunk 4 — +3000ms, отзывы зарезолвились последними]
  <template for="reviews">
    <hydraline-island id="reviews" data-state='{"productId":"iphone15"}'
      data-directive="hydrateOnVisible">
      <div class="reviews-static">★ 4.8 (124 отзыва)</div>
    </hydraline-island>
  </template>

</body></html>
```

**Что это даёт:**
- **TTFB ~50ms** — краулер видит head + meta + контент мгновенно
- **FCP ~50ms** — статический контент (h1, p, img) отображается мгновенно
- **Острова появляются по мере готовности**, не блокируя друг друга
- **Без JavaScript** — `<template for="...">` работает нативно в браузере
- **Googlebot видит ВСЁ** — buffered-режим для ботов (см. §5)

**Реализация на Dart-сервере:**

```dart
// hydraline_server: streaming SSR handler
Future<void> handleStreaming(Request request, RouteManifest route) async {
  final response = request.response;
  response.headers.contentType = ContentType.html;

  // 1. Статический shell — мгновенно
  response.write(renderShell(route.metadata));

  // 2. Статический контент (h1, p, img) — мгновенно
  response.write(renderStaticContent(route.document));

  // 3. Placeholder'ы для островов с <?start/?end> markers
  for (final island in route.islands) {
    response.write('''
      <div id="island-${island.id}">
        <?start name="${island.id}"><?end>
        ${renderSkeleton(island)}
      </div>
    ''');
  }

  // 4. Острова резолвятся параллельно, стримятся по мере готовности
  final futures = route.islands.map((island) async {
    final data = await island.fetchData(request);
    final html = renderIslandPlaceholder(island, data);
    return '<template for="${island.id}">$html</template>';
  });

  // out-of-order: кто первый зарезолвился — того и стримим
  await for (final chunk in streamOutOfOrder(futures)) {
    response.write(chunk);
  }

  // 5. Footer
  response.write('</body></html>');
  await response.close();
}
```

---

## 3. Litro: Declarative Shadow DOM + Streaming SSR

**Источник:** [litro.dev/blog/streaming-ssr-dsd](https://litro.dev/blog/streaming-ssr-dsd),
[web.dev/articles/declarative-shadow-dom](https://web.dev/articles/declarative-shadow-dom)

### Идея

Declarative Shadow DOM (DSD) позволяет определить Shadow Root прямо в HTML,
без JavaScript. Браузер парсит `<template shadowrootmode="open">` и сразу
создаёт изолированный Shadow DOM. При загрузке JS Custom Element «подхватывает»
уже существующий Shadow Root (через `ElementInternals.shadowRoot`) вместо
создания нового.

Hydration выглядит так:
```html
<!-- SSR вывод: компонент с DSD -->
<my-card>
  <template shadowrootmode="open">
    <style>
      .card { border: 1px solid #ccc; border-radius: 8px; }
    </style>
    <div class="card">
      <h2>Заголовок</h2>
      <slot></slot>
    </div>
  </template>
  <p>Контент карточки</p>
</my-card>
```

Браузер мгновенно рендерит карточку со стилями. JS-код компонента подключается
позже и **не пересоздаёт** Shadow Root — использует существующий.

### Как применить к Hydraline

**Концепция: `<hydraline-island>` как Custom Element с DSD**

Остров Hydraline — это Custom Element с декларативным Shadow DOM:

```html
<hydraline-island id="calculator" data-directive="hydrateOnVisible">
  <!-- Декларативный Shadow DOM — браузер парсит мгновенно -->
  <template shadowrootmode="open">
    <style>
      :host { display: block; contain: layout style paint; }
      .island-container {
        width: 640px; height: 480px;
        display: flex; align-items: center; justify-content: center;
      }
      .skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); }
    </style>
    <div class="island-container">
      <slot>
        <!-- No-JS fallback (слот наполняется статическим контентом) -->
        <div class="skeleton" style="width:320px;height:40px;border-radius:4px"></div>
        <p style="color:#999">Калькулятор загружается...</p>
      </slot>
    </div>
  </template>

  <!-- Статический fallback (в слоте) -->
  <span>Цена: 89 990 ₽</span>
</hydraline-island>
```

Когда Flutter-движок загружается и Island Shell монтирует view:
```js
class HydralineIsland extends HTMLElement {
  connectedCallback() {
    // Используем СУЩЕСТВУЮЩИЙ Shadow Root из DSD
    // (не создаём новый — attachShadow НЕ вызывается)
    this._shadow = this.shadowRoot || this.attachShadow({mode: 'open'});
    this._container = this._shadow.querySelector('.island-container');
  }

  mountFlutterView(flutterApp, initialData) {
    // Flutter-канвас вставляется ВНУТРЬ контейнера в Shadow DOM
    flutterApp.addView({
      hostElement: this._container,
      viewConstraints: {
        maxWidth: 640, maxHeight: 480,
        minWidth: 640, minHeight: 480,
      },
      initialData: initialData,
    });
  }
}
```

**Что это даёт:**
- **Стили острова изолированы** — не протекают на страницу, страница не ломает остров
- **Мгновенный рендер** — Shadow DOM парсится из HTML, не ждёт JS
- **Zero-JS Fallback** — `<slot>` содержит статический контент, видимый без Flutter
- **Размеры фиксированы внутри Shadow DOM** — не зависят от внешнего CSS (обход #185034!)
- **Custom Element не пересоздаёт Shadow Root** — использует DSD, избегая FOUC

---

## 4. Qwikloader: Глобальный Event Delegation вместо Индивидуальных Слушателей

**Источник:** [qwik.dev/docs/advanced/qwikloader](https://qwik.dev/docs/advanced/qwikloader/),
[qwikloader.ts](https://github.com/BuilderIO/qwik/blob/main/packages/qwik/src/qwikloader.ts)

### Идея

Вместо того чтобы регистрировать обработчики событий на каждом DOM-элементе
(что требует загрузки кода каждого компонента), Qwikloader:
1. Вешает **один глобальный слушатель** на `window` для каждого типа событий
2. При событии — идёт по цепочке `event.target → parentElement → ...`
3. Ищет атрибут `on:click="./chunk.js#symbol"`
4. Динамически импортирует чанк и вызывает нужный символ

Это позволяет отложить загрузку кода обработчика до момента реального взаимодействия.

### Как применить к Hydraline

**Концепция: Единый Island Dispatcher**

Вместо того чтобы загружать Flutter-движок для всех островов на странице,
используем единый глобальный диспетчер событий:

```js
// hydraline-dispatcher.js (~1.5 KB)
(function() {
  const ISLAND_ATTR = 'data-hydraline';
  const DIRECTIVE_ATTR = 'data-directive';

  // Карта: директива → тип события / триггер
  const DIRECTIVE_TRIGGERS = {
    hydrateOnLoad:      { type: 'immediate' },
    hydrateOnIdle:      { type: 'idle' },
    hydrateOnVisible:   { type: 'observer', observer: null },
    hydrateOnInteraction: { type: 'event', events: ['click', 'focusin', 'keydown'] },
    hydrateOnMedia:     { type: 'media', query: null },
  };

  // Единый глобальный слушатель
  document.addEventListener('click', handleEvent, { capture: true, passive: true });
  document.addEventListener('focusin', handleEvent, { capture: true, passive: true });

  function handleEvent(ev) {
    const island = ev.target.closest(`[${DIRECTIVE_ATTR}="hydrateOnInteraction"]`);
    if (!island || island._hydrating || island._hydrated) return;
    hydrateIsland(island);
  }

  // IntersectionObserver — ОДИН на все острова с hydrateOnVisible
  const visibilityObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        const island = entry.target;
        visibilityObserver.unobserve(island);
        hydrateIsland(island);
      }
    }
  });

  // requestIdleCallback — для hydrateOnIdle
  if (window.requestIdleCallback) {
    window.requestIdleCallback(() => {
      document.querySelectorAll(`[${DIRECTIVE_ATTR}="hydrateOnIdle"]`).forEach(hydrateIsland);
    });
  } else {
    setTimeout(() => {
      document.querySelectorAll(`[${DIRECTIVE_ATTR}="hydrateOnIdle"]`).forEach(hydrateIsland);
    }, 200);
  }

  // Immediate — hydrateOnLoad
  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll(`[${DIRECTIVE_ATTR}="hydrateOnLoad"]`).forEach(hydrateIsland);
  });

  // Настройка hydrateOnVisible
  document.querySelectorAll(`[${DIRECTIVE_ATTR}="hydrateOnVisible"]`).forEach(el => {
    visibilityObserver.observe(el);
  });

  let flutterEngineReady = false;

  function hydrateIsland(island) {
    if (island._hydrating || island._hydrated) return;
    island._hydrating = true;

    ensureFlutterEngine(() => {
      const state = JSON.parse(island.dataset.state || '{}');
      const directive = island.dataset.directive;
      const id = island.id;

      window.__hydralineApp.addView({
        hostElement: island,
        initialData: { id, state, directive },
        viewConstraints: {
          maxWidth:  island.clientWidth,
          maxHeight: island.clientHeight,
        },
      });
      island._hydrated = true;
    });
  }

  // ... ensureFlutterEngine загружает движок при первом вызове
})();
```

**Что это даёт:**
- **Один IntersectionObserver** на все острова (не N штук)
- **Один глобальный слушатель событий** (не N × M обработчиков)
- **Flutter-движок загружается только при первой гидрации** любого острова
- **Острова с `hydrateOnInteraction` не загружают движок**, пока пользователь не кликнет
- Размер диспетчера: ~1.5 KB (меньше, чем текущий Island Shell)

---

## 5. Nuxt/Next: Bot-Aware Streaming — не Cloaking

**Источник:** [Nuxt PR #34411](https://github.com/nuxt/nuxt/pull/34411),
[ParetoJS blog](https://paretojs.tech/blog/slowest-api/)

### Идея

Nuxt 4 (экспериментальный streaming SSR) делает важное архитектурное различие:
- **Пользователи (браузеры)** получают **потоковый** HTML (TTFB ~50ms, контент
  появляется по мере готовности)
- **Боты (Googlebot, Bingbot)** получают **полностью буферизованный** HTML
  (весь контент сразу, для индексации)

Это НЕ cloaking, потому что контент **идентичен**. Разница только в способе
доставки: чанками (chunked transfer) vs одним буфером. Бот видит тот же HTML,
просто получает его одной порцией.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  experimental: {
    ssrStreaming: true,
  },
  // Не стримить ботам — они получают буферизованный HTML
  ssrStreaming: {
    botRegex: /googlebot|bingbot|yandex/i,
  },
});
```

### Как применить к Hydraline

**Концепция: Два режима доставки — Streaming для UX, Buffered для SEO**

```dart
// hydraline_server: middleware
Future<Response> handleRequest(Request request) async {
  final userAgent = request.headers['user-agent'] ?? '';
  final isBot = _botPattern.hasMatch(userAgent.toLowerCase());

  if (isBot) {
    // БОТ: буферизованный HTML (весь контент сразу)
    // Идентичный контент, но одной порцией — для индексации
    final html = await renderBuffered(request);
    return Response.ok(html, headers: {'content-type': 'text/html'});
  } else {
    // ПОЛЬЗОВАТЕЛЬ: стриминговый HTML (чанками)
    // Тот же контент, но доставляется прогрессивно
    final stream = renderStreaming(request);
    return Response.ok(stream, headers: {
      'content-type': 'text/html',
      'transfer-encoding': 'chunked',
      // Без кэширования для стримов
      'cache-control': 'no-cache',
    });
  }
}
```

**Почему это не cloaking:**
- Контент **побитово идентичен** в обоих режимах
- Разница только в `Transfer-Encoding: chunked` vs буфер
- Google Webmaster Guidelines явно разрешают «оптимизацию доставки» если контент тот же
- Nuxt, Next.js, Remix — все делают так же

**Что это даёт:**
- **Боты получают полный HTML** за один ответ → 100% индексация
- **Пользователи получают мгновенный FCP** → лучший UX
- **Никакого cloaking-риска** → контент идентичен

---

## 6. Flutter Team: IntersectionObserver Virtual Views

**Источник:** [Flutter Issue #175892](https://github.com/flutter/flutter/issues/175892)
(комментарий mdebbar)

### Идея

Для высокого Flutter-контента (>4096 px — лимит OffscreenCanvas) Flutter-команда
рекомендует: разбить контент на **несколько маленьких view**, управляемых через
`IntersectionObserver`. По сути — **виртуальный скроллинг на уровне Flutter View**.

```
Вместо одного view высотой 12000px:
┌─────────────────┐
│   View 1 (0)    │ ← видимый
├─────────────────┤
│   View 2 (4K)   │ ← видимый
├─────────────────┤
│   View 3 (8K)   │ ← за границей экрана → unmount
└─────────────────┘

При скролле:
- Views, попавшие в viewport → mount
- Views, вышедшие из viewport → unmount
```

### Как применить к Hydraline

**Концепция: Virtual Flutter Islands для длинных страниц**

Если остров выше 4096 px (лимит OffscreenCanvas), Hydraline автоматически
разбивает его на сегменты:

```html
<!-- SSR/SSG вывод: остров разбит на сегменты -->
<hydraline-island-segment
  id="calculator-segment-0"
  data-virtual="calculator"
  data-offset="0"
  data-height="4000"
  style="min-height:4000px"
>
  <div class="skeleton" style="height:4000px"></div>
</hydraline-island-segment>

<hydraline-island-segment
  id="calculator-segment-1"
  data-virtual="calculator"
  data-offset="4000"
  data-height="4000"
  style="min-height:4000px"
>
  <div class="skeleton" style="height:4000px"></div>
</hydraline-island-segment>
```

```js
// hydraline-virtual.js
class VirtualIslandManager {
  constructor() {
    this.segments = new Map(); // islandId → список сегментов
    this.activeSegments = new Set();
    this.observer = new IntersectionObserver(
      this.onIntersection.bind(this),
      { rootMargin: '1000px' } // предзагрузка за 1000px до viewport
    );
  }

  registerSegments(islandId) {
    const segments = document.querySelectorAll(
      `[data-virtual="${islandId}"]`
    );
    segments.forEach(s => this.observer.observe(s));
  }

  onIntersection(entries) {
    for (const entry of entries) {
      const seg = entry.target;
      const islandId = seg.dataset.virtual;

      if (entry.isIntersecting && !this.activeSegments.has(seg)) {
        this.activeSegments.add(seg);
        // Монтируем FlutterView только для видимого сегмента
        window.__hydralineApp.addView({
          hostElement: seg,
          viewConstraints: {
            maxWidth: seg.clientWidth,
            maxHeight: parseInt(seg.dataset.height),
          },
          initialData: {
            islandId,
            offset: parseInt(seg.dataset.offset),
            height: parseInt(seg.dataset.height),
          },
        });
      } else if (!entry.isIntersecting && this.activeSegments.has(seg)) {
        this.activeSegments.delete(seg);
        // Unmount для невидимого сегмента → экономим GPU/память
        // window.__hydralineApp.removeView(seg._viewId);
      }
    }
  }
}
```

**Что это даёт:**
- **Обход лимита 16384px** OffscreenCanvas
- **Экономия GPU-памяти** — рендерятся только видимые сегменты
- **Нативная рекомендация Flutter-команды**
- **Автоматическое разбиение** — разработчику не нужно думать об этом

---

## 7. Columbo: Completion-Order Streaming

**Источник:** [github.com/johnbchron/columbo](https://github.com/johnbchron/columbo)

### Идея

Библиотека Columbo (Rust) стримит Suspense-фрагменты **в порядке завершения**,
а не в порядке объявления:

> Responses are streamed in completion order, not registration order, so the
> future that completes first will stream first.

Это максимизирует полезную нагрузку в каждом чанке — быстрые данные не ждут
медленных.

### Как применить к Hydraline

**Концепция: Fastest-First Island Streaming**

При SSR несколько островов могут запрашивать данные параллельно. Вместо того
чтобы ждать всех, стримим каждый остров как только его данные готовы:

```dart
// hydraline_server: fastest-first streaming
Stream<String> renderIslandsOutOfOrder(List<IslandManifest> islands) async* {
  // Создаём futures для всех островов
  final futures = <Future<IslandChunk>>[];
  for (final island in islands) {
    futures.add(_renderIslandWhenReady(island));
  }

  // Стримим по мере завершения (fastest first)
  // Используем StreamController + Future.forEach с неблокирующим ожиданием
  final controller = StreamController<String>();

  for (final future in futures) {
    // Не await — запускаем все параллельно
    future.then((chunk) {
      if (!controller.isClosed) {
        controller.add(chunk.html);
      }
    });
  }

  // Ждём все, потом закрываем
  await Future.wait(futures);
  await controller.close();

  yield* controller.stream;
}
```

**Что это даёт:**
- **Быстрые острова не ждут медленных** (остров «цена» не ждёт остров «отзывы»)
- **FCP для контента выше сгиба — быстрее**
- **Пользователь видит прогресс**, а не пустой экран

---

## 8. Qwik: Function-Level Code Splitting

**Источник:** [qwik.dev/docs/concepts/think-qwik](https://qwik.dev/docs/concepts/think-qwik/)

### Идея

Qwik разбивает приложение не на уровне маршрутов или компонентов, а на уровне
**отдельных функций** (обработчиков событий). Каждый `onClick$` — это отдельный
lazy-loaded чанк. Это радикально уменьшает стартовый бандл.

### Как применить к Hydraline

**Концепция: Per-Island Deferred Imports**

Вместо одного `main.dart.js` со всеми островами, каждый остров — отдельный
deferred import. Flutter-движок + базовый рантайм загружаются всегда, а код
конкретного острова — только при триггере:

```dart
// lib/island_entry.dart
import 'package:flutter/material.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

// Базовые импорты (всегда в бандле)
import 'islands/button.dart';
import 'islands/text.dart';

// ТЯЖЁЛЫЕ острова — deferred (отдельные чанки)
import 'islands/calculator.dart' deferred as calc;
import 'islands/configurator.dart' deferred as conf;
import 'islands/chart.dart' deferred as chart;
import 'islands/editor.dart' deferred as editor;

final islandFactories = <String, Future<Widget> Function(Map<String, dynamic>)>{
  'calculator': (props) async {
    await calc.loadLibrary();        // Загрузка только этого чанка
    return calc.CalculatorIsland(props: props);
  },
  'configurator': (props) async {
    await conf.loadLibrary();
    return conf.ConfiguratorIsland(props: props);
  },
  'chart': (props) async {
    await chart.loadLibrary();
    return chart.ChartIsland(props: props);
  },
  'editor': (props) async {
    await editor.loadLibrary();
    return editor.EditorIsland(props: props);
  },
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(IslandHost(factories: islandFactories));
}
```

**Размеры бандлов:**
| Компонент | Размер (gzip) |
|---|---|
| Flutter engine runtime | ~400 KB |
| Базовые виджеты | ~50 KB |
| calculator.dart.js (deferred) | ~30 KB |
| chart.dart.js (deferred) | ~80 KB |
| editor.dart.js (deferred) | ~120 KB |

Без deferred: один `main.dart.js` = ~680 KB.
С deferred: стартовый бандл = ~450 KB, остальное — по требованию.

---

## Сводная таблица идей и их влияния на Hydraline

| # | Идея | Источник | Влияние на Hydraline | Приоритет |
|---|---|---|---|---|
| 1 | Resumability вместо hydration | Qwik | Состояние острова в HTML; движок загружается при интеракции, а не на старте | **Высокий** |
| 2 | Declarative Partial Updates | Chrome DPU | Out-of-order стриминг островов без JS | **Высокий** |
| 3 | Declarative Shadow DOM | Web Standards | Custom Element с изолированными стилями + zero-JS fallback | **Средний** |
| 4 | Глобальный Event Delegation | Qwikloader | Единый диспетчер на все острова (~1.5 KB) | **Высокий** |
| 5 | Bot-Aware Streaming | Nuxt/Next | Буферизованный HTML для ботов, потоковый для людей | **Средний** |
| 6 | IntersectionObserver Virtual Views | Flutter Team | Обход лимита OffscreenCanvas, экономия GPU | **Низкий** |
| 7 | Completion-Order Streaming | Columbo | Быстрые острова не ждут медленных | **Средний** |
| 8 | Function-Level Code Splitting | Qwik | Каждый остров — отдельный deferred import | **Высокий** |

---

## Рекомендуемая интеграция в архитектуру Hydraline

Наиболее трансформирующие идеи — **Resumability (#1)**, **DPU Streaming (#2)**,
**Qwikloader-style Dispatcher (#4)** и **Per-Island Deferred (#8)** —
могут быть скомбинированы в единую архитектуру:

```
1. SSR рендерит HTML с:
   - статическим контентом (instant)
   - placeholder'ами для островов с <?start/?end>
   - сериализованным состоянием островов в data-state

2. HTML стримится чанками:
   - [0ms]  shell (head, meta, JSON-LD)
   - [0ms]  статический контент (h1, p, img)
   - [+N]   острова по мере готовности (fastest first)
   - острова встраиваются через <template for="..."> (DPU)

3. В браузере:
   - Контент виден мгновенно (FCP ~50ms)
   - Hydraline Dispatcher (~1.5 KB) регистрирует глобальный event delegation
   - Flutter-движок загружается ТОЛЬКО при первой интеракции с любым островом
   - При интеракции: движок инициализируется, состояние читается из data-state,
     остров «возобновляется» без пересчёта
   - Острова с hydrateOnVisible — через IntersectionObserver (один на все)
   - Острова с hydrateOnIdle — через requestIdleCallback

4. Для ботов: buffered режим (тот же HTML, одна порция)
```

---

*Документ дополняет HYDRALINE_SPEC.md и MITIGATION_PLAN.md. Идеи подлежат
spike-проверке на применимость в контексте Flutter Web.*
