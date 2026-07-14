# Hydraline — Архитектурный документ (Level 1)

| Поле | Значение |
|---|---|
| Статус | Draft к реализации |
| Базируется на | `HYDRALINE_SPEC_V3.md` v3.6 |
| Назначение | Мост между ТЗ и кодом: контракты, границы, протоколы, инварианты, нейминг |
| Уровни обязательности | **ДОЛЖНО** / **СЛЕДУЕТ** / **МОЖЕТ** (RFC 2119) |
| Аудитория | Разработчики пакетов, ревьюеры, авторы планов фаз |

> Этот документ фиксирует **что** строится и **как оно связано**, до написания
> кода. Сигнатуры ниже — контракты (форма API), а не реализация. Полные
> сигнатуры публичного API — уровень 4 (`api/` в каждом пакете).

---

## 0. Навигация

- **§1** — Обзор системы и границы
- **§2** — Топология пакетов и модулей
- **§3** — Правила зависимостей (проверяемые CI)
- **§4** — Модель `DocumentNode` (типы узлов, инварианты, пример)
- **§5** — Контракт безопасности (escaping/санитайз)
- **§6** — HTML-сериализатор (три режима)
- **§7** — Метаданные, JSON-LD, sitemap/robots
- **§8** — Протоколы: route-манифест, island-манифест, `data-state`
- **§9** — Две поверхности авторинга и `SsgCollector`
- **§10** — Сервер: middleware, SSR, HTMX, bot-aware доставка
- **§11** — Flutter: виджеты, IslandHost, SSG-раннер
- **§12** — Клиентский рантайм (JS): Custom Element, диспетчер, SW
- **§13** — Карта web-ассетов по уровням
- **§14** — Потоки данных (SSG / SSR / HTMX / гидрация)
- **§15** — Ключевые архитектурные инварианты (CI-gates)
- **§16** — Глоссарий имён (файлы/классы)
- **§17** — Матрица трассируемости (спека → модуль)

---

## 1. Обзор системы и границы

Hydraline — набор из **трёх Dart/Flutter-пакетов**, дающих Flutter Web-приложению
настоящий семантический HTML в первом HTTP-ответе + гидрацию интерактивных зон
(островов) поверх, без переписывания приложения и без превращения в фреймворк.

**Три поверхности вывода:**
1. **Уровень 0** — статический семантический HTML (без JS).
2. **Уровень 1** — vanilla-острова (~8 KB JS) + HTMX-острова (~14 KB), без Flutter.
3. **Уровень 2** — Flutter-острова (CanvasKit, multi-view), движок грузится по триггеру.

**Границы (что система НЕ делает):** не фреймворк, не владеет `main()`,
не конвертирует произвольные виджеты в HTML, не cloaking, не ORM/CMS,
не исполняет Flutter-виджеты на сервере.

```
┌──────────────────────────────────────────────────────────────┐
│                     Приложение разработчика                     │
│   (существующее Flutter Web app + опц. Dart-сервер shelf/Frog)   │
└──────────────────────────────────────────────────────────────┘
              │ подключает как библиотеки (аддитивно)
              ▼
┌───────────────────┐   ┌────────────────────┐   ┌───────────────────────┐
│  hydraline (core)  │◄──│  hydraline_server   │   │   hydraline_flutter    │
│  pure Dart         │   │  pure server Dart   │──►│   Flutter + JS-ассеты   │
│  модель+сериализ.  │   │  SSR/HTMX/доставка  │   │   виджеты+SSG+острова    │
└───────────────────┘   └────────────────────┘   └───────────────────────┘
        ▲                                                   │
        └───────────────────────────────────────────────────┘
                      все сходятся к DocumentNode
```

---

## 2. Топология пакетов и модулей

### 2.1 `hydraline` (core) — pure Dart, без `dart:ui`

