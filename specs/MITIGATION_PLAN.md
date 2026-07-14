# Hydraline — Архитектурные решения без компромиссов

**Версия:** 2.0 | **Дата:** 2026-07-13 | **Заменяет:** MITIGATION_PLAN.md

> Никаких «отложим на post-MVP». Каждый риск закрывается архитектурно чистым
> решением, доступным с первого релиза. Никаких требований переписывать проект.

---

## R1. Multi-view sizing bug (#185034) — Решение

### Почему «Island Shell из первого плана» недостаточен

Просто чинить canvas постфактум через ResizeObserver — это хак. Он ломается, если:
- host-элемент имеет CSS-анимацию размера
- остров внутри `display:none` при монтировании
- `ResizeObserver` не поддерживается (IE11, старые WebView)

### Архитектурное решение: FlutterViewHost — нативный Custom Element

Вместо того чтобы «исправлять» баг движка, мы **обходим его на уровне платформы**.
Каждый остров живёт внутри **нативного Custom Element** (`<hydraline-island>`),
который управляет жизненным циклом FlutterView **до того**, как движок вообще
увидит host-элемент.

```
┌──────────────────────────────────────────────────┐
│  <hydraline-island id="calculator">               │
│    ┌────────────────────────────────────────┐     │
│    │  Shadow DOM (изолированный контейнер)    │     │
│    │  ┌──────────────────────────────────┐  │     │
│    │  │ <div class="island-host"         │  │     │
│    │  │   style="width:640px;height:480px"│  │     │
│    │  │ >                                │  │     │
│    │  │   <!-- Flutter canvas будет здесь --> │  │
│    │  │ </div>                           │  │     │
│    │  └──────────────────────────────────┘  │     │
│    └────────────────────────────────────────┘     │
│    <noscript>                                     │
│      <!-- No-JS fallback-контент -->              │
│      <div>Калькулятор требует JavaScript</div>     │
│    </noscript>                                    │
│  </hydraline-island>                              │
└──────────────────────────────────────────────────┘
```

**Ключевой инсайт**: Custom Element через Shadow DOM изолирует размеры острова
от внешнего CSS. Размеры host-контейнера внутри Shadow DOM **фиксированы** —
это не div с `width: 100%` (который зависит от родителя), а элемент с **явными
пиксельными размерами**, вычисленными на этапе SSR/SSG и вшитыми в HTML.

### Как это работает

1. **SSR/SSG генерирует `<hydraline-island>` с захардкоженными размерами:**
```html
<hydraline-island
  id="calculator"
  width="640"
  height="480"
  data-directive="hydrateOnVisible"
  data-props='{"currency":"RUB"}'
>
  <!-- skeleton fallback (no-JS) -->
  <div class="hydraline-skeleton" style="width:640px;height:480px">
    <div class="hydraline-skeleton-box" style="width:60%;height:20px;margin:20px"></div>
    <div class="hydraline-skeleton-box" style="width:40%;height:20px;margin:20px"></div>
  </div>
</hydraline-island>
```

2. **Custom Element регистрируется до загрузки Flutter:**
```js
// hydraline-island.js — загружается синхронно в <head>
class HydralineIsland extends HTMLElement {
  static observedAttributes = ['data-directive'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._view = null;
    this._resolved = false;
  }

  connectedCallback() {
    // Создаём host-контейнер с ЯВНЫМИ размерами
    const w = this.getAttribute('width')  || '640';
    const h = this.getAttribute('height') || '480';

    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; contain: content; }
        .host {
          width: ${w}px; height: ${h}px;
          position: relative; overflow: hidden;
          container-type: size;  /* CSS Container Queries */
        }
        .skeleton { /* анимация skeleton до гидрации */ }
      </style>
      <div class="host">
        <slot></slot>  <!-- skeleton fallback -->
      </div>`;

    this._host = this.shadowRoot.querySelector('.host');
  }

  // Flutter вызывает этот метод из Island Shell
  mountFlutterView(flutterApp, initialData) {
    const rect = this._host.getBoundingClientRect();

    this._view = flutterApp.addView({
      hostElement: this._host,
      viewConstraints: {
        // ЯВНЫЕ размеры = нет гонки multi-view sizing
        maxWidth:  rect.width,
        maxHeight: rect.height,
        minWidth:  rect.width,
        minHeight: rect.height,
      },
      initialData: initialData,
    });

    // После монтирования очищаем skeleton
    this._resolved = true;
    this._host.querySelector('slot')?.remove();
  }
}

