# Hydraline — Альтернативы и смежные решения из индустрии

**Версия:** 1.0 | **Дата:** 2026-07-13 | **Дополняет:** INDUSTRY_IDEAS.md

> Второй раунд исследования. Фокус: альтернативные подходы, Dart-экосистема,
> конкуренты и смежные архитектурные решения из других языков/фреймворков.

---

## 1. Spark Framework — прямой Dart-конкурент (и ориентир)

**Источник:** [spark.kleak.dev](https://spark.kleak.dev/),
[pub.dev/packages/spark_framework](https://pub.dev/packages/spark_framework)

### Что это

Spark — **изоморфный SSR-фреймворк на Dart** с Custom Elements и Declarative
Shadow DOM. Это ближайший аналог того, что делает Hydraline, но без Flutter.

### Архитектура

Трёхфайловая модель компонента:

```
my-counter/
├── my_counter.dart       # Базовый файл (общий)
├── my_counter.impl.dart  # hydrate + reactivity (генерируется)
└── my_counter.html       # Шаблон (опционально)
```

```dart
@Component(tag: 'my-counter')
class MyCounter extends SparkComponent {
  @Attribute()
  int value = 0;

  @override
  Element render() => div([
    span('.count', text: '$value'),
    button(text: '+', onClick: (_) => value++),
    button(text: '-', onClick: (_) => value--),
  ]);

  @override
  AdoptedStyleSheets get adoptedStyleSheets => css({
    '.count': { 'font-size': 2.rem },
  });
}
```

**Как работает SSR:**
1. Компонент рендерится на сервере через `render()` → HTML
2. Выход содержит `<my-counter>` + Declarative Shadow DOM
3. Браузер парсит HTML, Shadow DOM создаётся без JS
4. Клиентский JS загружается, Custom Element «апгрейдится»
5. Spark читает `@Attribute` из DOM-атрибутов, восстанавливает состояние

### Что можно украсть для Hydraline

1. **`@Attribute` + автосинхронизация DOM** — изменение поля автоматически обновляет
   и состояние, и DOM-атрибут. Для Hydraline-островов: props из `data-state` →
   поля виджета → автообновление.

2. **Трёхфайловая модель** — базовый файл + impl (генерируется) + шаблон.
   Hydraline может использовать кодогенерацию для создания `DocumentNode`-билдера
   из аннотированных Flutter-виджетов.

3. **adoptedStyleSheets** — стили через CSSOM (`adoptedStyleSheets`) вместо
   `<style>` тегов. Эффективнее для SSR (не дублируются в каждом экземпляре).

4. **`@Component(tag:)`** — аннотация вместо ручной регистрации Custom Element.
   Hydraline может предложить `@HydraIsland('calculator')` аннотацию.

### Позиционирование Hydraline vs Spark

| | Spark | Hydraline |
|---|---|---|
| Рендер | Pure Dart → HTML | Flutter → CanvasKit + HTML |
| Компоненты | Dart-классы | Flutter-виджеты |
| Цель | Dart-сайты без Node.js | Flutter-приложения с SEO |
| Интерактив | Web Components | Flutter Islands (CanvasKit) |
| Аудитория | Dart-разработчики, уходящие от JS | Flutter-разработчики, которым нужно SEO |

**Вывод:** Spark — не конкурент, а proof-of-concept того, что Custom Elements +
DSD + Dart работают в продакшене. Hydraline делает то же самое,
но для Flutter-экосистемы.

---

## 2. Trellis — Pure-Dart HTMX + SSG

**Источник:** [github.com/tolo/trellis](https://github.com/tolo/trellis),
[pub.dev/packages/trellis](https://pub.dev/packages/trellis)

### Что это

Trellis — **чистый Dart SDK** для серверных веб-приложений и статических сайтов.
Без Node.js, без npm, без JavaScript-фреймворков. По духу — Dart-версия
Thymeleaf + Hugo + HTMX в одном флаконе.

### Ключевые архитектурные решения

1. **Натуральные HTML-шаблоны** — шаблоны это валидный HTML, который браузер
   может открыть как прототип без сервера:
```html
<!-- templates/pages/product.html -->
<html tl:extends="layouts/base.html">
  <div tl:define="content">
    <h1 tl:text="${product.name}">Product Name</h1>
    <p tl:text="${product.description}">Description</p>

    <!-- Фрагмент для HTMX-запросов -->
    <div tl:fragment="price">
      <span tl:text="${product.price}">$99.99</span>
    </div>
  </div>
</html>
```

2. **Фрагмент-first дизайн** — `tl:fragment` + `renderFragment()` для HTMX:
```dart
// Серверный handler
Future<Response> getPrice(Request request) async {
  final product = await fetchProduct();
  final html = engine.renderFragment('pages/product.html',
    fragment: 'price',
    context: {'product': product},
  );
  return Response.ok(html);
}
```

3. **Гибридная статика + динамика** — ОДИН И ТОТ ЖЕ шаблон рендерится:
   - На этапе сборки (SSG) — в статический `.html`
   - На запросе (SSR) — в HTMX-фрагмент
   - Без дублирования кода

4. **Single-binary деплой** — `dart compile exe` → один файл, мгновенный старт.

### Что можно украсть для Hydraline

1. **Fragment-first мышление.** Hydraline может рендерить `DocumentNode` не только
   как целую страницу, но и как фрагмент (для HTMX/partial-запросов):

```dart
// hydraline_server: fragment rendering
final doc = DocumentNode.of(
  children: [HeadingNode.h2('Price'), ParagraphNode('${price}₽')]
);
final html = serializer.serialize(doc); // без <html>/<head>/<body>
```

Это открывает HTMX-интеграцию: Flutter-приложение может использовать HTMX
для динамических обновлений без перезагрузки страницы.

2. **Единый шаблон для SSG и SSR.** Hydraline уже делает это через `DocumentNode` —
   одна модель, два режима доставки. Trellis подтверждает правильность подхода.

3. **Template inheritance.** `tl:extends` + `tl:define` — layouts. Для Hydraline:
   `DocumentNode` с layout-расширением (базовый документ + переопределение зон).

4. **Dart Frog + Shelf + Relic адаптеры.** Trellis показывает паттерн: один
   движок рендера, тонкие адаптеры под каждый серверный фреймворк. Hydraline
   уже спроектирован так же (`hydraline_server` с адаптерами).

---

## 3. Marko (eBay) — Пионер Streaming SSR и Compile-Time оптимизаций

**Источник:** [markojs.com](https://markojs.com/docs/explanation/streaming),
[markojs.com/docs/newsletter/june-2026](https://markojs.com/docs/newsletter/june-2026)

### Что это

Marko — JavaScript-фреймворк от eBay, работающий в продакшене с 2014 года на
миллионах страниц ebay.com. **Первый фреймворк с нативным streaming SSR**
(на decade раньше, чем Next.js/React).

### Ключевые идеи, которых нет больше нигде

1. **Single-pass рендеринг без промежуточного DOM-дерева.**
   Marko не строит VDOM на сервере. Вместо этого компилирует шаблоны в серию
   строковых конкатенаций, которые пишут напрямую в HTML-поток:
```
Компиляция:
  <div><h1>${title}</h1><p>${body}</p></div>
      ↓
Сгенерированный код:
  out.w('<div><h1>'); out.w(escape(title)); out.w('</h1><p>'); out.w(escape(body)); out.w('</p></div>');
```

   Это даёт **максимальную производительность SSR** — нет аллокаций
   промежуточных объектов, нет обхода дерева, нет сборки мусора.

2. **Compile-time реактивность.** Marko анализирует шаблон на этапе компиляции
   и определяет, какие части DOM будут меняться. Генерирует только тот JS,
   который нужен для обновления этих частей.

3. **Статический контент → 0 KB клиентского JS**, даже если он в одном шаблоне
   с интерактивным контентом. Компилятор разделяет статику и динамику.

4. **In-order + Out-of-order Streaming через `<await>`:**
```marko
<h1>Product Page</h1>
<p>This renders immediately</p>

<await(getUser)>
  <@placeholder>Loading user...</@placeholder>
  <@then|user|>
    <div>Welcome, ${user.name}</div>
  </@then>
  <@catch|err|>
    <div>Error: ${err.message}</div>
  </@catch>
</await>

<await(getRecommendations)>
  <@placeholder>
    <!-- Out-of-order: не ждёт getUser -->
    Loading recommendations...
  </@placeholder>
  <@then|recs|>
    <div>Recommendations: ${recs}</div>
  </@then>
</await>
```

5. **Resumability (Marko 6).** Как и Qwik — состояние сериализуется в HTML,
   клиент не повторяет работу сервера. Resumed conditional branches сохраняются,
   lazily-loaded эффекты выполняются после вставки.

### Что можно украсть для Hydraline

1. **Single-pass HTML-сериализатор.** Сейчас в Hydraline `DocumentNode` →
   сериализатор → HTML. Можно оптимизировать сериализатор до single-pass:
   без промежуточного буфера, писать напрямую в `HttpResponse` stream.

2. **Compile-time separation статики/динамики.** Для Flutter-виджетов:
   build_runner анализирует `Seo.*` виджеты на этапе компиляции и разделяет:
   - Статические узлы → `DocumentNode` (без Flutter-зависимостей)
   - Динамические узлы → deferred Flutter-чанк

3. **Out-of-order `<await>` как модель для островов.** Marko показывает, что
   out-of-order streaming с `<@placeholder>` + `<@then>` — зрелый паттерн.
   Hydraline может реализовать то же самое для Flutter-островов.

4. **In-order await с защитой от hydration-сбоев.** Marko PR #3322 фиксит:
   если in-order `<await>` блокирует поток, hydration-эффекты откладываются
   до разрешения await. В Hydraline: если остров ждёт данные, hydration
   приостанавливается до готовности данных.

---

## 4. Fresh (Deno) — Zero-JS и Streaming Partials

**Источник:** [fresh.deno.dev](https://fresh.deno.dev/),
[denoland.deno.dev/blog/fresh-2.3](https://denoland.deno.dev/blog/fresh-2.3)

### Что это

Fresh — сервер-first веб-фреймворк на Deno. По умолчанию: **ноль JavaScript**
в браузере. Интерактивность добавляется через острова (Preact-компоненты в
папке `islands/`).

### Ключевая находка: Fresh 2.3 наконец-то честно выполняет «zero JS»

До версии 2.3 ВСЕ страницы Fresh включали скрытый `client-entry` скрипт для
bootstrap'а islands и partials-движка, даже когда они не использовались.
**Маркетинг говорил «zero JS», реальность — нет.** PR #3696 исправил это:

```ts
// Fresh 2.3: проверка перед инъекцией JS
const needsClientRuntime = islands.size > 0 || clientNavEnabled;
if (!needsClientRuntime) {
  // Не вставляем <script> — страница реально без JS
  return;
}
```

### Streaming Partials (ключевая фича)

Fresh позволяет **стримить HTML-фрагменты с сервера** и заменять части страницы
без клиентского роутинга:

```tsx
<div f-client-nav>
  <aside>
    <button f-partial="/recipes/lemonade">Lemonade</button>
    <button f-partial="/recipes/lemon-honey-tea">Lemon-honey tea</button>
  </aside>
  <main>
    <Partial name="recipe">
      Click a recipe to stream HTML into this spot
    </Partial>
  </main>
</div>
```

При клике сервер стримит **только фрагмент HTML**, браузер заменяет содержимое
`<Partial>` без полной перезагрузки и без клиентского JS-роутера.

### Что можно украсть для Hydraline

1. **Честная проверка «нужен ли JS».** Hydraline должен проверять:
   - Есть ли на странице `Island` виджеты?
   - Используются ли vanilla-острова?
   - Если нет → не вставлять `flutter_bootstrap.js` и не загружать движок.

2. **Streaming Partials для Flutter-островов.** Вместо полной перезагрузки
   страницы при навигации, сервер может стримить только изменившийся остров:
```
GET /product/123?partial=calculator
→ стримится ТОЛЬКО HTML-фрагмент <hydraline-island id="calculator" ...>
```

3. **View Transitions API.** Fresh 2.3 интегрирует View Transitions API.
   Hydraline может использовать это для плавных переходов между островами.

4. **prerender: true** — простое SSG для помеченных маршрутов. Без отдельного
   пакета, без CLI. Просто флаг в конфиге маршрута.

---

## 5. SolidStart — Fine-Grained Reactivity + Islands

**Источник:** [docs.solidjs.com/solid-start](https://docs.solidjs.com/solid-start),
[islands-architecture.com](https://www.islands-architecture.com/framework-specific-islands-streaming-ssr/solidstart-islands-and-partial-hydration/)

### Что это

SolidStart — мета-фреймворк для SolidJS. Уникален тем, что комбинирует
**islands architecture** с **fine-grained reactivity** (нет VDOM).

### Ключевой инсайт: стоимость гидрации O(реактивные биндинги), а не O(DOM-узлы)

| Фреймворк | Модель гидрации | Стоимость |
|---|---|---|
| React (VDOM) | Полный reconcile дерева | O(DOM-узлы) |
| Solid (fine-grained) | Восстановление подписок | O(реактивные биндинги) |
| SolidStart islands | Только острова × fine-grained | **Минимальная** |

Solid компилирует JSX в императивный DOM-код. `createSignal` создаёт getter/setter.
При гидрации Solid **не обходит дерево** — он восстанавливает только сигналы,
которые реально используются. Остров с 1 кнопкой = 1 сигнал = ~0 стоимость.

### clientOnly — решение для браузер-специфичных компонентов

Компоненты, читающие `window`/`localStorage` в рендере, не могут рендериться
на сервере (SSR crash или hydration mismatch). `clientOnly` решает это:

```tsx
import { clientOnly } from '@solidjs/start';

const AudioPlayer = clientOnly(() => import('./audio-player'), {
  fallback: <div class="skeleton" style="width:320px;height:54px" />
});
```

Fallback резервирует место и предотвращает CLS.

### Что можно украсть для Hydraline

1. **`clientOnly` для Flutter-островов.** Некоторые острова не могут иметь
   статический HTML-эквивалент (3D-конфигуратор, WebGL-график). Для них —
   режим `clientOnly`: только skeleton в SSR, Flutter-рендер на клиенте.

2. **Fine-grained обновления.** Flutter уже fine-grained по своей природе
   (виджеты иммутабельны, перестраиваются только изменившиеся поддеревья).
   Но Hydraline может подчеркнуть это как преимущество: остров на Flutter
   эффективнее острова на React.

3. **Детерминированный рендер острова.** SolidStart документирует проблему:
   `Date.now()`/`Math.random()` в рендере → hydration mismatch. Для Hydraline:
   остров должен рендерить **детерминированный** static-фоллбэк в HTML
   и загружать реальные данные через `initialData` из `data-state`.

---

## 6. Enhance — SSR Web Components как чистые функции

**Источник:** [enhance.dev](https://enhance.dev/blog/posts/2024-07-09-island-architecture-with-web-components)

### Что это

Enhance — фреймворк, где компоненты это **чистые функции**, принимающие
`{html, state}` и возвращающие HTML. SSR из коробки. Клиентский JS — только
для интерактивных «островов».

### Архитектура компонента

```js
// app/elements/my-header.mjs
export default function MyHeader({ html, state }) {
  const { attrs, store } = state;
  const { user } = store;

  return html`
    <header>
      <h1>${attrs.title || 'My App'}</h1>
      ${user ? `<span>Welcome, ${user.name}</span>` : '<a href="/login">Login</a>'}
    </header>
  `;
}
```

Никаких классов, `this`, `render()`. Чистая функция. SSR — просто вызов функции
с передачей состояния. Клиент — Custom Element, который вызывает ту же функцию
при апгрейде.

### Что можно украсть для Hydraline

1. **Функциональный API для DocumentNode.** Вместо императивного билдера:
```dart
// Было: императивный стиль
final doc = DocumentNode();
doc.h1('Title');
doc.p('Content');

// Альтернатива: функциональный стиль (как Enhance)
DocumentNode doc(String title, String content) => DocumentNode([
  HeadingNode.h1(title),
  ParagraphNode(content),
]);
```

2. **`store` как единый источник состояния.** Enhance передаёт глобальный `store`
   во все компоненты. Для Hydraline: `HydraScope` уже делает это.

3. **Функция `html` как tagged template.** Enhance использует `html`-функцию
   для построения DOM. Hydraline может предложить аналогичный DSL для
   построения `DocumentNode` в Dart.

---

## 7. Stencil — Compile-time vs Runtime SSR

**Источник:** [stenciljs.com/docs/server-side-rendering](https://stenciljs.com/docs/server-side-rendering)

### Что это

Stencil — компилятор Web Components от Ionic. Предлагает **две стратегии SSR**:

1. **Compiler-based (build-time):** Плагин компилятора перехватывает код и
   делает AST-трансформации. Компоненты пре-сериализуются в Declarative Shadow DOM
   на этапе сборки.

2. **Runtime (server-side):** Next.js Server Components рендерят Stencil-компоненты
   в рантайме. Подходит для динамических данных.

### Ключевая фича: scoped mode вместо Shadow DOM

Stencil может рендерить компонент в **scoped-режиме** (без Shadow DOM, стили
эмулируются через CSS scoping). Это решает проблему дублирования стилей
при SSR множества экземпляров одного компонента:

```ts
// Конфигурация: какие компоненты в Shadow DOM, какие в scoped
serializeShadowRoot: {
  default: 'declarative-shadow-dom',
  scoped: ['my-button', 'my-badge'], // Не дублируем стили для часто используемых
}
```

### Что можно украсть для Hydraline

1. **Scoped-режим для `<hydraline-island>`.** Если на странице 10 одинаковых
   островов, стили в DSD дублируются 10 раз. Scoped-режим решает это:
   один набор стилей на страницу, CSS @scope для изоляции.

2. **Компилятор vs Runtime выбор.** Hydraline может предложить:
   - Build-time: SSG через flutter_tester (как сейчас)
   - Runtime: SSR через pure-Dart `DocumentNode` builder (как сейчас)
   - Выбор определяется developer'ом исходя из динамичности данных

3. **hydrateModule как entry-point.** Stencil генерирует `hydrate` модуль —
   точку входа для SSR-сериализации. Для Hydraline: `hydraline_widgets`
   может экспортировать `hydrate`-API для внешних SSR-движков.

---

## 8. htmdart — Dart + HTMX как альтернативная модель интерактивности

**Источник:** [pub.dev/packages/htmdart](https://pub.dev/packages/htmdart),
[pub.dev/packages/trellis](https://pub.dev/packages/trellis)

### Идея

Вместо Flutter-островов для интерактивности, Hydraline может поддержать
**HTMX как опциональный backend-движок** для динамики. Это архитектурно
дополняет Flutter-острова, а не заменяет их.

### Модель: три уровня интерактивности

```
Уровень 0: Статический HTML (SEO, FCP <100ms)
Уровень 1: HTMX-острова (интерактив без Flutter, TTI ~50ms)
  - Формы, поиск, пагинация, табы — через HTMX-запросы
  - Сервер возвращает HTML-фрагменты
  - Не нужен Flutter-движок
Уровень 2: Flutter-острова (сложная интерактивность, TTI ~3-5s)
  - Калькуляторы, 3D-конфигураторы, графики
  - Flutter-движок + CanvasKit
```

### Интеграция с Hydraline

```dart
// hydraline_server: HTMX-aware DocumentNode builder
DocumentNode buildProductPage(Product product) => DocumentNode([
  // Статический контент (уровень 0)
  HeadingNode.h1(product.name),
  ParagraphNode(product.description),

  // HTMX-остров (уровень 1) — сервер рендерит фрагменты
  IslandPlaceholderNode(
    id: 'reviews',
    type: IslandType.htmx,        // ← NEW
    endpoint: '/api/reviews/${product.id}',
    trigger: 'load',               // hx-trigger="load"
    target: '#reviews-container',
  ),

  // Flutter-остров (уровень 2) — тяжёлый интерактив
  IslandPlaceholderNode(
    id: 'calculator',
    type: IslandType.flutter,
    directive: HydrateOnVisible(),
    props: {'price': product.price},
  ),
]);
```

Серверный handler для HTMX-острова:

```dart
// routes/api/reviews/[id].dart (Dart Frog)
Future<Response> onGet(Request req, String id) async {
  final reviews = await db.getReviews(id);
  final html = serializer.serializeFragment(
    DocumentNode([...reviews.map((r) => _reviewCard(r))])
  );
  return Response.ok(html);
}
```

### Что это даёт

- **Мгновенная интерактивность** (HTMX) для простых UI-паттернов
- **Flutter только для сложного** — меньший бандл, реже загрузка движка
- **HTMX работает без JavaScript-фреймворка** — один скрипт 14 KB
- **Dart на сервере** — единый язык для всего

---

## Сводная таблица: что берём из каждого источника

| Источник | Ключевая идея | Применение в Hydraline | Приоритет |
|---|---|---|---|
| **Spark** | `@Component` + DSD + `@Attribute` автосинхронизация | `@HydraIsland('name')` аннотация, авто-десериализация props из data-атрибутов | Средний |
| **Trellis** | Fragment-first + HTMX + единый шаблон для SSG/SSR | HTMX-острова как уровень 1 интерактивности, `renderFragment()` в сервере | **Высокий** |
| **Marko** | Single-pass SSR без DOM-дерева, compile-time статика/динамика, out-of-order `<await>` | Оптимизация HTML-сериализатора, out-of-order стриминг островов | **Высокий** |
| **Fresh** | Честный zero-JS, Streaming Partials без клиентского роутера | Проверка «нужен ли Flutter» перед загрузкой движка, стриминг фрагментов | Высокий |
| **SolidStart** | `clientOnly` + fine-grained стоимость гидрации | `clientOnly`-режим для Flutter-островов без статического HTML | Средний |
| **Enhance** | Компоненты как чистые функции `(html, state) → HTML` | Функциональный API для `DocumentNode` билдера | Низкий |
| **Stencil** | Scoped mode vs Shadow DOM, compile-time vs runtime SSR | Scoped-режим для островов (оптимизация стилей), выбор стратегии SSR | Средний |
| **htmdart** | Dart + HTMX helpers | Интеграция HTMX как альтернативного движка интерактивности | **Высокий** |

---

## Интеграция находок в итоговую архитектуру

Самые сильные идеи из двух документов (INDUSTRY_IDEAS.md + этот):

```
┌─────────────────────────────────────────────────────────┐
│  Уровень 0: Статический HTML (FCP < 100ms)               │
│  • Single-pass сериализатор (Marko)                      │
│  • Fragment-first рендеринг (Trellis)                    │
│  • Честная проверка: нет островов → нет JS (Fresh)       │
├─────────────────────────────────────────────────────────┤
│  Уровень 1: HTMX-острова (TTI ~50ms)                     │
│  • Простые интеракции: формы, табы, поиск, пагинация      │
│  • Сервер рендерит HTML-фрагменты (Trellis)              │
│  • Без Flutter-движка → мгновенно                        │
│  • htmdart helpers для Dart                              │
├─────────────────────────────────────────────────────────┤
│  Уровень 2: Flutter-острова (TTI ~3-5s холодный)         │
│  • Resumability: состояние в data-state (Qwik)            │
│  • Out-of-order стриминг (Marko/DPU)                     │
│  • Per-island deferred imports (Qwik)                    │
│  • Qwikloader-style диспетчер (~1.5 KB)                  │
│  • clientOnly для не-SSR-совместимых островов (Solid)     │
│  • Declarative Shadow DOM изоляция (Web Standards)       │
│  • Scoped-режим для массовых островов (Stencil)           │
├─────────────────────────────────────────────────────────┤
│  Доставка:                                               │
│  • Streaming SSR с shell-first (Marko/Fresh)              │
│  • Bot-Aware: buffered для краулеров (Nuxt)              │
│  • Bot-Aware: streaming для пользователей                 │
│  • Fastest-first completion order (Columbo)               │
└─────────────────────────────────────────────────────────┘
```

---

*Документ дополняет INDUSTRY_IDEAS.md и MITIGATION_PLAN.md. Рекомендуется
после spike-проверки перенести выбранные идеи в основной SPEC v3.0.*