| Модуль | Ответственность | Спека |
|---|---|---|
| `document_node.dart` | Дерево `DocumentNode` + все типы узлов | C-1 |
| `escaping.dart` | Контекстное экранирование + `SafeUrl`/санитайз | C-5 |
| `html_serializer.dart` | Single-pass сериализатор (3 режима) | C-4 |
| `metadata.dart` | `SeoMeta`, OG, Twitter, `<meta>`/`<link>` | C-2 |
| `structured_data.dart` | Типобезопасный JSON-LD | C-3 |
| `sitemap.dart` | `sitemap.xml` + `SitemapSource` + автосплит | C-6 |
| `robots.dart` | `robots.txt` | C-6 |
| `island_manifest.dart` | Сериализация/десериализация island-манифеста | C-7 |
| `route_manifest.dart` | Модель + парсер `hydraline.routes.yaml` + Dart-builder | C-8 |
| `collector.dart` | `SsgCollector` (pure-Dart, инстанс-скопированный) | C-9 |
| `validators.dart` | SEO-валидаторы | C-10 |
| `audit.dart` | CLI-аудит (standalone + server-integration) | C-11 |
| `assets/` | Standalone web-ассеты L0–L1 (vanilla ~8 KB, HTMX-glue) как файлы/строки | C-12 |

### 2.2 `hydraline_server` — pure server Dart, без `flutter`

| Модуль | Ответственность | Спека |
|---|---|---|
| `middleware.dart` | shelf-middleware | S-1 |
| `dart_frog.dart` | Адаптер Dart Frog | S-1 |
| `handler.dart` | Матч маршрута → рендер (document/hybrid/app) | S-2 |
| `builder.dart` | Контракт `DocumentNode` builder (UA-слепой) | S-3 |
| `streaming.dart` | Single-pass in-order стриминг (прогрессивный flush) | S-4 |
| `delivery.dart` | Bot-aware транспорт (buffered/chunked), инвариант тела | S-5 |
| `htmx.dart` | `renderFragment()`, `HtmxResponse`, `HtmxTrigger` | S-6 |
| `http_semantics.dart` | Статусы, редиректы, `X-Robots-Tag`, канонизация | S-7 |
| `caching.dart` | `Cache-Control`/`ETag`, TTL, pluggable-кэш | S-8 |
| `assets_handler.dart` | Отдача sitemap/robots + L0–L1 ассетов из core | S-9 |
| `flutter_assets.dart` | Встраивание island-манифеста + абсолютные пути к движку | S-10 |

### 2.3 `hydraline_flutter` — Flutter + JS-ассеты (L2)

| Модуль | Ответственность | Спека |
|---|---|---|
| `hydra_app.dart` | `HydraApp` + `HydraScope` (InheritedWidget) | W-3 |
| `ssg_sandbox.dart` | `SsgSandbox` (заглушки MediaQuery/Navigator/Directionality) | W-4 |
| `widgets/seo_*.dart` | `Seo.*`-виджеты (двойная природа) | W-1 |
| `island.dart` | `Island(...)` виджет + `IslandType`/`IslandRenderMode`/`IslandStyleMode` | W-2 |
| `island_host.dart` | `IslandHost` (`runWidget`+`ViewCollection`), фабрики островов | W-6, W-7 |
| `routing/go_router.dart` | First-class адаптер `go_router` | W-5 |
| `routing/route_adapter.dart` | Интерфейс `RouteAdapter` + `Navigator2Adapter` | W-5 |
| `build/ssg_runner.dart` | Обход манифеста, извлечение, запись `dist/`, копирование ассетов | W-14 |
| `build/dynamic_segments.dart` | Генерация `/blog/:slug` × N | W-15 |
| `build/ssg_cli.dart` | CLI `dart run hydraline_flutter:build` (через flutter_tester) | W-16 |
| `devtools/overlay.dart` | Dev-оверлей островов | W-18 |
| `devtools/diagnostics.dart` | Диагностика гидрации, SSG↔DOM сверка | W-19 |
| `web/hydraline-island.js` | Custom Element `<hydraline-island>` (DSD) | W-8 |
| `web/hydraline-dispatcher.js` | Диспетчер гидрации (Qwikloader-style) | W-9 |
| `web/hydraline-virtual.js` | Virtual views (deferred) | W-13 |
| `web/service-worker.js` | Кэш движка + WASM streaming | W-11 |
| `lib/island_main.dart` | Отдельный island entry-point (шаблон) | W-7 |