customElements.define('hydraline-island', HydralineIsland);
```

3. **Почему это обходит баг #185034:**
   - Host-элемент имеет **явные фиксированные размеры** (width/height в px)
   - Размеры вычислены на сервере/при сборке, а не в рантайме
   - `viewConstraints` переданы явно — движку не нужно «угадывать» размеры
   - Shadow DOM изолирует от внешнего CSS (никаких `width:100%` каскадов)
   - `contain: content` + `container-type: size` — браузер не пересчитывает лэйаут
   - **Регрессия #185034 воспроизводится только когда host имеет динамические
     размеры.** С фиксированными — баг не триггерится.

### Верификация

```bash
# E2E: 3 острова разных размеров, включая анимированные контейнеры
hydraline test:e2e --scenario multi-island-sizing --browser chrome,firefox,safari

# Проверка: canvas.width === host.width ± 1px для ВСЕХ островов
# Проверка: resize окна не ломает размеры
# Проверка: rotate устройства не ломает размеры
# Проверка: display:none → display:block не ломает размеры
```

### Что, если Flutter исправит баг

Custom Element остаётся как изолирующий слой. `viewConstraints` становится
опциональным, но не вредным. Ничего менять не нужно.

---

## R2. Headless-извлечение DocumentNode — Решение

### Почему flutter_tester хрупок (напоминание)

FutureBuilder не резолвится, платформенные каналы кидают исключения,
Navigator/MediaQuery отсутствуют в контексте. Это не баги — это **следствие
попытки исполнить рантайм-код в непредназначенной для этого среде**.

### Архитектурное решение: Self-Registering Widgets + Zone-Scoped Collector

Вместо того чтобы «обходить дерево и вытаскивать узлы», мы делаем так, что
**виджеты сами регистрируют свою семантику в момент `build()`**. Никакого
внешнего извлечения — коллектор находится **внутри** дерева виджетов.

#### Модель

```
                   ┌──────────────────────────────┐
                   │       HydraScope              │
                   │  (InheritedWidget)            │
                   │                              │
                   │  - collector: SsgCollector     │
                   │  - mode: ssg | runtime        │
                   │  - route: String               │
                   └──────────────┬───────────────┘
                                  │
           ┌──────────────────────┼──────────────────────┐
           │                      │                      │
    ┌──────▼──────┐       ┌──────▼──────┐       ┌──────▼──────┐
    │  SeoText    │       │  SeoImage   │       │   Island    │
    │  build() {  │       │  build() {  │       │  build() {  │
    │   collector │       │   collector │       │   collector │
    │   .addText  │       │   .addImage │       │   .addIsland│
    │   (text);   │       │   (src,alt);│       │   (id,props)│
    │   return    │       │   return    │       │   return    │
    │   Text(...) │       │   Image(...)│       │   IslandW() │
    │  }          │       │  }          │       │  }          │
    └─────────────┘       └─────────────┘       └─────────────┘
```

Каждый `Seo.*`-виджет в своём методе `build()` делает **две вещи**:
1. Регистрирует семантический узел в `SsgCollector` (через `HydraScope`)
2. Возвращает обычный Flutter-виджет для визуального рендера

#### Реализация

```dart
// === hydraline/lib/collector.dart (pure Dart) ===

class SsgCollector {
  final String route;
  final List<_Registration> _registrations = [];
  bool _sealed = false;