---

## 3. Правила зависимостей (проверяемые CI)

```
hydraline (core)  ──► НЕ импортирует flutter, dart:ui, dart:html
hydraline_server  ──► импортирует hydraline; НЕ импортирует flutter, dart:ui
hydraline_flutter ──► импортирует hydraline (+ flutter); переиспользует core-ассеты
```

**Инвариант D1 (ДОЛЖНО, блокирующий CI):**
- В `hydraline/lib/**` запрещены импорты `package:flutter/*`, `dart:ui`, `dart:html`.
- В `hydraline_server/lib/**` запрещён импорт `package:flutter/*`.
- Нарушение → fail пайплайна (статический скан импортов в Phase 0).

**Следствие (R9):** сервер физически не может исполнять Flutter-виджеты — это
не ограничение, а корректная модель (см. §14).

---

## 4. Модель `DocumentNode`

### 4.1 Иерархия типов (Phase 1, ДОЛЖНО)

```
DocumentNode (sealed, immutable)
├── DocumentRootNode            корень
├── HeadNode                    контейнер метаданных
│   ├── MetaNode
│   ├── LinkNode (rel/href)
│   └── TitleNode
├── Блочные:
│   ├── HeadingNode (level 1..6)
│   ├── ParagraphNode
│   ├── SectionNode (role: SectionRole = section|article|nav|header|footer|main)
│   ├── ListNode (ordered: bool) → ListItemNode
│   ├── BlockquoteNode
│   ├── PreNode / CodeNode
│   ├── TableNode → TableRowNode → TableCellNode (header: bool)
│   └── DetailsNode → SummaryNode
├── Инлайн:
│   ├── TextNode (всегда экранируется)
│   ├── AnchorNode (href: SafeUrl)
│   ├── ImageNode (src: SafeUrl, alt, width?, height?)
│   └── TimeNode (dateTime)
├── Острова:
│   ├── IslandPlaceholderNode (Flutter-остров)
│   ├── HtmxIslandNode (endpoint, trigger, target, swap)
│   └── VanillaIslandNode (kind, config)
└── UnsafeHtmlNode (opt-in, sanitizer?)      ← единственный сырой HTML
```

**Post-MVP (СЛЕДУЕТ, Phase 5+):** `FigureNode`/`FigcaptionNode`, расширенные
таблицы (colspan/rowspan, caption, colgroup). **Никогда (по дизайну):**
`iframe`/`script`/`video`/`audio`/CSS-узлы — только через `UnsafeHtmlNode`.

### 4.2 Контракт узла

```dart
sealed class DocumentNode {
  const DocumentNode();
  /// Дочерние узлы (пустой список для листьев). N5: без циклов.
  List<DocumentNode> get children;
}
```

Иерархия **закрытая** (`sealed`), поэтому сериализатор обходит дерево
**исчерпывающим `switch`** по типу узла (Dart 3, компилятор проверяет полноту),
**без внешнего visitor'а** и без возврата строк — пишет напрямую в `Sink<String>`
(SER1). Новый тип узла → ошибка компиляции во всех `switch` до его обработки.

**Инварианты (ДОЛЖНО):**
- **N1.** Узлы иммутабельны (`const`-конструируемы где возможно).
- **N2.** `TextNode` хранит сырой текст; экранирование — только на сериализации.
- **N3.** `AnchorNode`/`ImageNode` принимают только `SafeUrl` (см. §5) — нельзя
  сконструировать с непроверенным URL.
- **N4.** Дерево детерминировано: один и тот же вход → идентичный граф → идентичный HTML.
- **N5.** Нет циклов (дерево, не граф); проверяется на этапе `seal()` коллектора.

### 4.3 Пример графа (карточка товара, hybrid)

```dart
DocumentRootNode(
  head: HeadNode(children: [
    TitleNode('iPhone 15 — Магазин'),
    MetaNode(name: 'description', content: 'Смартфон Apple iPhone 15, 128 ГБ'),
    MetaNode(property: 'og:title', content: 'iPhone 15'),
    MetaNode(property: 'og:image', content: '/img/iphone15.jpg'),
  ]),
  body: [
    SectionNode(role: SectionRole.main, children: [
      HeadingNode(level: 1, children: [TextNode('iPhone 15')]),
      ParagraphNode(children: [TextNode('Описание товара...')]),
      ImageNode(src: SafeUrl.parse('/img/iphone15.jpg'), alt: 'iPhone 15'),
      IslandPlaceholderNode(              // Flutter-остров (уровень 2)
        id: 'calculator',
        directive: HydrationDirective.onVisible,
        renderMode: IslandRenderMode.ssr,
        size: IslandSize(width: 640, height: 480),
        state: {'price': 89990, 'currency': 'RUB'},
      ),
      HtmxIslandNode(                     // HTMX-остров (уровень 1)
        id: 'reviews',
        endpoint: '/api/reviews/iphone15',
        trigger: 'load',
        swap: 'innerHTML',
      ),
    ]),
  ],
)
```

---

## 5. Контракт безопасности (`escaping.dart`)

```dart
String escapeHtmlText(String s);        // < > &  → сущности
String escapeHtmlAttribute(String s);   // " ' < > & → сущности

abstract interface class SafeUrl {       // конструируется ТОЛЬКО через санитайз
  String get value;
  static SafeUrl? tryParse(String raw);  // null если схема запрещена
  static SafeUrl parse(String raw);      // бросает UnsafeUrlException при запрете
}                                        // публичного конструктора НЕТ (N3/S1)
```

**Инварианты (ДОЛЖНО, R5):**
- **S1.** Allowlist схем: `http`, `https`, `mailto`, `tel`, относительные (`/`, `./`).
  Блок: `javascript:`, `data:`, `vbscript:`.
- **S2.** `TextNode`/атрибуты не могут попасть в вывод неэкранированными —
  сериализатор всегда применяет контекстную функцию.
- **S3.** `UnsafeHtmlNode` — единственный обход; имя содержит «Unsafe»; валидатор
  предупреждает при отсутствии переданного санитайзера.
- **S4.** Property/fuzz: 0 XSS на 10^6 входов, 0 падений за 60 с фаззинга.
- **S5.** CSP-helper эмитит `script-src 'self' 'wasm-unsafe-eval'` (без `unsafe-inline`).

---

## 6. HTML-сериализатор (`html_serializer.dart`)

```dart
class HtmlSerializer {
  const HtmlSerializer({this.pretty = false});

  /// Буферизованный HTML (для ботов / SSG-файла).
  String serialize(DocumentNode root);

  /// Потоковый in-order (для SSR streaming, прогрессивный flush).
  Stream<String> serializeToStream(DocumentNode root);

  /// Фрагмент без <html>/<head> (для HTMX-ответов).
  String serializeFragment(DocumentNode node);
}
```

**Инварианты (ДОЛЖНО):**
- **SER1. Single-pass:** обход дерева ровно один раз, запись в `Sink<String>`/
  `StringBuffer`; без промежуточного строкового дерева/VDOM.
- **SER2. Детерминизм:** стабильный порядок атрибутов, предсказуемый вывод
  (golden-тесты).
- **SER3. Сложность** O(число узлов + суммарная длина текста); без квадратичной
  конкатенации.
- **SER4. Идентичность тела:** `serialize(root)` побайтово равен конкатенации
  `serializeToStream(root)` на одном и том же входе (основа §15 инварианта I3).
- **SER5. Нормализация переносов:** вывод всегда `\n` независимо от ОС (R8).

---

## 7. Метаданные, JSON-LD, sitemap/robots

### 7.1 Метаданные (`metadata.dart`)
`SeoMeta`: `title`, `description`, `canonical: SafeUrl`, `robots`,
Open Graph (полный набор), Twitter Card (`summary`/`summary_large_image`),
произвольные `<meta>`/`<link>`, `charset`, `viewport`, `lang`, `hreflang[]`.