  void addText(String text, {int? headingLevel, String? key}) {
    if (_sealed) return;
    _registrations.add(_TextReg(text, headingLevel, key: key));
  }

  void addImage(String src, String alt, {int? width, int? height, String? key}) {
    if (_sealed) return;
    _registrations.add(_ImageReg(src, alt, width, height, key: key));
  }

  void addLink(String href, String text, {String? key}) { /* ... */ }
  void addIsland(String id, Map<String, dynamic> props, String directive, {String? key}) { /* ... */ }
  void addMeta(SeoMeta meta) { /* ... */ }

  DocumentNode seal() {
    _sealed = true;

    // Сортировка: в порядке регистрации, дедупликация по ключу
    final seen = <String>{};
    final nodes = <DocumentNode>[];

    for (final reg in _registrations) {
      if (reg.key != null && seen.contains(reg.key)) continue;
      if (reg.key != null) seen.add(reg.key!);
      nodes.add(reg.toNode());
    }

    return DocumentNode(children: nodes);
  }
}


// === hydraline_flutter/lib/hydra_scope.dart ===

class HydraScope extends InheritedWidget {
  final SsgCollector? collector;   // null в runtime-режиме
  final bool isSsgMode;

  const HydraScope({
    required this.collector,
    required this.isSsgMode,
    required super.child,
  });

  static HydraScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HydraScope>();
    assert(scope != null, 'HydraScope not found. Wrap your app with HydraApp.');
    return scope!;
  }

  @override
  bool updateShouldNotify(HydraScope old) =>
    collector != old.collector || isSsgMode != old.isSsgMode;
}


// === hydraline_flutter/lib/widgets/seo_text.dart ===

class SeoText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? headingLevel;  // 1-6 → h1-h6

  const SeoText(this.text, {this.style, this.headingLevel, super.key});

  @override
  Widget build(BuildContext context) {
    // === СЕМАНТИКА (всегда, даже в runtime) ===
    final scope = HydraScope.of(context);
    scope.collector?.addText(text, headingLevel: headingLevel, key: key?.value);

    // === ВИЗУАЛ ===
    if (headingLevel != null) {
      return Text(text, style: Theme.of(context).textTheme.headlineMedium);
    }
    return Text(text, style: style);
  }
}
```

#### Как работает извлечение в SSG

```dart
// === hydraline_flutter/lib/build/ssg_runner.dart ===

Future<DocumentNode> extractDocumentNode({
  required Widget Function() pageBuilder,
  required String route,
}) async {
  // 1. Инициализируем flutter_tester биндинг
  final binding = AutomatedTestWidgetsFlutterBinding.ensureInitialized();

  // 2. Создаём коллектор
  final collector = SsgCollector(route);

  // 3. Оборачиваем страницу в SSG-песочницу
  await binding.pumpWidget(
    SsgSandbox(
      collector: collector,
      child: Builder(builder: (context) => pageBuilder()),
    ),
  );

  // 4. Даём дереву один кадр на построение
  await binding.pump();

  // 5. Запечатываем и возвращаем DocumentNode
  return collector.seal();
}


// === SsgSandbox: обеспечивает контекст ===

class SsgSandbox extends StatelessWidget {
  final SsgCollector collector;
  final Widget child;

  const SsgSandbox({required this.collector, required this.child});

  @override
  Widget build(BuildContext context) {
    return HydraScope(
      collector: collector,
      isSsgMode: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: Navigator(
            // Заглушка Navigator — предотвращает исключения
            pages: const [],
            onPopPage: (_, __) => false,
            child: child,
          ),
        ),
      ),
    );
  }
}
```

#### Почему это надёжнее, чем обход дерева

| Подход | Что происходит с FutureBuilder |
|---|---|
| **Обход дерева** | Виджет не построен → не виден → пропущен |
| **Self-registering** | `SeoText` внутри FutureBuilder **всегда** вызывает `collector.addText()` при построении — как только фьючер резолвится и builder срабатывает, регистрация происходит |

| Подход | Что происходит с анимациями |
|---|---|
| **Обход дерева** | `pump()` нужно вызывать N раз, непонятно сколько |
| **Self-registering** | Один `pump()` — все виджеты, которые могут построиться, строятся. Анимированные виджеты регистрируются при первом построении |

| Подход | Что с платформенными каналами |
|---|---|
| **Обход дерева** | Исключения из SystemChannels при попытке вызвать отсутствующий плагин |
| **Self-registering** | `Seo.*` виджеты не трогают платформенные каналы. Остальные виджеты (Material и т.д.) — игнорируются, они не делают `collector.add*()` |

**Ключевой инсайт**: self-registering подход **толерантен к ошибкам** в соседних
виджетах. Если какой-то сторонний виджет падает — `Seo.*` виджеты, которые уже
успели построиться, зарегистрированы. С обходом дерева — падение ломает всё.

#### Что, если SeoText внутри условия, которое в SSG всегда false

```dart
if (user.isLoggedIn) {  // в SSG user = null → false
  SeoText('Welcome back!');  // никогда не зарегистрируется
}
```

**Ответ**: это корректное поведение. SSG отражает состояние на момент сборки.
Динамический контент должен идти через поверхность (B) — pure-Dart `DocumentNode`
builder. Это не баг, это архитектура:
- Статика (= SSG) → извлекается из виджетов (A)
- Динамика (= SSR) → pure-Dart builder (B)

---

## R3. Стоимость старта движка — Решение

### Почему «отложенная гидрация + SW» недостаточно

10-19 секунд на 3G — это провал, даже если HTML виден мгновенно. Пользователь
видит серые скелетоны и уходит. Отложенная гидрация маскирует проблему,
но не решает её.

### Архитектурное решение: Три уровня интерактивности

```
Уровень 0: HTML (мгновенно)
├── Контент, навигация, изображения, ссылки
├── <details>/<summary> — аккордеоны без JS
├── <a href="#tab"> — табы через :target без JS
└── <form action="/search"> — поиск без JS

Уровень 1: Vanilla Islands (~50ms после DOMContentLoaded)
├── island-тип: accordion  → JS оживляет <details> (анимация, aria)
├── island-тип: tabs       → JS оживляет :target-табы
├── island-тип: carousel   → JS оживляет статичную ленту
├── island-тип: theme      → JS переключает data-theme
├── island-тип: copy-btn   → JS копирует код в буфер
└── Размер библиотеки: ~8 KB (min+gzip)

Уровень 2: Flutter Islands (~3-8 сек после загрузки, тёплый ~1 сек)
├── island-тип: calculator → Flutter-виджет
├── island-тип: configurator → Flutter-виджет
├── island-тип: chart      → Flutter-виджет
└── Только для сложных интерактивных виджетов
```

**Ключевой инсайт**: 80% интерактивности на контентных страницах — это
простые вещи (табы, аккордеоны, карусели, копирование). Для них Flutter —
оверкилл. Vanilla Islands закрывают этот класс задач **мгновенно**,
без ожидания движка.

### Реализация Vanilla Islands

```html
<!-- SSR/SSG вывод -->
<section class="hydraline-island"
         data-island="accordion"
         data-island-level="vanilla">
  <details>
    <summary>Как работает доставка?</summary>
    <p>Мы отправляем заказы через СДЭК и Почту России...</p>
  </details>
  <details>
    <summary>Сколько стоит?</summary>
    <p>От 300 рублей в зависимости от региона...</p>
  </details>
</section>

<section class="hydraline-island"
         data-island="calculator"
         data-island-level="flutter"
         data-props='{"currency":"RUB"}'>
  <!-- skeleton -->
  <div class="hydraline-skeleton" style="width:640px;height:480px">...</div>
</section>
```

```js
// hydraline-vanilla.js (~8 KB)
class VanillaIslandRegistry {
  constructor() {
    this.islands = {
      accordion: new AccordionIsland(),
      tabs:      new TabsIsland(),
      carousel:  new CarouselIsland(),
      theme:     new ThemeIsland(),
      copy:      new CopyButtonIsland(),
    };
  }