### 7.2 JSON-LD (`structured_data.dart`)
Типобезопасные билдеры: `Article`, `Product`, `BreadcrumbList`, `WebPage`,
`Organization`, `FAQPage` (метод `JsonLd.faq`), `Event`, `Recipe`, `Review` + произвольная схема (`JsonLd.raw`).
Вывод: `<script type="application/ld+json">`.

### 7.3 Sitemap/robots (`sitemap.dart`, `robots.dart`)
```dart
abstract class SitemapSource {
  Stream<SitemapEntry> entries();      // (a) из route-манифеста | (b) async-провайдер
}
```
**Инвариант SM1 (ДОЛЖНО):** автосплит в `sitemap-index` при > 50 000 URL или > 50 MB.

---

## 8. Протоколы (границы сериализации)

### 8.1 Route-манифест — `hydraline.routes.yaml` (primary)

```yaml
routes:
  - path: /
    mode: document                 # app | document | hybrid
    metadata: { title: Home, description: "..." }
    content_source: widget         # widget | widget:HomeBuilder | dart_builder:HomeBuilder.new
  - path: /blog/:slug
    mode: document
    content_source: dart_builder:BlogPostBuilder.new
    dynamic_segments: { slug: [post-1, post-2] }   # только SSG
  - path: /app/dashboard
    mode: app                      # noindex + исключён из sitemap по умолчанию
```
Dart-builder API (`route_manifest.dart`) — опциональный генератор того же YAML.
**Инвариант RM1:** YAML читается сервером и SSG-раннером; один источник правды.

### 8.2 Island-манифест
Поля: `id`, `type` (`flutter`/`vanilla`/`htmx`), `mountSelector`, `state` (JSON-safe),
`directive`, `size` (px, anti-CLS), `renderMode`, `styleMode`. Встраивается в HTML
и потребляется диспетчером.

### 8.3 `data-state` — контракт props (сервер → HTML → клиент)

**Инварианты (ДОЛЖНО, §7.8 спеки):**
- **DS1.** Сериализация `JSON.stringify` + HTML-escape атрибута; на клиенте `JSON.parse`.
  Никакого `eval`/`Function`/`DOMParser`.
- **DS2.** Типы: `String`/`int`/`double`/`bool`/`null`/`List`/`Map<String,dynamic>`.
  Запрещены: функции, `DateTime` (→ ISO-строка), `Uri` (→ строка), циклы, `Symbol`.
- **DS3. Детерминизм:** запрещены `DateTime.now()`/`random()` в момент рендера (R6).
- **DS4. Лимит** ~10 KB/остров; devtools предупреждает при превышении.
- **DS5.** Приём на Dart-стороне: `IslandProps.of(view)` — типобезопасная десериализация.

---

## 9. Две поверхности авторинга и `SsgCollector`

```
(A) Flutter-виджеты (self-registering)      (B) Pure-Dart билдер
    Seo.text/image/link/Island                  Document.of(children: [...])
        │ build() → collector.add*()                    │ напрямую
        ▼                                                ▼
   flutter_tester (dart:ui) → SsgCollector → DocumentNode ◄─────┘
```

```dart
class SsgCollector {                        // pure Dart, инстанс-скопированный
  SsgCollector(this.route);
  void addText(String text, {int? headingLevel, String? key});
  void addImage(SafeUrl src, String alt, {int? width, int? height, String? key});
  void addLink(SafeUrl href, String text, {String? key});
  void addIsland(IslandSpec spec, {String? key});   // id — внутри IslandSpec
  void addMeta(SeoMeta meta);
  DocumentNode seal();                       // dedup по key, иммутабельный, N5-проверка
}
```

**Инварианты (ДОЛЖНО):**
- **CO1.** Отдельный инстанс коллектора на прогон извлечения (изоляция параллельных).
- **CO2.** Доступ из виджетов — только через `HydraScope` (InheritedWidget).
- **CO3.** Обе поверхности дают **идентичный** `DocumentNode` (golden-сверка A↔B, R2).
- **CO4.** После `seal()` коллектор иммутабелен (повторные `add*` игнорируются).

---

## 10. Сервер: middleware, SSR, HTMX, bot-aware доставка

### 10.1 Контракт билдера (UA-слепой)
```dart
typedef DocumentBuilder = FutureOr<DocumentNode> Function(Request req, Object? data);
// Сигнатура НЕ содержит User-Agent — архитектурный запрет cloaking (R7).
```

### 10.2 Двухслойность контента и транспорта (§6.5 спеки)
```
Слой контента (UA-СЛЕПОЙ):   builder(req,data) → DocumentNode → HTML  (детерминирован)
Слой транспорта (МОЖЕТ UA):  бот → buffered (Content-Length)
                             юзер → chunked (Transfer-Encoding)  ← тот же байтовый поток
```

**Инварианты (ДОЛЖНО):**
- **SRV1.** Билдер контента не получает и не читает `User-Agent`.
- **SRV2.** `bytes(buffered) == bytes(concat(chunks))` на детерм. входе (проверка A8).
- **SRV3.** MVP-стриминг **in-order** (без переупорядочивания); out-of-order/DPU — post-MVP.
- **SRV4.** `app`-маршрут: app-shell + `noindex` + исключён из sitemap по умолчанию.

### 10.3 HTMX
`serializeFragment()` → HTML без `<html>/<head>`; хелперы `HtmxResponse`/`HtmxTrigger`;
HTMX-скрипт вендорится как first-party из core (совместимо с CSP `script-src 'self'`).

---

## 11. Flutter: виджеты, IslandHost, SSG-раннер

### 11.1 Виджеты
```dart
class Island extends StatelessWidget {
  const Island({
    required this.id,
    required this.type,            // IslandType.flutter | vanilla | htmx
    this.props = const {},
    this.directive = HydrationDirective.onIdle,   // дефолт
    this.renderMode = IslandRenderMode.ssr,       // | skeletonOnly
    this.styleMode = IslandStyleMode.shadow,      // | scoped
    this.size,                     // px, anti-CLS
    this.placeholder,
    this.errorFallback,
  });
}
```

### 11.2 IslandHost (Dart-контрагент JS-диспетчера)
```dart
class IslandHost extends StatelessWidget {       // runWidget + ViewCollection
  const IslandHost({required this.factories});
  final Map<String, Future<Widget> Function(Map<String, dynamic> props)> factories;
}
```
**Инвариант IH1 (ДОЛЖНО):** одна инстанция движка на страницу — N views (§7.5).
Каждый `FlutterView` из `addView()` мапится на остров по `id` из `initialData`.

### 11.3 SSG-раннер (`build/ssg_runner.dart`, CLI W-16)
**Инвариант SSG1 (ДОЛЖНО):** извлечение требует `dart:ui` → раннер исполняется
**внутри `flutter test`-харнесса** (`flutter test --tags ssg`) или как
Flutter-скомпилированный executable (`AutomatedTestWidgetsFlutterBinding
.ensureInitialized()`). CLI `dart run hydraline_flutter:build` инкапсулирует это;
запуск в pure-Dart окружении невозможен.
**Инвариант SSG2:** раннер — **единственный** ответственный за копирование
island-бандла + `web/`-ассетов в `dist/` при SSG (только если есть `IslandType.flutter`).
**Инвариант SSG3:** вывод детерминирован (стабильные пути/порядок).

---

## 12. Клиентский рантайм (JS, `hydraline_flutter/web/`)

### 12.1 Custom Element `<hydraline-island>` (W-8)
- Declarative Shadow DOM (использует существующий Shadow Root из HTML — нет FOUC).
- Фиксированные px-размеры + явные `viewConstraints` при `addView()` → обход #185034.
- `ResizeObserver`-корректор: pinned `min==max`, rAF-коалесинг по всем view, debounce,
  no-op на Flutter 3.41.x.
- Режимы: `shadow` (дефолт) | `scoped` (стили один раз в `<head>` при массовых островах).

### 12.2 Диспетчер (W-9, Qwikloader-style, ≤ 2 KB)
- Один `IntersectionObserver` (все `onVisible`), один `requestIdleCallback` (все `onIdle`),
  одно делегирование событий (`onInteraction`), `matchMedia` (`onMedia`).