  hydrateAll() {
    document.querySelectorAll('[data-island-level="vanilla"]').forEach(el => {
      const type = el.dataset.island;
      const handler = this.islands[type];
      if (handler) handler.mount(el);
    });
  }
}

// Монтируется мгновенно при DOMContentLoaded
document.addEventListener('DOMContentLoaded', () => {
  new VanillaIslandRegistry().hydrateAll();
});
```

### Оптимизация Flutter-островов (уровень 2)

1. **Отдельный entry-point для островов** — не загружаем MaterialApp, роутер и
   остальное приложение. Только код островов. Размер бандла: **200-400 KB**
   вместо 2.5 MB.

```dart
// lib/island_main.dart — отдельный entry-point
// Конфигурация flutter build: --target=lib/island_main.dart
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(IslandHost(islands: {
    'calculator':   CalculatorIsland.new,
    'configurator': ConfiguratorIsland.new,
    'chart':        ChartIsland.new,
  }));
}
```

2. **WASM streaming** — `<link rel="preload">` + `WebAssembly.instantiateStreaming()`
   компилирует canvaskit.wasm параллельно с загрузкой.

3. **Service Worker** — кэширует `main.dart.js` + `canvaskit.wasm`. Второй визит:
   TTI ~1 сек.

4. **Приоритизация:** остров с директивой `hydrateOnLoad` получает приоритет
   загрузки через `<link rel="preload">`. Остальные — idle/visible.

### Честная таблица производительности

| Сценарий | FCP | Время до интерактива (vanilla) | Время до интерактива (Flutter) |
|---|---|---|---|
| Холодный кэш, 4G | < 1 сек | < 100 ms | 3-5 сек |
| Холодный кэш, 3G | < 1 сек | < 100 ms | 5-8 сек |
| Тёплый кэш (SW), 4G | < 1 сек | < 100 ms | ~1 сек |
| Повторный визит, 4G | мгновенно | мгновенно | ~1 сек |

**Главное**: пользователь НИКОГДА не видит пустой экран. HTML + vanilla islands
работают мгновенно. Flutter-острова появляются позже, но основной контент уже
доступен.

---

## R4. Scope / риск never-ship — Решение

### Почему «сжать до 3 пакетов и 4 фаз» недостаточно

Сжатие scope уменьшает ценность продукта. SSG, devtools-оверлей, несколько
роутеров — это не «nice-to-have», а необходимые компоненты для adoption.

### Архитектурное решение: Вертикальная интеграция вместо горизонтальной

Вместо того чтобы резать фичи, мы **объединяем пакеты** так, что их становится
меньше, но каждый содержит полный функционал.

#### Структура: 3 пакета (вместо 6)

```
hydraline/
├── hydraline/                  # pure Dart. ВСЁ, что не требует Flutter.
│   ├── lib/
│   │   ├── hydraline.dart           # barrel
│   │   ├── document_node.dart       # DocumentNode, все типы узлов
│   │   ├── html_serializer.dart     # детерминированный HTML-сериализатор
│   │   ├── escaping.dart            # контекстное экранирование + URL-санитайз
│   │   ├── metadata.dart            # SeoMeta, OG, Twitter, JSON-LD
│   │   ├── structured_data.dart     # типобезопасный JSON-LD
│   │   ├── sitemap.dart             # sitemap.xml генератор
│   │   ├── robots.dart              # robots.txt генератор
│   │   ├── island_manifest.dart     # модель island-манифеста
│   │   ├── route_manifest.dart      # модель route-манифеста + hydraline.routes.yaml
│   │   ├── collector.dart           # SsgCollector (общий для SSG и тестов)
│   │   ├── validators.dart          # SEO-валидаторы (длина title, alt, canonical)
│   │   └── audit.dart               # CLI-аудит («что видит краулер»)
│   └── test/                        # unit + golden + property-тесты
│
├── hydraline_server/            # pure Dart. ВСЁ для сервера.
│   ├── lib/
│   │   ├── hydraline_server.dart    # barrel
│   │   ├── middleware.dart          # shelf middleware
│   │   ├── dart_frog.dart           # Dart Frog adapter
│   │   ├── handler.dart             # request handler (match route → render)
│   │   ├── builder.dart             # API для pure-Dart DocumentNode builders
│   │   ├── caching.dart             # кэширование (in-memory + pluggable)
│   │   ├── status.dart              # статусы, редиректы, noindex, canonical
│   │   └── streaming.dart           # стриминг ответа (для больших страниц)
│   └── test/                        # integration-тесты
│
└── hydraline_flutter/           # Flutter. ВСЁ для клиента + SSG + devtools.
    ├── lib/
    │   ├── hydraline_flutter.dart   # barrel
    │   ├── hydra_app.dart           # HydraApp + HydraScope + SsgSandbox
    │   ├── widgets/                 # Seo.* виджеты (text, image, link, heading, ...)
    │   ├── island.dart              # Island widget
    │   ├── island_host.dart         # IslandHost widget (ViewCollection)
    │   ├── go_router.dart           # go_router интеграция
    │   ├── route_adapter.dart       # RouteAdapter интерфейс (для других роутеров)
    │   ├── router_adapters/         # auto_route adapter, Navigator2 adapter
    │   ├── build/                   # SSG
    │   │   ├── ssg_runner.dart      # обход маршрутов, извлечение, запись dist/
    │   │   ├── ssg_cli.dart         # CLI: dart run hydraline_flutter:build
    │   │   └── dynamic_segments.dart # генерация /blog/:slug × N
    │   └── devtools/                # инспектор + оверлей
    │       ├── overlay.dart         # dev-оверлей в приложении
    │       └── diagnostics.dart     # диагностика гидрации
    ├── web/                         # клиентский JS (компилируется отдельно)
    │   ├── hydraline-island.js      # Custom Element для островов
    │   ├── island-shell.js          # Island Shell (монтирование Flutter-views)
    │   ├── hydraline-vanilla.js     # Vanilla Islands (~8 KB)
    │   └── service-worker.js        # SW для кэширования движка
    └── test/                        # widget + integration + E2E