- Грузит Flutter-движок только при первом триггере любого острова.
- Глобальный API `window.hydraline.hydrate(id)` / `hydrateAll()` (для `hydrateManual`,
  работает без запущенного `MaterialApp`).
- Состояния host-элемента: `data-hydration = pending|hydrating|hydrated|failed`.
- Ошибки: тайм-аут + ограниченный retry; при терминальном сбое — fallback остаётся
  видимым, событие `hydraline:island-error`.

### 12.3 Service Worker (W-11, ≤ 2 KB)
Кэш `main.dart.js` + `canvaskit.wasm`; прогрев `WebAssembly.instantiateStreaming()` +
`<link rel="preload">`. Тёплый визит: TTI ~1 с.

---

## 13. Карта web-ассетов по уровням

| Уровень | Ассет | Пакет | Flutter? | JS-бюджет (min+gzip) |
|---|---|---|---|---|
| 0 | Статический HTML, DSD-скелетоны | `hydraline` (сериализатор) | Нет | 0 |
| 1 | Vanilla islands | `hydraline/assets` | Нет | ≤ 8 KB |
| 1 | HTMX (vendored) + glue | `hydraline/assets` | Нет | ~14 KB (по наличию) |
| 2 | Custom Element | `hydraline_flutter/web` | Да | ≤ 2 KB |
| 2 | Диспетчер | `hydraline_flutter/web` | Да | ≤ 2 KB |
| 2 | Service Worker | `hydraline_flutter/web` | Да | ≤ 2 KB |
| 2 | Virtual-views (deferred) | `hydraline_flutter/web` | Да | ≤ 2 KB (по наличию) |
| 2 | Island JS-бандл (`main.dart.js` entry + `IslandHost`) | сборка W-7 | Да | ≈ 450 KB (без wasm/deferred) |

**Инвариант AS1 (ДОЛЖНО, P8/W-12):** нет `IslandType.flutter` на странице →
`flutter_bootstrap.js` не вставляется, базовый L2-JS не грузится. `hydraline_flutter`
не дублирует L1-ассеты — ссылается на core-бандл.

---

## 14. Потоки данных

### 14.1 SSG
```
[есть Flutter-острова] flutter build web --target=lib/island_main.dart → build/web/
route-манифест → SsgCollector (во flutter_tester) → DocumentNode → serialize()
  → dist/**.html + sitemap.xml + robots.txt + island-манифесты
  → W-14 копирует island-бандл + web/-ассеты в dist/  (единственный ответственный)
  → деплой dist/ на статик-хостинг
```

### 14.2 SSR
```
запрос → middleware → match route
  document/hybrid → builder(req,data) → DocumentNode → serializeToStream() (in-order)
  app → app-shell
  → бот: buffered | юзер: chunked  (тело идентично, §6.5)
```

### 14.3 HTMX
```
hx-get/post → handler → builder(data) → serializeFragment() → HTML-фрагмент
  → HTMX заменяет DOM (без перезагрузки, без Flutter-движка)
```

### 14.4 Гидрация (браузер)
```
HTML с <hydraline-island> (DSD, data-state) → диспетчер ждёт триггер по директиве
  → грузит движок (1 раз) → addView({hostElement, viewConstraints, initialData})
  → IslandHost мапит view→остров по id → возобновление из data-state (без пересчёта)
```

---

## 15. Ключевые архитектурные инварианты (CI-gates)

| # | Инвариант | Где проверяется | Спека |
|---|---|---|---|
| I1 | core без flutter/dart:ui; server без flutter | статический скан импортов (Phase 0) | D1, R9 |
| I2 | 0 XSS на 10^6 входов; 0 падений за 60 с фаззинга | property/fuzz (Phase 1) | S4, R5 |
| I3 | `bytes(buffered)==bytes(concat(chunks))` | integration + аудит A8 (Phase 2) | SRV2, R7 |
| I4 | Детерминированный HTML | golden-тесты (Phase 1) | SER2 |
| I5 | `DocumentNode` A↔B идентичен | golden-сверка (Phase 3) | CO3, R2 |
| I6 | Нет островов → нет `flutter_bootstrap.js` | E2E (Phase 4) | AS1, A9 |
| I7 | `canvas − host ≤ 1px` для всех островов | E2E-sizing (Phase 4) | R1 |
| I8 | CLS ≈ 0 (зарезервированные размеры) | E2E (Phase 4) | NF-3 |
| I9 | Покрытие: core/server ≥ 90%, flutter ≥ 80% | coverage-gate (все фазы) | §15.3 |
| I10 | Golden стабильны на Windows + Linux | CI-матрица (все фазы) | R8 |

---

## 16. Глоссарий имён (фиксируется до кода)

**Пакеты:** `hydraline`, `hydraline_server`, `hydraline_flutter`.

**Публичные типы (core):** `DocumentNode` (+ подтипы §4.1), `SectionRole`, `SafeUrl`, `HtmlSerializer`,
`SeoMeta`, `JsonLd*`-билдеры, `SitemapSource`/`SitemapEntry`, `RouteManifest`/`RouteEntry`,
`ContentSource` (`WidgetContent`/`DartBuilderContent`), `IslandManifest`/`IslandSpec`, `SsgCollector`, `SeoValidator`.

**Публичные типы (server):** `HydralineMiddleware`, `DocumentBuilder`, `HtmxResponse`,
`HtmxTrigger`, `DeliveryMode` (`buffered`/`chunked`), `HydralineCache`.

**Публичные типы (flutter):** `HydraApp`, `HydraScope`, `SsgSandbox`, `Seo` (namespace),
`Island`, `IslandType`, `IslandRenderMode`, `IslandStyleMode`, `HydrationDirective`,
`IslandHost`, `IslandProps`, `RouteAdapter`, `GoRouterAdapter`, `Navigator2Adapter`.

**JS-глобали:** `window.hydraline.hydrate(id)`, `window.hydraline.hydrateAll()`.
**HTML-элементы:** `<hydraline-island>`, `<hydraline-island-segment>`.
**DOM-атрибуты:** `data-directive`, `data-render-mode`, `data-style-mode`, `data-state`,
`data-hydration`, `data-media`, `data-island`, `data-island-level`, `data-virtual`,
`data-offset`, `data-height`.
**DOM-события:** `hydraline:island-error`.
**Файлы-манифесты:** `hydraline.routes.yaml`.

---

## 17. Матрица трассируемости (спека → модуль → инвариант)

| Спека | Модуль | Инвариант | Фаза |
|---|---|---|---|
| C-1 | `document_node.dart` | N1–N5 | 1 |
| C-4 | `html_serializer.dart` | SER1–SER5, I4 | 1 |
| C-5 | `escaping.dart` | S1–S5, I2 | 1 |
| C-6 | `sitemap.dart`/`robots.dart` | SM1 | 1 |
| C-8 | `route_manifest.dart` | RM1 | 0/1 |
| C-9 | `collector.dart` | CO1–CO4, I5 | 1/3 |
| C-11 | `audit.dart` | I3 | 1/2 |
| S-3 | `builder.dart` | SRV1 | 2 |
| S-4/S-5 | `streaming.dart`/`delivery.dart` | SRV2–SRV3, I3 | 2 |
| W-2 | `island.dart` | DS1–DS5 | 3/4 |
| W-6/W-7 | `island_host.dart` | IH1 | 3 |
| W-8/W-9 | `web/*.js` | I6, I7 | 4 |
| W-14/W-16 | `build/ssg_runner.dart` | SSG1–SSG3 | 4 |
| §6.2.1 | карта ассетов §13 | AS1, I6 | 2/4 |

---

*Level 1 завершён. Следующие уровни: `DEVELOPMENT.md` (L2), `PHASE_*_PLAN.md` (L3),
`api/` контракты в каждом пакете (L4). Изменения архитектуры — через версионирование
этого файла + синхронизацию с `HYDRALINE_SPEC_V3.md`.*