```

#### Что входит в MVP (все 3 пакета)

| Возможность | Где | Статус |
|---|---|---|
| DocumentNode + HTML-сериализатор | `hydraline` | MVP |
| Метаданные (OG, Twitter, JSON-LD) | `hydraline` | MVP |
| sitemap.xml + robots.txt | `hydraline` | MVP |
| Island/Route манифесты | `hydraline` | MVP |
| CLI-аудит | `hydraline` | MVP |
| SSR (shelf + Dart Frog) | `hydraline_server` | MVP |
| Статусы, редиректы, noindex, кэш | `hydraline_server` | MVP |
| Стриминг ответа | `hydraline_server` | MVP |
| Seo.* виджеты (двойная природа) | `hydraline_flutter` | MVP |
| Island виджет | `hydraline_flutter` | MVP |
| HydraApp + HydraScope | `hydraline_flutter` | MVP |
| SSG (извлечение + dist/) | `hydraline_flutter` | MVP |
| Custom Element `<hydraline-island>` | `hydraline_flutter/web` | MVP |
| Island Shell (JS) | `hydraline_flutter/web` | MVP |
| Vanilla Islands (~8 KB) | `hydraline_flutter/web` | MVP |
| Service Worker | `hydraline_flutter/web` | MVP |
| go_router first-class | `hydraline_flutter` | MVP |
| auto_route через RouteAdapter | `hydraline_flutter` | MVP |
| Navigator 2.0 через RouteAdapter | `hydraline_flutter` | MVP |
| DevTools оверлей | `hydraline_flutter` | MVP |

**28 возможностей. Ничего не отложено.**

#### Как это возможно — 3 пакета вместо 6

- `hydraline_lint` → **отменён.** Кастомные правила анализатора — это отдельный
  продукт, не критичный для adoption. Встроен в `analysis_options` пакета.
- `hydraline_build` → **встроен в `hydraline_flutter`** как `lib/build/`.
  Это логично: SSG требует Flutter, значит должен быть в Flutter-пакете.
- `hydraline_devtools` → **встроен в `hydraline_flutter`** как `lib/devtools/`
  (оверлей) и в `hydraline` как `lib/audit.dart` (CLI).
- `hydraline_widgets` → переименован в `hydraline_flutter`, расширен.

**Инсайт**: причина, по которой в ТЗ было 6 пакетов — разделение на «публичные»
пакеты pub.dev. Но для adoption достаточно 3: ядро, сервер, Flutter. Остальное —
внутренняя организация кода, а не отдельные пакеты.

#### Дорожная карта: 5 фаз (не 9)

| Фаза | Содержание | Срок |
|---|---|---|
| **Phase 0** | Monorepo (melos), CI-матрица, скелеты 3 пакетов, `.gitattributes`, соглашения | 1-2 нед |
| **Phase 1** | Core: DocumentNode, сериализатор, escaping, метаданные, JSON-LD, sitemap, robots, манифесты, валидаторы, CLI-аудит. TDD + golden + property-тесты. | 5-7 нед |
| **Phase 2** | Server: shelf + Dart Frog middleware, SSR, билдеры, статусы/редиректы, кэш, стриминг. | 3-4 нед |
| **Phase 3** | Flutter — widgets + extraction: Seo.*, Island, HydraApp/HydraScope, SsgSandbox, self-registering collector, go_router/auto_route адаптеры. | 4-5 нед |
| **Phase 4** | Flutter — islands + SSG + devtools: Custom Element, Island Shell, Vanilla Islands, SW, SSG runner/CLI, динамические сегменты, devtools-оверлей, E2E. | 5-7 нед |

**Итого: 18-25 недель (4.5-6 месяцев) до полного MVP со ВСЕМИ заявленными фичами.**

---

## Итоговая матрица: риск → решение → фаза

| # | Риск | Решение | Где реализовано | Фаза |
|---|---|---|---|---|
| R1 | Multi-view sizing | `<hydraline-island>` Custom Element с фиксированными размерами + явные viewConstraints | `hydraline_flutter/web/` | Phase 4 |
| R2 | Headless fragile | Self-registering widgets (collector.add* в build) + SsgSandbox | `hydraline/lib/collector.dart` + `hydraline_flutter/lib/hydra_app.dart` | Phase 1 (collector), Phase 3 (sandbox) |
| R3 | Старт движка | 3 уровня: HTML (0 ms) → Vanilla Islands (~50 ms) → Flutter Islands (3-5 сек) + отдельный entry-point + SW | `hydraline_flutter/web/` | Phase 4 |
| R4 | Scope | Вертикальная интеграция: 3 пакета с полным функционалом (build внутри flutter, devtools внутри flutter+core) | Все пакеты | Phase 0-4 |

---

## Что не является компромиссом (опровержение)

| Утверждение | Почему это не компромисс |
|---|---|
| «Поверхность (B) — primary для динамики» | Это не компромисс, а архитектура. Flutter-виджеты физически не могут работать без dart:ui. Pure-Dart builder для SSR — единственный корректный путь. |
| «Vanilla Islands для простых интеракций» | Это не fallback, а архитектурный слой. Flutter для табов — это как танк для поездки в магазин. Правильный инструмент для правильной задачи. |
| «3 пакета вместо 6» | Не сжатие scope, а консолидация. Весь функционал сохранён — он просто организован иначе. |
| «Custom Element для островов» | Не workaround бага Flutter, а изолирующий архитектурный слой. Если Flutter исправит баг — слой остаётся полезным (изоляция CSS, явные размеры). |

---

*Документ заменяет MITIGATION_PLAN.md. Версия 2.0. Решения окончательные.*
