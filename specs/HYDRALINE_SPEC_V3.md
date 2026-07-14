# Hydraline v3.6 — Итоговое техническое задание

**SEO / SSR / prerender + islands для Flutter Web**

| Поле | Значение |
|---|---|
| Кодовое имя | `hydraline` |
| Версия ТЗ | 3.6 (final — устранены нейминг-рассинхроны спека↔API: `AnchorNode`/`LinkNode`, `SectionRole`, `content_source: widget`, `JsonLd.faq`; уточнено окно версий Flutter в NF-5) |
| Статус | Утверждено к декомпозиции на фазы |
| Базируется на | SPEC v1.0, MITIGATION_PLAN v2.0, RISK_ANALYSIS v1.0, ADR v1.0, INDUSTRY_IDEAS v1.0, ALTERNATIVES_AND_ADJACENT v1.0 |
| Тип продукта | Набор Dart/Flutter пакетов (monorepo, melos + pub workspaces) |
| Целевая платформа | Flutter Web (CanvasKit / Skwasm) + Dart-серверы |
| Среда разработки | Windows 10/11 + WSL2 (Ubuntu) |
| Язык реализации | Dart (без C/C++/FFI/нативных прослоек) |
| Модель работы | Brainstorm → Spike → TDD (red-green-refactor) → полное покрытие |
| Целевой срок MVP | 18–27 недель (5 фаз; оптимистично 18, консервативно 27) |

---

## 0. Навигация по документу

- **§1–3** — Зачем: проблема, цели, позиционирование
- **§4–5** — Что: термины, режимы, модель документа, три уровня интерактивности
- **§6–9** — Как: архитектура, пакеты, поток данных, острова
- **§10–12** — Функциональные требования по пакетам
- **§13** — Нефункциональные требования
- **§14** — Риски и митигация (сводка)
- **§15** — Режим разработки и стратегия тестирования
- **§16** — Дорожная карта фаз
- **§17** — Критерии приёмки
- **§18** — Открытые вопросы (все решены)
- **Приложения** — Глоссарий, источники, история версий

Уровни обязательности: **ДОЛЖНО** (mandatory), **СЛЕДУЕТ** (recommended),
**МОЖЕТ** (optional) — в смысле RFC 2119.

---

## 1. Проблема

### 1.1 Суть

Flutter Web рендерит UI в `<canvas>` через CanvasKit/Skwasm. Первый HTTP-ответ —
пустой app-shell. Реальный контент появляется только после скачивания движка
(1.5–2.5 MB), WASM-бинарника (~1.1 MB) и исполнения Dart-кода.

### 1.2 Кто ломается

- **Соц-краулеры** (Facebook, X/Twitter, LinkedIn, Telegram, WhatsApp, iMessage,
  Slack, Discord) — не исполняют JavaScript. Забирают HTML, ищут `og:*`/`twitter:*`
  теги. Видят пустой shell → превью не строится.
- **Простые парсеры / no-JS среды / аналитические краулеры** — аналогично.
- **Поисковые боты** — Googlebot исполняет JS с задержкой и бюджетом; контент
  индексируется хуже и медленнее.

### 1.3 Почему существующие пакеты не решают

Все делают **runtime DOM-инъекцию** после загрузки Flutter — тегов нет в
`view-source`, соц-боты их не видят. HTML-renderer удалён (#145954).
Firebase Functions + UA-sniff → cloaking → риск санкций.

### 1.4 Позиция Flutter-команды (подтверждено)

- #187663 (route-level document rendering) — открыт, без сроков
- #183992 — «делайте как community package»
- #46789 (610 👍) — «P2 / скоро не будет»

**Дыра свободна.** Нужен community-пакет, совместимый по модели с #187663.

### 1.5 Что отсутствует на рынке

Пакет, который: (1) отдаёт настоящий HTML в первом HTTP-ответе, (2) Flutter
гидрирует интерактивные зоны поверх, (3) не требует переписывания приложения,
(4) не является новым фреймворком.

Ближайший аналог — Jaspr, но это отдельный фреймворк (контент пишется на
Jaspr-компонентах, не на Flutter-виджетах). Spark Framework — то же самое
(Dart SSR, но без Flutter). Trellis — pure-Dart шаблонизатор, не для Flutter.
Все альтернативы требуют выбросить Flutter Web. Hydraline — единственный путь
**сохранить** Flutter-приложение и добавить SEO.

---

## 2. Цели, не-цели, принципы

### 2.1 Цели (Goals)

1. **G1.** Валидный семантический HTML (заголовки, параграфы, ссылки, alt,
   метаданные, JSON-LD) в первом HTTP-ответе для `document`/`hybrid`-маршрутов —
   доступный в `view-source`, без JS.
2. **G2.** Flutter гидрирует интерактивные зоны поверх HTML (islands) через
   multi-view API, не перерисовывая статический контент.
3. **G3.** Не требовать переписывания: `app`-маршруты работают как сейчас;
   SEO-режимы включаются пер-маршрут, аддитивно.
4. **G4.** Полный SEO-инструментарий: метаданные, canonical, OG/Twitter,
   JSON-LD, `sitemap.xml`, `robots.txt`, статус-коды, редиректы, `noindex`,
   hreflang.
5. **G5.** Два пути доставки HTML: build-time SSG и request-time SSR.
6. **G6.** Три уровня интерактивности: статический HTML → vanilla/HTMX-острова
   → Flutter-острова. Flutter-движок загружается только когда реально нужен.
7. **G7.** Инструмент верификации: CLI-аудит «что видит краулер» + dev-оверлей.
8. **G8.** Никакого cloaking: боту и пользователю — семантически идентичный
   контент (побайтово одинаковое тело документа). Разрешена разная **стратегия
   доставки** одного и того же тела: streaming (chunked) для людей, buffered
   (одна порция) для ботов. Различие живёт **только** на транспортном слое и
   **не влияет** на содержимое (см. §6.5, §11 S-5, §14 R7).

### 2.2 Не-цели (Non-Goals)

1. **NG1.** Не фреймворк. Не владеет `main()`, не диктует роутер, не заменяет
   `MaterialApp`. Библиотеки, встраиваемые в существующий проект.
2. **NG2.** Не автоматическая конвертация Flutter-виджетов в HTML/CSS.
   Семантика — явная (developer-controlled).
3. **NG3.** Не возрождение HTML-renderer. CanvasKit/Skwasm остаются визуальным
   рантаймом для app-маршрутов и интерактивных островов.
4. **NG4.** Никаких C/C++/Rust/FFI/WASM-прослоек собственной разработки.
   Только Dart + необходимый минимум JS (Custom Element, диспетчер).
5. **NG5.** Не требует конкретного бэкенда/хостинга.
6. **NG6.** `document`-контент — семантический HTML, а не pixel-perfect копия
   CanvasKit-рендера.
7. **NG7.** Не ORM/CMS/data-layer. Данные предоставляет разработчик.

### 2.3 Инженерные принципы

- **P1. Pure-Dart ядро.** Модели и сериализация не зависят от Flutter →
  тестируются `dart test`, переиспользуются на сервере.
- **P2. Одна модель — два источника.** Серверный pure-Dart билдер и
  Flutter-виджеты сходятся к единому `DocumentNode`-дереву.
- **P3. Безопасность по умолчанию.** Пользовательский текст экранируется;
  небезопасный HTML — только через явный opt-in `UnsafeHtmlNode`.
- **P4. Прогрессивное улучшение.** Контент работает без JS; интерактив
  добавляется послойно (vanilla → HTMX → Flutter).
- **P5. Совместимость с #187663.** Термины и модель осознанно совпадают
  с дизайн-доком Flutter.
- **P6. Минимум runtime-JS.** Единственный собственный JS — Custom Element
  `<hydraline-island>` (~2 KB), диспетчер событий (~1.5 KB), vanilla-острова
  (~8 KB). Всё остальное — стандартный `flutter_bootstrap.js`.
- **P7. Resumable-модель для Flutter-островов.** Состояние острова сериализуется
  в HTML (`data-state`); движок не пересчитывает widget tree при старте —
  возобновляет из сохранённого состояния.
- **P8. Честный zero-overhead.** Если на странице нет **Flutter-островов** —
  `flutter_bootstrap.js` не вставляется и движок не загружается. Уровни 0–1
  (статика, vanilla, HTMX) работают без Flutter вовсе. Проверка — на уровне
  диспетчера и SSR/SSG-генератора (W-12).

---

## 3. Позиционирование и конкурентный анализ

| Решение | HTML в первом ответе | Flutter-острова поверх | Переписывание проекта | Фреймворк | Cloaking-риск |
|---|---|---|---|---|---|
| `meta_seo` / `seo` / `webify_toolkit` | нет (runtime) | n/a | нет | нет | нет |
| Firebase Function + UA-sniff | только ботам | нет | частично | нет | **да** |
| Jaspr | да | нет (свои компоненты) | **да** | **да** | нет |
| Spark Framework | да | нет (Web Components) | **да** | **да** | нет |
| Trellis | да | HTMX-фрагменты | **да** | нет (движок) | нет |
| Нативный #187663 (будущее) | да | да | нет | нет (ядро) | нет |
| **Hydraline** | **да** | **да (multi-view islands)** | **нет** | **нет** | **нет** |

**Ключевой дифференциатор:** единственный путь получить настоящий HTML в первом
ответе **и** Flutter-острова поверх, сохранив существующее приложение.

---

## 4. Термины и режимы рендера

### 4.1 Режимы маршрута (`WebRouteRenderMode` — по #187663)

| Режим | Владелец контента | Применение |
|---|---|---|
| `app` | CanvasKit/Skwasm (как сейчас) | Дашборды, редакторы, приватные экраны |
| `document` | Семантический HTML | Блог, docs, лендинги, карточки товаров |
| `hybrid` | HTML владеет SEO-контентом; Flutter-острова — интерактивом | Товар с калькулятором, статья с виджетом |

Режим задаётся **пер-маршрут**. В одном приложении сосуществуют все три.

**`app`-маршруты и SEO (дефолты):** исключены из `sitemap.xml` по умолчанию;
**СЛЕДУЕТ** помечать их `noindex` (meta + `X-Robots-Tag`), если разработчик явно
не opt-in на индексацию; опционально `app`-маршрут может задать минимальный
`document`-fallback (meta + `<noscript>`-контент) для соц-ботов.

### 4.2 Основные термины

- **Prerender** — генерация HTML до/вместо исполнения Flutter (SSG build-time
  или SSR request-time).
- **Hydration (гидрация)** — «оживление» уже отрисованного HTML: монтирование
  Flutter-острова в DOM-элемент через multi-view API.
- **Resume (возобновление)** — загрузка Flutter-острова из сериализованного
  состояния (`data-state` в HTML) без пересчёта widget tree.
- **Island (остров)** — явно очерченная интерактивная зона. Может быть трёх
  типов: статическая (vanilla JS), HTMX-остров (серверные фрагменты),
  Flutter-остров (CanvasKit).
- **`DocumentNode`** — узел абстрактного дерева документа (h1–h6, p, a, img,
  списки, таблицы, island-placeholder, raw-fragment). Pure Dart, без `dart:ui`.
- **Island-манифест** — сериализованное описание островов маршрута (id, тип,
  точка монтирования, props, директива гидрации), встраиваемое в HTML.
- **Route-манифест** — карта: маршрут → режим, метаданные, статус, источник
  контента. Формат: YAML (`hydraline.routes.yaml`) + опциональный Dart-builder.

### 4.3 Три уровня интерактивности

```
Уровень 0 — Статический HTML (FCP < 100ms, работает без JS)
├── Семантические заголовки, текст, изображения, ссылки
├── <details>/<summary> — аккордеоны без JS
├── Метаданные (title, meta, OG, JSON-LD)
└── Skeleton-плейсхолдеры для островов

Уровень 1 — Vanilla Islands + HTMX-острова (TTI ~50ms после DOMContentLoaded)
├── Vanilla: табы, аккордеоны, карусели, копирование, темы (~8 KB JS)
├── HTMX: формы, поиск, пагинация, ленивая подгрузка (~14 KB JS)
├── Сервер рендерит HTML-фрагменты по запросу
└── Flutter-движок НЕ загружается

Уровень 2 — Flutter Islands (TTI: холодный 4G ~3-5 сек / холодный 3G ~10-19 сек / тёплый ~1 сек)
├── Сложные виджеты: калькуляторы, конфигураторы, графики
├── Загрузка движка только при триггере острова
├── Deferred imports: код острова в отдельном чанке
├── Состояние из data-state → возобновление без пересчёта
└── Service Worker кэширует движок для повторных визитов
```

Разработчик выбирает уровень для каждого острова. 80% интерактивности на
контентных страницах покрывается уровнями 0–1 без загрузки Flutter-движка.

---

## 5. Модель документа (`DocumentNode`)

### 5.1 Типы узлов

**ДОЛЖНО (Phase 1):**
- `DocumentRootNode` — корень документа
- `HeadNode` / `TitleNode` / `MetaNode` / `LinkNode` (`<link rel href>`) — метаданные
- `HeadingNode` (h1–h6), `ParagraphNode`, `TextNode`
- `AnchorNode` (`<a href>`), `ImageNode` (`<img src alt width height>`)
- `ListNode` (ul/ol) → `ListItemNode` (li)
- `SectionNode` с осью `SectionRole` (section/article/nav/header/footer/main)
- `BlockquoteNode`, `CodeNode` / `PreNode`, `TimeNode`
- `TableNode` / `TableRowNode` / `TableCellNode` (базово: текст в ячейках)
- `DetailsNode` / `SummaryNode` (no-JS аккордеоны уровня 0 — §4.3; нужны в MVP,
  т.к. vanilla-остров `accordion` оживляет именно `<details>`)
- `IslandPlaceholderNode` (для Flutter-островов)
- `HtmxIslandNode` (для HTMX-островов: endpoint, trigger, target, swap)
- `VanillaIslandNode` (для vanilla-островов: тип, конфигурация)
- `UnsafeHtmlNode` (opt-in, с санитайзером)

**СЛЕДУЕТ (Phase 5+):**
- Расширенные таблицы (colspan/rowspan, caption, colgroup)
- `FigureNode` / `FigcaptionNode`

**НЕТ выделенных типов узлов (по дизайну, ADR Q4):**
- `iframe`, `script`, `video`, `audio` — hydraline **не** предоставляет для них
  отдельных нод. При реальной необходимости — только через `UnsafeHtmlNode` с
  санитайзером, предоставленным разработчиком (осознанный opt-in).
- CSS/стили в `DocumentNode` — не поддерживаются: модель семантическая, а не
  презентационная. Стили — на уровне тем/страницы, не узла.

### 5.2 Модель метаданных

- `title`, `description`, `canonical`
- `robots`-директивы
- Open Graph (`og:*`) — полный набор
- Twitter Card (`twitter:*`) — summary + summary_large_image
- Произвольные `<meta>` / `<link>`
- `charset`, `viewport`, `lang`, `hreflang`-альтернативы

### 5.3 JSON-LD (Structured Data)

Типобезопасные билдеры для: `Article`, `Product`, `BreadcrumbList`, `WebPage`,
`Organization`, `FAQPage`, `Event`, `Recipe`, `Review` (метод `JsonLd.faq`).
+ Произвольные схемы.
Вывод: `<script type="application/ld+json">`.

### 5.4 Безопасность

- **Контекстное экранирование:** `escapeHtmlText()`, `escapeHtmlAttribute()`,
  `sanitizeUrl()` (allowlist: `http`, `https`, `mailto`, `tel`).
- **Безопасный API по умолчанию:** `DocumentNode.text()` всегда экранирует.
  `DocumentNode.link()` принимает только `SafeUrl`.
- **`UnsafeHtmlNode`** — единственный путь для сырого HTML. Имя осознанно
  содержит "Unsafe". Валидатор предупреждает при использовании без санитайзера.
- **URL-валидация:** блок `javascript:`, `data:`, `vbscript:`.
- **CSP по умолчанию (СЛЕДУЕТ):** документируемый рекомендуемый заголовок для
  продакшна — `script-src 'self' 'wasm-unsafe-eval'` (без `'unsafe-inline'`),
  что блокирует инлайн-скрипты даже при проскочившем XSS. Генератор HTML
  предоставляет helper для вставки CSP-мета/заголовка. Совместим с
  `flutter_bootstrap.js` (CanvasKit требует `wasm-unsafe-eval`).

### 5.5 HTML-сериализатор

- **Single-pass по дереву** — обходит готовое `DocumentNode`-дерево ровно один
  раз и пишет напрямую в выходной поток, **без второго (промежуточного) буфера
  строк** и без построения дополнительного представления (VDOM/строкового
  дерева). Отличие от Marko: Marko компилирует шаблон и вовсе не строит дерево;
  hydraline **осознанно** строит одно `DocumentNode`-дерево (это цена за две
  поверхности авторинга → одну модель, §5.6), но сериализует его single-pass без
  лишних аллокаций сверх самого дерева.
- **Детерминированный** — стабильный порядок атрибутов, предсказуемый вывод.
- **Конфигурируемый** — pretty/minified.
- **Потоковый** — `serializeToStream(DocumentNode) → Stream<String>` для SSR.
- **Фрагментный** — `serializeFragment(DocumentNode) → String` для HTMX-ответов.
- **Без квадратичных алгоритмов** (NF-1): конкатенация через `StringBuffer`/
  `Sink<String>`, сложность O(число узлов + суммарная длина текста).
- **Golden-тесты** на вывод.

### 5.6 Две поверхности авторинга — одна модель

```
Поверхность (A): Flutter-виджеты (self-registering)
  Seo.text('Hello')         ─┐
  Seo.image('/img.png',...)  ─┤  build() → collector.add*()
  Island(id:'calc',...)      ─┘
                                    │
                                    ▼
                            SsgCollector → DocumentNode
                                    ▲
                                    │
Поверхность (B): Pure-Dart билдер  │
  Document.of(children: [          │
    h1('Title'),                   │
    p('Content'),                  │
    island(id:'calc',...),         │
  ])                          ─────┘
```

- **(A)** — Flutter-виджеты с двойной природой. В методе `build()` регистрируют
  семантику через `SsgCollector` (InheritedWidget). Извлечение — в build-time
  через `flutter_tester`. Подходит для статических страниц.
- **(B)** — Pure-Dart билдеры. Работают на сервере без Flutter. Для динамических
  страниц (per-request SSR).
- Обе дают **идентичный** `DocumentNode` → один сериализатор, один механизм
  островов, один набор тестов.

### 5.7 Сводный SEO-чек-лист (полный перечень возможностей)

Единый список того, что покрывает hydraline по SEO (реализуется core + server):

- **SEO-1.** Пер-маршрутные `title`, `description`, `canonical`.
- **SEO-2.** Open Graph (`og:title/description/image/url/type/locale/site_name`,
  `image:secure_url/alt/width/height`).
- **SEO-3.** Twitter Card (`summary` / `summary_large_image`, title/description/
  image/site/creator).
- **SEO-4.** JSON-LD structured data (типобезопасно + произвольные схемы, §5.3).
- **SEO-5.** `sitemap.xml` с `lastmod`/`changefreq`/`priority` и hreflang-alternates;
  статический (манифест) или динамический (`SitemapSource`) источник; автосплит в
  sitemap-index при > 50 000 URL / > 50 MB (C-6).
- **SEO-6.** `robots.txt` + пер-маршрутный `noindex`/`nofollow` (meta и `X-Robots-Tag`).
- **SEO-7.** Path-routing (без hash), корректные абсолютные canonical.
- **SEO-8.** i18n: `lang`, `hreflang`, alternate-URL.
- **SEO-9.** HTTP-статусы и редиректы (SSR): 200/301/302/404/410/5xx; для SSG —
  рекомендации по хостинг-конфигу.
- **SEO-10.** No-JS fallback: осмысленный контент и навигация без JavaScript.
- **SEO-11.** Семантика: настоящие `h1..h6`, `nav`, `article`, `main`, `a[href]`,
  `img[alt]`.

---

## 6. Архитектура

### 6.1 Состав (monorepo, melos ≥ 7, Dart SDK ≥ 3.6)

| Пакет | Роль | Зависит от Flutter? |
|---|---|---|
| `hydraline` | **Pure-Dart ядро**: `DocumentNode`, HTML-сериализатор, escaping, метаданные, JSON-LD, sitemap/robots, island/route манифесты, SEO-валидаторы, CLI-аудит, `SsgCollector`, **standalone web-ассеты уровней 0–1** (vanilla islands ~8 KB, HTMX-интеграция) как строковые/файловые ассеты | **Нет** |
| `hydraline_server` | **Pure-Dart сервер**: shelf / Dart Frog middleware, SSR-обработчик (single-pass стриминг), HTMX-хелперы, кэширование, статусы/редиректы/noindex, стриминг, **отдача web-ассетов уровней 0–1 из core** | **Нет** |
| `hydraline_flutter` | **Flutter-пакет**: `Seo.*`-виджеты, `Island`, `HydraApp`, `SsgSandbox`, `IslandHost` (мульти-вью), SSG-раннер, devtools-оверлей, go_router-адаптер, `RouteAdapter`-интерфейс, **web-ассеты уровня 2** (Custom Element, диспетчер, Service Worker — оркестрация движка), island entry-point | **Да** |

### 6.2 Диаграмма зависимостей

```
              ┌──────────────────────────────────┐
              │         hydraline (core)          │
              │  DocumentNode • serializer •       │
              │  escaping • metadata • JSON-LD •   │
              │  sitemap/robots • manifests •      │
              │  validators • audit • collector    │
              └──────────────────────────────────┘
                  ▲           ▲
                  │           │
    ┌─────────────┘           └──────────────┐
    │                                         │
┌───────────────────┐              ┌──────────────────────┐
│ hydraline_server   │              │  hydraline_flutter    │
│ shelf/Dart Frog    │              │  Seo.* widgets        │
│ SSR handler        │              │  Island widget        │
│ HTMX helpers       │              │  HydraApp / SsgSandbox│
│ cache • streaming  │              │  IslandHost (views)   │
│ serve L0–L1 assets │              │  SSG runner           │
│ pure server Dart   │              │  devtools overlay     │
└───────────────────┘              │  go_router adapter     │
                                   │  Custom Element JS (L2)│
                                   │  dispatcher JS (L2)    │
                                   │  Service Worker (L2)   │
                                   └──────────────────────┘
```

**Правило зависимостей (ДОЛЖНО):**
- `hydraline` не импортирует `flutter` / `dart:ui`
- `hydraline_server` не импортирует `flutter`
- Нарушение — блокирующая ошибка CI

### 6.2.1 Расслоение web-ассетов по уровням интерактивности

Чтобы проект с чисто `document`/HTMX-маршрутами **не тянул Flutter-пакет** ради
JS, web-ассеты разделены по уровням (§4.3):

| Уровень | Ассеты | Пакет | Flutter нужен? |
|---|---|---|---|
| 0 | Статический HTML, DSD-скелетоны | `hydraline` (генерируется сериализатором) | Нет |
| 1 | Vanilla islands (~8 KB), HTMX-glue | `hydraline` (standalone-бандл) | Нет |
| 2 | Custom Element, диспетчер, Service Worker, island entry-point | `hydraline_flutter` | Да |

Проект без Flutter-островов (лендинг, блог, docs) подключает только `hydraline`
+ `hydraline_server` и получает полностью рабочие уровни 0–1. Flutter-пакет
подключается **только** когда на маршрутах есть `IslandType.flutter`. Это
прямое следствие принципа P8 (честный zero-overhead) и проверки W-12.

### 6.3 Ключевое архитектурное ограничение

Flutter-виджеты нельзя исполнять на «голом» Dart-сервере — требуется `dart:ui`.
Поэтому:
1. **`hydraline_server` никогда не запускает Flutter-виджеты.** Работает только
   с pure-Dart `DocumentNode`-билдерами (поверхность B) и предсобранными
   маршрутными манифестами.
2. **Извлечение из Flutter-виджетов (поверхность A)** — только в среде с `dart:ui`:
   build-time SSG через `flutter_tester` + `SsgCollector`.
3. **Для динамических per-request маршрутов** — только поверхность B.

### 6.4 Поток данных: три сценария доставки

**Сценарий SSG (статик-хостинг / CDN):**
```
flutter + hydraline_flutter
  → [если есть Flutter-острова] flutter build web --target=lib/island_main.dart
      → build/web/ (main.dart.js island-entry, canvaskit/, flutter_bootstrap.js, deferred-чанки)
  → обход route-манифеста
  → headless-извлечение DocumentNode через SsgCollector
  → single-pass сериализатор
  → /dist/**.html + sitemap.xml + robots.txt + island-манифесты
  → SSG-раннер (W-14) КОПИРУЕТ island-бандл и web/-ассеты из build/web в dist/
      (единственный ответственный за размещение Flutter-ассетов при SSG)
  → деплой всего dist/ на статик-хостинг
  → краулер видит готовый HTML
  → браузер грузит Flutter и гидрирует острова
```
Ответственность за ассеты (ДОЛЖНО): **при SSG** — SSG-раннер (W-14) копирует бандл
в `dist/`; **при SSR** — сервер/CDN (S-10) отдаёт заранее собранный бандл как
first-party. В обоих случаях источник бандла — `flutter build web
--target=lib/island_main.dart` (W-7). Проекты без Flutter-островов шаг сборки и
копирования пропускают (§6.2.1, P8).

**Сценарий SSR (shelf / Dart Frog):**
```
HTTP-запрос
  → hydraline_server middleware
  → match route по манифесту
  → [document/hybrid]: pure-Dart DocumentNode builder(данные)
  → [app]: отдать app-shell как обычно
  → single-pass in-order streaming serializer (прогрессивный flush)
  → HTML + island-манифест (чанками: shell → статика → острова)
  → ответ со статусом/редиректом/noindex
  → для ботов: buffered (весь HTML сразу)
  → для пользователей: chunked transfer-encoding
```

**Сценарий HTMX (динамические фрагменты):**
```
HTMX-запрос (hx-get/hx-post)
  → hydraline_server handler
  → pure-Dart DocumentNode builder(данные)
  → serializeFragment() → HTML-фрагмент
  → ответ (без <html>/<head>, только фрагмент)
  → HTMX в браузере заменяет DOM
  → без перезагрузки страницы, без Flutter-движка
```

### 6.5 Два слоя и запрет cloaking (разрешение противоречия «UA-барьер vs bot-aware»)

Ключевое архитектурное разграничение, устраняющее кажущееся противоречие между
«middleware не принимает User-Agent» (§14 R7) и «buffered для ботов, streaming
для людей» (§11 S-5):

```
┌─────────────────────────────────────────────────────────────┐
│  Слой контента (UA-СЛЕПОЙ) — ДОЛЖНО                           │
│  DocumentNode builder(request, data) → DocumentNode           │
│  • сигнатура НЕ содержит user-agent                           │
│  • тело документа детерминировано и одинаково для всех         │
│  • сериализатор даёт побайтово идентичный HTML                 │
└─────────────────────────────────────────────────────────────┘
                            │ один и тот же HTML
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Транспортный слой (МОЖЕТ читать UA) — только доставка         │
│  • бот  → buffered: тот же HTML одной порцией (Content-Length) │
│  • юзер → chunked: тот же HTML потоком (Transfer-Encoding)     │
│  • НИКАКИХ изменений тела в зависимости от UA                  │
└─────────────────────────────────────────────────────────────┘
```

**Инвариант (ДОЛЖНО, проверяется CI-аудитом A8):** для любого маршрута на одном и
том же (детерминированном) входе `bytes(buffered) == bytes(concat(chunks))` —
чанки суть сегментация того же байтового потока, а не его перестановка. Транспорт
вправе знать UA; билдер контента — нет. Это не cloaking: cloaking = разное **тело**;
здесь тело идентично, отличается лишь `Transfer-Encoding`.

---

## 7. Flutter-острова и гидрация

### 7.1 Механизм

1. Prerender (SSR/SSG) вставляет в HTML **Custom Element** `<hydraline-island>`
   с Declarative Shadow DOM:
```html
<hydraline-island
  id="calculator"
  data-directive="hydrateOnVisible"
  data-state='{"price":89990,"currency":"RUB","quantity":1}'
>
  <template shadowrootmode="open">
    <style>
      :host { display: block; contain: layout style paint; }
      .host { width: 640px; height: 480px; }
      .skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); }
    </style>
    <div class="host">
      <slot>
        <div class="skeleton" style="width:320px;height:40px"></div>
        <p>Калькулятор загружается...</p>
      </slot>
    </div>
  </template>
</hydraline-island>
```

2. **Диспетчер** (~1.5 KB JS) — единый глобальный слушатель событий (Qwikloader-style):
   - Один `IntersectionObserver` на все острова с `hydrateOnVisible`
   - Один `requestIdleCallback` на все `hydrateOnIdle`
   - Один глобальный `click`/`focusin` listener на `hydrateOnInteraction`
   - При триггере: загружает Flutter-движок (если ещё не загружен) + код острова

3. **Custom Element** принимает `hostElement` в Shadow DOM, вычисляет точные
   пиксельные размеры и передаёт явные `viewConstraints` в `addView()` —
   обход бага #185034. `ResizeObserver` на host-элементе служит корректором
   при легитимном изменении размеров (resize окна, ротация, media-query), но:
   (а) **всегда переустанавливает pinned-констрейнты** (`min==max`), никогда не
   переключаясь на авто-sizing движка; (б) обновления **коалесцируются в один
   кадр (`requestAnimationFrame`) и применяются ко всем view пачкой** — чтобы не
   воспроизводить гонку «последний view перезаписывает sizing» (#185034, R1);
   (в) реагирует только на committed-изменения (debounce), не в процессе
   CSS-анимаций; (г) на версиях с известной регрессией (3.41.x) деградирует до
   no-op (R1, NF-5). Дефолт — фиксированные px + явные констрейнты.

4. **Состояние** десериализуется из `data-state` → `initialData` → виджет
   возобновляется без пересчёта widget tree (resumable-модель).

### 7.2 Директивы гидрации

| Директива | Триггер | Браузерное API | Применение |
|---|---|---|---|
| `hydrateOnLoad` | На `DOMContentLoaded` диспетчер немедленно грузит движок; монтирование — как только движок готов | `DOMContentLoaded` | Критичный интерактив «выше сгиба» |
| `hydrateOnIdle` | Простой главного потока | `requestIdleCallback` (+fallback) | Второстепенное. **Дефолт.** |
| `hydrateOnVisible` | Попадание в viewport | `IntersectionObserver` | Ниже сгиба, тяжёлые виджеты |
| `hydrateOnInteraction` | Первое взаимодействие | Глобальный event delegation | Виджеты, не нужные сразу |
| `hydrateOnMedia(q)` | Совпадение media-query | `matchMedia` | Только desktop / только mobile |
| `hydrateManual` | Явный вызов глобального JS-API `window.hydraline.hydrate(id)` (работает без запущенного `MaterialApp`, §7.9) | — | Гидрация по бизнес-триггеру (после логина, по событию) |

**Дефолт — `hydrateOnIdle`** (не `hydrateOnLoad`), чтобы не бить по TTI.
`hydrateOnLoad` — только явный выбор разработчика.

**Порядок:** top-down (родительский остров раньше вложенного).

**Две ортогональные оси острова.** Директива (*когда* гидрировать) не зависит от
**`renderMode`** (*что* попадает в HTML):
- `renderMode: ssr` (дефолт) — остров эмитит семантический fallback в HTML.
- `renderMode: skeletonOnly` (бывш. `clientOnly`) — в HTML только skeleton
  (3D-конфигураторы, WebGL, `window`/`localStorage` в рендере). SSR-контента нет,
  но директива гидрации всё равно применяется (дефолт — `hydrateOnIdle`).

### 7.3 Отдельный island entry-point + per-island code splitting

Острова собираются из **отдельной точки входа** `lib/island_main.dart`
(`flutter build web --target=lib/island_main.dart`), которая грузит только
`IslandHost` + код островов, **без** `MaterialApp`/роутера/бизнес-логики
основного приложения (W-7). Каждый тяжёлый остров — отдельный deferred import.
Базовый island **JS**-бандл (`main.dart.js` island-entry + Flutter runtime glue +
`IslandHost`) ≈ 450 KB gzip — **без** `canvaskit.wasm` (~1.1 MB, кэшируется
SW/CDN отдельно) и **без** per-island deferred-чанков; для сравнения полное
приложение ≈ 2.5 MB. Код острова загружается только при триггере:

```dart
// lib/island_entry.dart
import 'package:hydraline_flutter/hydraline_flutter.dart';

// Тяжёлые острова — deferred (отдельные чанки)
import 'islands/calculator.dart' deferred as calc;
import 'islands/configurator.dart' deferred as conf;
import 'islands/chart.dart' deferred as chart;

final islandFactories = <String, Future<Widget> Function(Map<String, dynamic>)>{
  'calculator': (props) async {
    await calc.loadLibrary();
    return calc.CalculatorIsland(props: props);
  },
  // ...
};
```

### 7.4 Anti-CLS

- До гидрации плейсхолдер держит зарезервированные размеры (width/height в px)
- Размеры вычислены на этапе SSR/SSG и вшиты в HTML
- При `hydrateOnVisible`: `min-height` на host-элементе предотвращает схлопывание
- Валидатор devtools отлавливает острова без размеров

### 7.5 Единственная инстанция движка

Одна инстанция Flutter-движка на страницу — несколько views. Общее состояние
между островами — через явную шину / URL / `localStorage`, не через общий
Flutter-контекст.

### 7.6 Scoped-режим стилей (оптимизация массовых островов)

По умолчанию `<hydraline-island>` использует Declarative Shadow DOM — стили
изолированы, но при N одинаковых островах на странице `<style>` внутри DSD
**дублируется N раз** (проблема, отмеченная в Stencil). Для страниц с
множеством однотипных островов (карточки товаров, ленты) предусмотрен
`scoped`-режим:

| Режим | Изоляция | Дублирование стилей | Когда |
|---|---|---|---|
| `shadow` (дефолт) | Shadow DOM (полная) | N × стили | Уникальные острова |
| `scoped` | CSS `@scope` / атрибутный префикс | 1 × стили на страницу | Много одинаковых островов |

- Режим задаётся на острове: `Island(..., styleMode: IslandStyleMode.scoped)`.
- В `scoped`-режиме сериализатор выносит стили один раз в `<head>` (или общий
  `adoptedStyleSheets`), а острова получают scope-атрибут.
- `viewConstraints` и фиксированные px-размеры (§7.1) сохраняются — обход
  #185034 работает в обоих режимах.
- Дефолт остаётся `shadow` (безопаснее); `scoped` — осознанный выбор для
  оптимизации. Валидатор devtools предлагает `scoped` при обнаружении > 5
  островов одного типа на странице.

### 7.7 Virtual views — высокие острова (обход лимита OffscreenCanvas)

`OffscreenCanvas` имеет браузерный лимит размера (4096–16384px в зависимости от
GPU/браузера, #175892). Остров выше этого лимита обрезается. По рекомендации
Flutter-команды (mdebbar в #175892) высокий остров **автоматически разбивается
на сегменты**, управляемые общим `IntersectionObserver` — виртуальный скроллинг
на уровне Flutter-view:

```html
<hydraline-island-segment data-virtual="calc" data-offset="0"    data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
<hydraline-island-segment data-virtual="calc" data-offset="4000" data-height="4000" style="min-height:4000px">…</hydraline-island-segment>
```

- Сегменты, попавшие в viewport (`rootMargin` для предзагрузки) → `addView()`;
  вышедшие из viewport → `removeView()` (экономия GPU-памяти).
- Порог сегментации (по умолчанию ~4000px) конфигурируем; разбиение
  автоматическое — разработчик описывает один остров.
- Применяется только при `IslandType.flutter` и высоте острова выше порога;
  для обычных островов не активируется (нулевой оверхед).
- Валидатор devtools предупреждает об островах выше лимита без включённого
  virtual-режима (см. R10).

### 7.8 Контракт props / `data-state` (граница сервер ↔ остров)

Props острова пересекают границу «сервер → HTML → клиент» через атрибут
`data-state` (или `data-props`). Контракт (ADR Q6):

- **Сериализация:** `JSON.stringify` на сервере (с HTML-escaping значения
  атрибута), `JSON.parse` на клиенте. Никакого `eval`/`Function`/`DOMParser`.
- **Допустимые типы (MVP):** `String`, `int`, `double`, `bool`, `null`, `List`,
  `Map<String, dynamic>` с допустимыми листьями.
- **Недопустимо:** функции, `DateTime` (передавать ISO-строкой), `Uri` (строкой),
  `Color` (int-значением), циклические ссылки, `undefined`, `Symbol`.
- **Детерминизм:** запрещены недетерминированные значения в момент рендера
  (`DateTime.now()`, `Math.random()`) — иначе hydration-mismatch (см. R6).
- **Лимит размера:** ~10 KB/остров; devtools предупреждает при превышении
  (W-18). Держите props минимальными — JSON.parse ~2–5ms на 10 KB.
- **Приём на Dart-стороне:** `IslandHost` (W-6) прокидывает `initialData` в
  остров; helper `IslandProps.of(view)` даёт типобезопасный доступ и
  десериализацию. Возобновление из `data-state` — без пересчёта widget tree (P7).
- **Расширение (post-MVP):** tagged replacer/reviver для `DateTime`/`Uri`/`BigInt`,
  версионирование `__v` для оптимистичной сверки.

### 7.9 Состояния и ошибки гидрации (жизненный цикл острова)

Гидрация острова в проде **ДОЛЖНА** иметь явный контракт состояний и обработку
сбоев (сеть, ошибка загрузки движка/deferred-чанка):

- **Состояния** отражаются в атрибуте host-элемента:
  `data-hydration="pending" | "hydrating" | "hydrated" | "failed"`.
- **Тайм-аут + ограниченный retry** загрузки движка и per-island deferred-чанка.
- **При терминальном сбое:** SSR-fallback/скелетон **остаётся видимым**,
  ставится `data-hydration="failed"`, эмитится DOM-событие
  `hydraline:island-error` (`detail: {id, reason}`) для аналитики/логики приложения.
- **Опциональный error-fallback:** `Island(..., errorFallback: ...)` — контент,
  показываемый вместо скелетона при сбое.
- **Ручная гидрация без приложения:** глобальный JS-API
  `window.hydraline.hydrate(id)` / `window.hydraline.hydrateAll()` работает на
  `document`/`hybrid`-страницах, где основной `MaterialApp` не запущен (директива
  `hydrateManual`, §7.2). API экспонирует диспетчер (W-9).

### 7.10 Доступность островов (a11y)

Основной SEO-контент — настоящий семантический HTML (a11y «из коробки»). Для
интерактивных островов **ДОЛЖНО**:

- Host-элемент несёт `role` и `aria-busy="true"` до гидрации; после — `aria-busy`
  снимается.
- SSR-fallback/скелетон несёт осмысленный `aria-label` (напр. «Калькулятор,
  загружается»).
- Для Flutter-островов включается semantics-слой Flutter (доступное дерево в
  пределах Shadow DOM острова; AT обходит shadow-деревья).
- В `scoped`-режиме (§7.6) сохраняются порядок фокуса и лейблинг.
- E2E покрывает a11y островов (axe/pa11y в CI).

---

## 8. Vanilla Islands (уровень 1)

### 8.1 Мотивация

80% интерактивности на контентных страницах — простые вещи (табы, аккордеоны,
карусели, копирование, переключение темы). Flutter для них — оверкилл.
Vanilla Islands закрывают этот класс задач мгновенно (~50ms), без загрузки
Flutter-движка.

### 8.2 Встроенные типы

| Тип | Что делает | No-JS fallback |
|---|---|---|
| `accordion` | Анимирует `<details>`, добавляет aria | `<details>` работает без JS |
| `tabs` | Переключает видимые панели | `:target` через якоря |
| `carousel` | Листает слайды | Статичная лента |
| `theme` | Переключает `data-theme` | Системная тема через `prefers-color-scheme` |
| `copy-button` | Копирует текст в буфер | Кнопка без копирования |
| `lazy-image` | Ленивая загрузка изображений | `<img loading="lazy">` |

### 8.3 Разметка

```html
<div class="hydraline-island"
     data-island="accordion"
     data-island-level="vanilla">
  <details>
    <summary>Как работает доставка?</summary>
    <p>Через СДЭК и Почту России...</p>
  </details>
</div>
```

### 8.4 Размер

~8 KB min+gzip. Загружается асинхронно, не блокирует рендер.

---

## 9. HTMX-острова (уровень 1)

### 9.1 Мотивация

Формы, поиск, пагинация, ленивая подгрузка — традиционно требуют либо
перезагрузки страницы, либо JS-фреймворка. HTMX-острова решают это через
серверные HTML-фрагменты без клиентского роутинга.

### 9.2 Модель

```html
<!-- SSR/SSG вывод -->
<div class="hydraline-island"
     data-island="htmx"
     data-island-level="htmx"
     hx-get="/api/reviews/iphone15"
     hx-trigger="load"
     hx-swap="innerHTML">
  <div class="skeleton">Загрузка отзывов...</div>
</div>
```

Серверный handler:
```dart
Future<Response> getReviews(Request req) async {
  final reviews = await db.getReviews(productId);
  final doc = DocumentNode([
    for (final r in reviews) _reviewCard(r),
  ]);
  return Response.ok(serializer.serializeFragment(doc));
}
```

### 9.3 Интеграция

`hydraline_server` предоставляет HTMX-хелперы: `renderFragment()`, `HtmxResponse`,
`HtmxTrigger`. HTMX-скрипт (~14 KB) **вендорится и отдаётся как first-party ассет**
(из core-бандла уровня 1, C-12; без внешнего CDN — совместимо с CSP
`script-src 'self'`, §5.4), загружается асинхронно при наличии HTMX-островов
на странице.

---

## 10. Функциональные требования: `hydraline` (core)

- **C-1 (ДОЛЖНО).** Модель `DocumentNode` со всеми типами узлов (§5.1).
- **C-2 (ДОЛЖНО).** Модель метаданных (§5.2).
- **C-3 (ДОЛЖНО).** JSON-LD билдеры (§5.3).
- **C-4 (ДОЛЖНО).** HTML-сериализатор: single-pass, потоковый (`serializeToStream`),
  фрагментный (`serializeFragment`), буферизованный (`serialize`). Детерминированный.
  Golden-тесты.
- **C-5 (ДОЛЖНО).** Контекстное экранирование и URL-санитайз (§5.4).
- **C-6 (ДОЛЖНО).** Генераторы: `sitemap.xml` (urlset, lastmod, changefreq,
  priority, alternates/hreflang), `robots.txt`. Источник URL — абстракция
  `SitemapSource`: (a) из route-манифеста + `dynamicSegments` (SSG/статик) или
  (b) developer-provided async-провайдер (`Stream<SitemapEntry>`/callback) для
  БД-driven SSR. **Автосплит в sitemap-index** при > 50 000 URL или > 50 MB на
  файл (`sitemap.xml` → индекс + `sitemap-1.xml`, …).
- **C-7 (ДОЛЖНО).** Island-манифест: сериализация/десериализация (id, тип, mount-selector,
  props как JSON-safe по контракту §7.8, директива, размеры-заглушки для anti-CLS).
- **C-8 (ДОЛЖНО).** Route-манифест: YAML-формат (`hydraline.routes.yaml`) +
  Dart-builder API для программного создания.
- **C-9 (ДОЛЖНО).** `SsgCollector` — коллектор для self-registering виджетов.
  Инстанс-скопированный (свой коллектор на каждый прогон извлечения; изоляция
  параллельных прогонов — через отдельные инстансы), доступ из виджетов — через
  `HydraScope` (InheritedWidget, W-3). Dedup по ключу, иммутабельный `seal()`.
- **C-10 (СЛЕДУЕТ).** SEO-валидаторы: длина title/description, обязательность alt,
  дубли canonical, битые hreflang.
- **C-11 (ДОЛЖНО).** CLI-аудит `dart run hydraline:audit <url>` в двух режимах:
  (a) **standalone** — view-source, валидация метаданных/OG/JSON-LD, SEO-валидаторы,
  exit-code для CI (без сервера); (b) **server-integration** — проверка инварианта
  bot-aware доставки (§6.5): на фиксированном входе
  `bytes(buffered) == bytes(concat(chunks))` для UA бота и обычного UA
  (требует живого endpoint).
- **C-12 (ДОЛЖНО).** Standalone web-ассеты уровней 0–1 (§6.2.1): vanilla islands
  (~8 KB), self-hosted HTMX (~14 KB) + HTMX-glue. Поставляются как файлы/строковые
  константы, отдаются сервером (S-* ) без зависимости от Flutter. Пакет
  `hydraline_flutter` переиспользует эти же ассеты, не дублируя их.
- **C-13 (ДОЛЖНО).** Ноль зависимостей от Flutter / `dart:ui`.

---

## 11. Функциональные требования: `hydraline_server`

- **S-1 (ДОЛЖНО).** Middleware для shelf + адаптер для Dart Frog.
- **S-2 (ДОЛЖНО).** Маршрутизация по route-манифесту (YAML): `document`/`hybrid`
  → рендер HTML; `app` → отдать app-shell (по дефолту `noindex` + исключён из
  sitemap, §4.1; опциональный `document`-fallback для ботов).
- **S-3 (ДОЛЖНО).** Точка расширения: pure-Dart `DocumentNode` builder(request, data)
  для динамических маршрутов. Сигнатура **не принимает** `User-Agent` — билдер
  контента UA-слепой (§6.5, архитектурный запрет cloaking).
- **S-4 (ДОЛЖНО).** Single-pass **in-order** стриминговый рендер (прогрессивный
  flush, без переупорядочивания):
  - [chunk 1, ~0ms] Shell: head, meta, JSON-LD
  - [chunk 2, ~0ms] Статический контент (в порядке документа)
  - [chunk N] Плейсхолдеры островов (скелетон + `data-state`) — детерминированы,
    в порядке документа
  - Чанки — это **сегментация одного и того же байтового потока**, а не его
    перестановка: `concat(chunks)` побайтово равен buffered-ответу (S-5, A8).
  - Out-of-order / fastest-first / `<template for>` (DPU) — **вне MVP**
    (Advanced streaming, §16.1): требует серверных async-островов; там инвариант
    сужается до статического скелетона + обязателен fallback для браузеров без DPU.
- **S-5 (ДОЛЖНО).** Bot-aware **доставка** (транспортный слой, §6.5):
  - Боты: buffered HTML (весь контент сразу, один response, `Content-Length`)
  - Пользователи: chunked transfer-encoding (тот же поток, прогрессивный flush)
  - Тело **побайтово идентично**; UA читается только для выбора буферизация/чанки,
    не для формирования контента. Инвариант `bytes(buffered)==bytes(concat(chunks))`
    на одном и том же (детерминированном) входе проверяется CI (A8). Не cloaking.
- **S-6 (ДОЛЖНО).** HTMX-хелперы: `renderFragment()`, `HtmxResponse`, `HtmxTrigger`.
- **S-7 (ДОЛЖНО).** HTTP-семантика: статус-коды (200/301/302/404/410/5xx),
  редиректы, `X-Robots-Tag`/`noindex`, канонизация путей (path-routing).
- **S-8 (ДОЛЖНО).** Кэширование: `Cache-Control`/`ETag`, конфигурируемый TTL,
  in-memory/pluggable кэш.
- **S-9 (ДОЛЖНО).** Отдача `sitemap.xml` / `robots.txt` (включая sitemap-index при
  автосплите, C-6), а также standalone web-ассетов уровней 0–1 из core (C-12:
  vanilla islands, self-hosted HTMX) — без зависимости от `hydraline_flutter`.
- **S-10 (ДОЛЖНО).** Встраивание island-манифеста и **абсолютных** путей к ассетам
  Flutter (`/flutter_bootstrap.js`, `/main.dart.js`, `/canvaskit/`) — **только** для
  маршрутов с Flutter-островами. Генерация `<link rel="preload">` для движка.
  **Пути ДОЛЖНЫ быть абсолютными** (начинаться с `/`) или использоваться `<base href>`
  для корректной загрузки ассетов на вложенных path-маршрутах (`/blog/:slug`,
  `/shop/cat/item`), где относительные пути ломаются. Предпосылка: island entry-point
  заранее собран (`flutter build web --target=lib/island_main.dart`, W-7); сервер/CDN
  отдаёт этот бандл и `web/`-ассеты как first-party. Чисто `document`/HTMX-SSR
  **не требует** Flutter-сборки (§6.2.1).
- **S-11 (НЕ ДОЛЖНО).** Никогда не исполнять Flutter-виджеты; не зависеть от
  `package:flutter`.

---

## 12. Функциональные требования: `hydraline_flutter`

### 12.1 Виджеты

- **W-1 (ДОЛЖНО).** `Seo.*`-виджеты: text, image, link, heading, section, list,
  head/meta. Двойная природа: (1) визуальный Flutter-виджет, (2) self-registering
  в `SsgCollector` через `HydraScope`.
- **W-2 (ДОЛЖНО).** `Island(id, type, props, directive, placeholder, size, renderMode, styleMode)`:
  - `type: IslandType.flutter` — Flutter-остров (CanvasKit)
  - `type: IslandType.vanilla` — vanilla JS-остров
  - `type: IslandType.htmx` — HTMX-остров
  - `renderMode: IslandRenderMode.ssr` (дефолт) | `skeletonOnly` — ось,
    ортогональная директиве гидрации (§7.2)
  - В рантайме — обычный виджет. При извлечении — регистрация в коллекторе.
- **W-3 (ДОЛЖНО).** `HydraApp` — интеграционная обёртка. Предоставляет `HydraScope`
  (InheritedWidget с `SsgCollector`). Не заменяет `MaterialApp`/роутер.
- **W-4 (ДОЛЖНО).** `SsgSandbox` — обёртка для build-time извлечения:
  предоставляет заглушки `MediaQuery`, `Navigator`, `Directionality`.
- **W-5 (ДОЛЖНО).** First-class адаптер для `go_router`. Общий `RouteAdapter`
  интерфейс для `auto_route`, `Navigator 2.0`. `beamer` не поддерживается
  (пакет практически заморожен — ADR Q3); его пользователи используют
  `Navigator2Adapter`.
- **W-6 (ДОЛЖНО).** `IslandHost` — корневой мульти-вью виджет **Dart-стороны**
  (`runWidget` + `ViewCollection` + `View`). Сопоставляет каждый `FlutterView`,
  созданный через `addView()` (из диспетчера, W-9), конкретному острову и
  рендерит его виджет. Это Dart-контрагент JS-диспетчера: JS создаёт view и
  передаёт `initialData`, `IslandHost` отображает соответствующий остров в этот
  view. Единственная инстанция движка — несколько views (§7.5).
- **W-7 (ДОЛЖНО).** Отдельный island entry-point (`lib/island_main.dart`,
  собирается `flutter build web --target=lib/island_main.dart`): грузит только
  код островов + `IslandHost`, **без** `MaterialApp`/роутера/бизнес-логики
  основного приложения. Базовый island JS-бандл ≈ 450 KB gzip (без `canvaskit.wasm`
  и deferred-чанков, §7.3) вместо ~2.5 MB. Тяжёлые острова —
  per-island deferred imports (`deferred as` + `loadLibrary()`, §7.3), фабрики
  островов регистрируются в `IslandHost(factories: ...)`.

### 12.2 Клиентский рантайм островов (JS, в `hydraline_flutter/web/`)

- **W-8 (ДОЛЖНО).** `<hydraline-island>` Custom Element с Declarative Shadow DOM.
  Изолирует размеры острова (Shadow DOM, `contain`, фиксированные px). Принимает
  `addView()` с явными `viewConstraints` + `ResizeObserver`-корректор при
  легитимном ресайзе (pinned `min==max`, rAF-коалесинг по всем view, debounce,
  no-op на 3.41.x — §7.1). Обходит баг #185034. Использует **существующий** Shadow
  Root из DSD (не пересоздаёт → нет FOUC). Поддерживает `scoped`-режим (§7.6)
  для страниц с множеством одинаковых островов.
- **W-9 (ДОЛЖНО).** Диспетчер событий (~1.5 KB, Qwikloader-style). Единый
  глобальный слушатель. Загружает Flutter-движок только при первом триггере
  любого острова. Поддерживает все директивы гидрации (§7.2). Один
  `IntersectionObserver` на все `hydrateOnVisible`, один `requestIdleCallback`
  на все `hydrateOnIdle`, одно глобальное делегирование событий на
  `hydrateOnInteraction`, `matchMedia` — на `hydrateOnMedia`. Экспонирует
  глобальный API `window.hydraline.hydrate(id)`/`hydrateAll()` для `hydrateManual`
  (§7.9). Управляет состояниями `data-hydration` и обработкой ошибок (тайм-аут,
  retry, событие `hydraline:island-error`, §7.9). Создаёт view и передаёт
  управление `IslandHost` (W-6).
- **W-10 (СЛЕДУЕТ).** Переиспользование vanilla islands из core (C-12): пакет
  `hydraline_flutter` не дублирует JS уровня 1, а ссылается на standalone-бандл
  из `hydraline` (§6.2.1). Типы: accordion, tabs, carousel, theme, copy-button,
  lazy-image. Не зависят от Flutter-движка.
- **W-11 (ДОЛЖНО).** Service Worker (~2 KB). Кэширует `main.dart.js` +
  `canvaskit.wasm`. Прогрев через `WebAssembly.instantiateStreaming()` +
  `<link rel="preload">`/`modulepreload`. Тёплые повторные визиты: TTI ~1 сек.
- **W-12 (ДОЛЖНО).** Честная проверка (Fresh-style): если на странице нет
  Flutter-островов — `flutter_bootstrap.js` не вставляется, движок не грузится.
  Проверка на уровне диспетчера и SSR/SSG-генератора.
- **W-13 (СЛЕДУЕТ).** Virtual views для высоких островов (§7.7): автосегментация
  острова выше лимита OffscreenCanvas, `IntersectionObserver`-управление
  `addView`/`removeView` по сегментам. Обход #175892 (R10).

### 12.3 SSG

- **W-14 (ДОЛЖНО).** SSG-раннер: обход route-манифеста, извлечение `DocumentNode`
  через `SsgCollector` во `flutter_tester`, запись `dist/` (`**.html`, `sitemap.xml`,
  `robots.txt`, island-манифесты). **Единственный ответственный за размещение
  Flutter-ассетов при SSG:** копирует/линкует предсобранный island-бандл (`flutter
  build web --target=lib/island_main.dart`, W-7) и `web/`-ассеты (`main.dart.js`,
  `canvaskit/`, `flutter_bootstrap.js`, deferred-чанки, Service Worker) из
  `build/web/` в `dist/` — **только** если в манифесте есть маршруты с
  `IslandType.flutter` (иначе шаг пропускается, P8). Генерирует
  `<link rel="preload">` для ассетов движка (см. W-11). Вывод — детерминированный
  и воспроизводимый (стабильные пути/порядок).
- **W-15 (ДОЛЖНО).** Динамические сегменты: генерация страниц из набора параметров
  (`/blog/:slug` × N).
- **W-16 (ДОЛЖНО).** CLI: `dart run hydraline_flutter:build`. **Среда исполнения:**
  SSG-раннер требует `dart:ui` (для `flutter_tester` / `AutomatedTestWidgetsFlutterBinding`,
  §6.3) — поэтому запуск идёт **не** как plain `dart`, а одним из двух способов:
  (a) **внутри `flutter test`-харнесса** (`flutter test --tags ssg`), где биндинг
  уже инициализирован фреймворком; или (b) **отдельным Flutter-скомпилированным
  executable**, который вручную вызывает `AutomatedTestWidgetsFlutterBinding.ensureInitialized()`.
  Оба варианта встроены в CLI-команду; разработчик вызывает `dart run
  hydraline_flutter:build`, не задумываясь о биндинге. Документируется зависимость
  SSG от Flutter SDK и невозможность запуска в pure-Dart окружении.
- **W-17 (ДОЛЖНО).** Совместимость выхода со статик-хостингами (Firebase Hosting,
  Netlify, Cloudflare Pages, GitHub Pages): самодостаточный `dist/` (HTML +
  скопированные Flutter-ассеты, W-14). Документируются рекомендованные
  rewrite/fallback-правила для path-routing и SPA-фолбэка `app`-маршрутов на
  каждом из хостингов (без cloaking).

### 12.4 DevTools

- **W-18 (ДОЛЖНО).** Оверлей в dev-режиме: подсветка островов, их директив,
  границ HTML-vs-Flutter, диагностика несостоявшейся гидрации. Предупреждает об
  островах без зарезервированных размеров (anti-CLS) и о props > 10 KB.
- **W-19 (СЛЕДУЕТ).** Проверка соответствия «SSG-HTML ↔ гидрированный DOM».

---

## 13. Нефункциональные требования

- **NF-1. Производительность SSR:** median рендер `document`-маршрута (без учёта
  данных) < 50ms. Single-pass сериализатор без квадратичных алгоритмов.
- **NF-2. TTFB:** < 100ms для стримингового SSR (первый чанк — shell).
- **NF-3. Core Web Vitals:**
  - FCP < 1 сек (статический HTML)
  - LCP < 2.5 сек (контентные `document`/`hybrid`-маршруты)
  - CLS ≈ 0 (зарезервированные размеры островов)
  - TTI Flutter-острова: холодный 4G < 5 сек (target), холодный 3G — деградирует
    до ~10-19 сек (причина трёх уровней интерактивности, §4.3, R3); тёплый ~1 сек
  - Lighthouse (mobile, throttled) ≥ 70 для `document`/`hybrid` — проверяется
    Lighthouse CI (R3)
  - Бюджет skeleton-HTML острова (до гидрации): < 50 KB gzip (R3)
- **NF-4. JS-бюджет (хард-капы, min+gzip):**
  - *Базовый (всегда для страниц с Flutter-островами):*
    - Диспетчер: ≤ 2 KB
    - Custom Element: ≤ 2 KB
    - Service Worker: ≤ 2 KB
    - Итого базового собственного JS: ≤ 6 KB
  - *Уровень 1 (без Flutter):*
    - Vanilla Islands: ≤ 8 KB
    - HTMX (vendored, self-hosted): ~14 KB — грузится только при наличии HTMX-островов
  - *Условный (deferred, грузится только при использовании):*
    - Virtual-views менеджер (§7.7): ≤ 2 KB — только на страницах с virtual-островом
  - Уровни 0–1 не тянут базовый L2-JS. Превышение любого капа — регрессионный
    алерт CI.
- **NF-4a. Бюджет бандла островов:**
  - Базовый island **JS**-бандл (`main.dart.js` island-entry + runtime glue +
    `IslandHost`): ≈ 450 KB gzip — **без** `canvaskit.wasm` (~1.1 MB, отдельно,
    SW/CDN) и **без** deferred-чанков
  - Один остров + его уникальные зависимости (deferred-чанк): < 100 KB gzip —
    при превышении devtools выдаёт предупреждение и рекомендацию code-split
  - Регрессионный тест: рост `main.dart.js` между версиями hydraline ≤ 5%
- **NF-5. Совместимость Flutter:** *окно активной поддержки* — последние 3
  stable (на 2026-07: 3.44, 3.41, 3.38); min: 3.22 (multi-view). CI не заводит
  джоб на каждую версию окна: **блокирующие CI-джобы — только min (3.22) +
  latest (3.44)**; промежуточные версии окна (3.38) поддерживаются по SemVer-
  контракту, но постоянного джоба не имеют (проверяются точечно перед релизом).
  Любая версия с задокументированным known-issue добавляется как **отдельный
  non-blocking (informational) джоб** с ожидаемыми warning'ами.
  **Оговорка (ADR Q7, R1):** Flutter 3.41.x поддерживается **с оговоркой** —
  регрессия multi-view sizing (#185034); рекомендуется 3.44+ или обязательные
  явные `viewConstraints` (§7.1). В документации — banner «Known issue with
  Flutter 3.41.x». Джоб на 3.41 — informational (не блокирует PR).
- **NF-6. Безопасность:** отсутствие XSS (property/fuzz-тесты: 0 XSS на 10^6
  входов, 0 падений за 60 сек фаззинга), отсутствие секретов в логах, URL-санитайз,
  рекомендованный CSP (§5.4). Security-фиксы — patch-версия в течение 48 ч +
  advisory + регрессионный тест на вектор.
- **NF-7. Доступность (a11y):** семантический HTML + alt по умолчанию.
  Валидаторы предупреждают об отсутствии alt / пустых ссылках. Острова —
  a11y-контракт §7.10 (`aria-busy`, `aria-label` скелетона, semantics-слой Flutter
  в Shadow DOM, фокус в `scoped`-режиме), покрывается E2E.
- **NF-8. Кроссплатформенность разработки:** pure-Dart пакеты тестируются на
  Windows и WSL/Linux. Нормализация `\r\n` → `\n` в golden-тестах. Отсутствие
  зависимостей от локали (сравнения/сортировки — culture-invariant). Работа с
  путями — только через `package:path` (без хардкода `\`/`/`).
- **NF-9. Observability:** структурные логи сервера, коды выхода CLI-аудита для CI.
- **NF-10. Версионирование:** SemVer, Conventional Commits, melos changelog.
- **NF-11. Лицензия и публикация:** MIT. Публикация на pub.dev с полной
  pub.dev-готовностью каждого пакета: описание, `example/`, dartdoc публичного API,
  корректные `>=`-ограничения версий SDK/зависимостей, `CHANGELOG.md`, топики.

---

## 14. Риски и митигация (сводка)

| # | Риск | Критичность | Решение | Статус |
|---|---|---|---|---|
| R1 | Multi-view sizing #185034 | Высокая | Custom Element + фиксированные px-размеры + явные `viewConstraints` + ResizeObserver-корректор | Управляемый |
| R2 | Headless-извлечение хрупкое | Средняя | Self-registering виджеты (collector.add* в build) + SsgSandbox с заглушками + поверхность (B) как fallback | Управляемый |
| R3 | Старт движка (10-19 сек 3G) | Высокая | Три уровня интерактивности + диспетчер (движок только при триггере) + deferred per-island imports + SW-cache + preload | Управляемый |
| R4 | #187663 догонит (2028+) | Низкая | Совместимость модели + дифференциация (devtools/аудиты/HTMX) | Мониторинг |
| R5 | XSS через экранирование | Критическая | Контекстное escaping + property/fuzz-тесты + UnsafeHtmlNode opt-in | TDD-управляемый |
| R6 | Рассинхрон SSG ↔ hydrated | Средняя | Единый источник данных + devtools-сравнение + golden-тесты | Управляемый |
| R7 | Cloaking-соблазн | Высокая | Двухслойная архитектура (§6.5): билдер контента UA-слепой (API не принимает UA), UA доступен только транспорту для выбора buffered/chunked; инвариант идентичности тела в CI (A8) | Исключён |
| R8 | OS golden-флейки (CRLF) | Низкая | Нормализация + .gitattributes eol=lf + CI-матрица Windows/Linux | Управляемый |
| R9 | Непонимание «сервер без Flutter» | Средняя | Явное документирование + ошибка компиляции при импорте Flutter в сервер | Снижается |
| R10 | OffscreenCanvas limit (16384px) | Средняя | IntersectionObserver-based virtual views (Flutter team recommendation) — разбивка высоких островов на сегменты | Управляемый |

Детальный анализ каждого риска (сценарий → триггер → метрика порога → верификация
→ путь эскалации) — см. `RISK_ANALYSIS.md`.

### 14.1 Пороги срабатывания, верификация и эскалация (инкорпорировано из RISK_ANALYSIS)

Ключевые численные пороги и пути эскалации подняты в тело ТЗ, чтобы §14 был
самодостаточен (не только ссылкой). `RISK_ANALYSIS.md` остаётся расширенным
reference'ом со сценариями.

| # | Порог/метрика (FAIL/WARN) | Верификация | Эскалация |
|---|---|---|---|
| R1 | `canvas − host > 1px` или `mismatches > 0` → **FAIL** | E2E-скриншот-детектор: страница с ≥3 островами разных размеров, сравнение canvas↔host в Chrome/Firefox/Safari; `hydraline audit --check-sizing`; ежемес. ручной прогон на latest beta | Открыть/апдейтить issue в flutter/flutter; временно ограничить до **single-view fallback** (1 остров/страница); участие в ревью PR (#185034) |
| R2 | извлечено `< 90%` узлов → **FAIL**; SSG-прогон 10+ страниц с exception → **FAIL** | Stability-тест: 100 последовательных SSG-прогонов без деградации; репрезентативный набор (блог/лендинг/товар/docs); devtools-diff «какие виджеты не попали в DocumentNode» + `--verbose` | Поверхность (A) → «beta, требует SSG-паттернов»; поверхность (B, pure-Dart) → recommended для prod SSG |
| R3 | TTI 4G `> 5 сек`, LCP `> 2.5 сек`, Lighthouse `< 70`, skeleton-HTML `> 50 KB gzip` → **WARN/регресс-алерт** | Lighthouse CI (throttled, cold-cache 4G) в пайплайне; бюджет-гейты NF-4/NF-4a | Документировать ограничение Flutter Web; progressive enhancement: некритичное → `hydrateOnVisible`, критичное → чистый JS/уровень 1 |
| R4 | появление GA-эквивалента #187663 | Ежеквартальный обзор #187663 и Flutter web roadmap; тест совместимости — конвертация эталонного `DocumentNode` за O(N) | Позиционировать как надстройку (devtools/аудиты/HTMX/хостинг-адаптеры) поверх нативного ядра |
| R5 | `> 0` XSS на 10^6 входов или падение за 60 сек фаззинга → **FAIL** | property/fuzz-тесты; статический анализ на `UnsafeHtmlNode` без санитайзера; ручной пентест перед мажорным релизом | Security-фикс патч-версией ≤ 48 ч + advisory + регрессионный тест на вектор |
| R6 | расхождение `> 5%` текстовых узлов SSG↔hydrated → **WARN** | golden-тесты; devtools-сравнение SSG-HTML ↔ гидрированный DOM (W-19) | Строгое правило: остров **дополняет**, не **заменяет** статику; при осознанной замене — явный `replace: true` + маркер `<!-- hydraline: replaced-by-island -->` |
| R7 | `bytes(buffered) ≠ bytes(concat(chunks))` на детерм. входе → **FAIL** | CI-аудит A8 (C-11 server-integration): `curl` vs `curl -H "User-Agent: Googlebot"`; детектор cloaking в devtools | Классифицировать как misuse (не баг hydraline); образовательный барьер — первая страница доки |
| R8 | `> 0` golden-флейков из-за CRLF/путей за 30 дней → **алерт** | `melos run test:golden` с нормализацией; еженедельный scheduled CI-прогон golden'ов на Windows+Linux | Нормализация `\r\n→\n`; `.gitattributes` (`test/**/goldens/** binary`); `package:path` (`path.posix`) вместо хардкода разделителей |
| R9 | доля вопросов «почему сервер без Flutter?» в issues | ошибка компиляции при импорте `package:flutter` в сервер (граница CI); примеры | README (жирным на первой странице) + диаграмма §6.3; терминология «Dynamic HTML Rendering (pure Dart)»; `analysis_options`-правило для Dart Frog; видеотуториал |
| R10 | остров выше лимита OffscreenCanvas (~4096–16384px) без virtual-режима → **WARN** | devtools-валидатор высоты острова; E2E скролл-тест сегментов | Автосегментация virtual views (§7.7, W-13); порог ~4000px конфигурируем |

---

## 15. Разработка и тестирование

### 15.1 Цикл разработки

```
Brainstorm → Spike (одноразовый прототип) → Заморозка API → TDD (red-green-refactor)
→ Полное покрытие + golden/property/integration → Аудит devtools → Ретро
```

### 15.2 Пирамида тестов

| Уровень | Где | Инструмент | Что покрывает |
|---|---|---|---|
| Unit | core, server | `dart test` | Модель, сериализатор, escaping, sitemap/robots, манифесты |
| Golden (HTML) | core | `dart test` + эталоны | Детерминированный HTML-вывод |
| Property/fuzz | core | `dart test` (генеративные) | Нет XSS на случайных входах |
| Widget | flutter | `flutter test` | Двойная природа `Seo.*`, извлечение в headless, `IslandHost`/`ViewCollection` мультивью |
| Integration | server | `dart test` + shelf/Dart Frog harness | Статусы, редиректы, noindex, кэш, стриминг, **инвариант bot-aware `bytes(buffered)==bytes(concat(chunks))`** |
| Build/SSG | flutter | `flutter test` / CLI e2e | Корректность `dist/`, sitemap, сегменты |
| E2E (браузер) | flutter/web | Playwright/Puppeteer в CI | Гидрация островов, no-JS fallback, CLS, sizing |
| Audit (краулер) | core | CLI | «Что видит краулер», SEO-валидаторы, exit-code |

### 15.3 Порог покрытия

- `hydraline` (core) и `hydraline_server`: ≥ 90% строк/веток
- `hydraline_flutter`: ≥ 80% (с обоснованными исключениями для JS-interop, покрываемого E2E)
- Падение ниже порога — блокирующая ошибка CI

### 15.4 CI-матрица

- Pure-Dart пакеты: Windows-runner + Linux (WSL-эквивалент)
- Flutter-пакет: обе ОС; блокирующие джобы — min (3.22) + latest stable (3.44);
  версии с known-issue (напр. 3.41.x) — отдельный non-blocking джоб (NF-5)
- E2E-браузер: Linux-контейнер CI, локально WSL
- Проверка границ зависимостей (core без Flutter, server без Flutter)

### 15.5 Инструменты качества

- `dart analyze` со строгим `analysis_options` (lints)
- `dart format` в CI (проверка)
- Conventional Commits + melos `version`/`publish`
- `.gitattributes`: `* text=auto eol=lf`; golden-файлы — binary

---

## 16. Дорожная карта фаз

| Фаза | Содержание | Пакеты | Срок | Веха |
|---|---|---|---|---|
| **Phase 0** | Monorepo (melos), CI-матрица Windows/WSL, `analysis_options`, скелеты 3 пакетов, `.gitattributes`, политика версий Flutter | Все | 1-2 нед | CI зелёный на пустых пакетах |
| **Phase 1** | Core: DocumentNode (вкл. details/summary, таблицы), HTML-сериализатор (single-pass + streaming + fragment), escaping + CSP-helper, метаданные, JSON-LD, sitemap, robots, манифесты (island + route), SsgCollector, SEO-валидаторы, CLI-аудит, standalone web-ассеты уровней 0–1 (vanilla + HTMX-glue) | `hydraline` | 5-7 нед | Детерминированный безопасный HTML из модели. Golden + property-тесты проходят. |
| **Phase 2** | Server: shelf + Dart Frog middleware, SSR handler (single-pass streaming), bot-aware buffered/streaming (инвариант идентичности тела), HTMX-хелперы, pure-Dart билдеры (UA-слепые), статусы/редиректы/noindex, кэш, отдача ассетов уровней 0–1 | `hydraline_server` | 3-5 нед | Динамический SSR-маршрут с потоковой доставкой. Интеграционные тесты + инвариант bot-aware. |
| **Phase 3** | Flutter — widgets + extraction: Seo.* (self-registering), Island (3 типа), HydraApp + HydraScope + SsgSandbox, `IslandHost`/`ViewCollection` (мультивью Dart-стороны), island entry-point, go_router + RouteAdapter | `hydraline_flutter` | 4-6 нед | HTML из реального Flutter-дерева. Widget-тесты + мультивью. |
| **Phase 4** | Flutter — islands + SSG + devtools: Custom Element (+scoped-режим), диспетчер, переиспользование vanilla islands из core, Service Worker (WASM streaming/preload), SSG runner/CLI, динамические сегменты, devtools-оверлей, E2E | `hydraline_flutter` | 5-7 нед | Полный hybrid-маршрут: HTML + vanilla-острова + Flutter-острова. E2E проходят. |

**Итого: 18–27 недель (4.5–6.5 месяцев) до полного MVP.**
Нижняя граница (18) — при отсутствии блокеров и параллелизации; верхняя (27) —
консервативная оценка с учётом spike-итераций и E2E-стабилизации. Сумма по фазам:
min = 1+5+3+4+5 = 18; max = 2+7+5+6+7 = 27.

### 16.1 Post-MVP (не блокирует релиз)

- Code-generation для поверхности (A) из аннотированных виджетов (`@HydraPage`)
- Server islands (`server:defer`-аналог)
- **Advanced streaming** (вместе с server islands): out-of-order / fastest-first
  доставка через `<template for="...">` (DPU). Инвариант A8 сужается до
  **статического скелетона документа** (async-регионы островов исключены — это не
  SEO-контент); обязателен fallback для браузеров без DPU (in-order буферизация
  этих регионов); боты получают быстрый статический скелетон и **не блокируются**
  на async-данных островов.
- Инкрементальная SSG
- Расширенные таблицы (colspan/rowspan)
- View Transitions API интеграция

### 16.2 Осознанно отклонённые идеи (из ALTERNATIVES_AND_ADJACENT)

Идеи, рассмотренные при синтезе и **отклонённые** (не «забытые») — с обоснованием,
чтобы решение было воспроизводимым:

| Идея | Источник | Приоритет в источнике | Решение и обоснование |
|---|---|---|---|
| Compile-time separation статики/динамики (кодоген) | Marko | Высокий | **Отклонено для MVP.** Требует `build_runner`/кодогенерации и усложняет DX. Hydraline использует runtime `SsgCollector` (C-9, W-1). Кодоген поверхности (A) через `@HydraPage` — кандидат post-MVP (§16.1). |
| `@HydraIsland('name')`-аннотация + авто-десериализация props | Spark | Средний | **Отклонено для MVP.** Императивный API `Island(id, type, props, ...)` (W-2) покрывает функциональность без кодогена. Аннотации — возможное post-MVP-удобство. |
| Streaming Partials при клиентской навигации | Fresh | Высокий | **Частично покрыто, полное — отклонено.** HTMX-острова (§9) закрывают ~80% задачи (серверные фрагменты без клиентского роутера). Полноценные navigation-partials конфликтуют с NG1 (не владеем роутером). |
| Template inheritance (`tl:extends`-аналог) | Trellis | — | **Отклонено.** Компоновку layout решает разработчик через переиспользуемые `DocumentNode`-билдеры/виджеты; отдельный слой наследования шаблонов избыточен. |
| Functional API `(state) → HTML` / `html`-tagged-template DSL | Enhance | Низкий | **Отклонено.** Модель — типобезопасное `DocumentNode`-дерево (§5), а не строковый DSL; строковый путь противоречит P3 (safety-by-default). |
| `adoptedStyleSheets` (CSSOM) для scoped-стилей | Spark | — | **Отклонено в пользу** CSS `@scope`/атрибутного префикса (§7.6) — работает из HTML без JS-инициализации CSSOM (совместимо с уровнем 0). |
| `prerender: true` пер-роут-флаг | Fresh | — | **Отклонено в пользу** route-манифеста YAML (C-8) — единый декларативный источник режимов/метаданных. |

---

## 17. Критерии приёмки (Definition of Done)

### 17.1 DoD фичи/фазы (ДОЛЖНО)

1. Есть design-note/ADR с зафиксированным решением
2. Публичный API заморожен и задокументирован (dartdoc)
3. TDD-история соблюдена (тесты предшествуют коду)
4. Покрытие ≥ порога (§15.3), CI зелёный на Windows и WSL/Linux
5. `dart analyze` без ошибок; `dart format` соблюдён
6. Границы зависимостей соблюдены (core/server без Flutter)
7. Обновлены примеры и документация; CHANGELOG-энтри
8. Для UI/гидрации — E2E и devtools-аудит проходят

### 17.2 Приёмочные сценарии (E2E, ДОЛЖНО)

1. **A1.** `curl`/`view-source` `document`-маршрута → валидный HTML с
   title/meta/og/JSON-LD/заголовками/ссылками **без JS**.
2. **A2.** Соц-превью (OG/Twitter) строится симулятором бота — теги в исходнике.
3. **A3.** `hybrid`-маршрут: статический контент виден сразу; vanilla-острова
   работают мгновенно; Flutter-остров гидрируется по директиве; CLS ≈ 0.
4. **A4.** Существующее `app`-приложение работает **без изменений** после
   подключения hydraline (аддитивность).
5. **A5.** `sitemap.xml` и `robots.txt` валидны и соответствуют route-манифесту.
6. **A6.** SSR отдаёт корректные статусы/редиректы/`noindex`.
7. **A7.** No-JS: страница остаётся осмысленной и навигируемой.
8. **A8.** Один и тот же контент боту и пользователю. На фиксированном
   (детерминированном) входе проверяется инвариант
   `bytes(buffered-ответ для UA=Googlebot) == bytes(конкатенация chunked-ответа
   для обычного UA)` — тело побайтово идентично, отличается лишь `Transfer-Encoding`
   (bot-aware streaming, §6.5 — тот же HTML, разная стратегия доставки).
9. **A9.** На странице без островов `flutter_bootstrap.js` не загружается.
10. **A10.** HTMX-остров получает HTML-фрагмент с сервера и заменяет DOM без
    перезагрузки страницы и без Flutter-движка.

---

## 18. Решённые архитектурные вопросы

| # | Вопрос | Решение | Фаза |
|---|---|---|---|
| Q1 | Headless binding | `flutter_tester` + `AutomatedTestWidgetsFlutterBinding`. Self-registering виджеты через `SsgCollector`. Поверхность (B) как fallback. | Phase 1 (collector), Phase 3 (sandbox) |
| Q2 | Route manifest | YAML (`hydraline.routes.yaml`) как primary; Dart builder как опциональный генератор | Phase 0 (схема), Phase 1 (модель) |
| Q3 | Роутеры | `go_router` first-class; `RouteAdapter`-интерфейс для auto_route, Navigator 2.0; `beamer` не поддерживается (заморожен) | Phase 3 |
| Q4 | DocumentNode | Базовые ноды + таблицы + details/summary (Phase 1, т.к. details нужны для уровня 0). Расширенные таблицы, figure — post-MVP. Raw-HTML = opt-in UnsafeHtmlNode | Phase 1 |
| Q5 | Server islands | Post-MVP | — |
| Q6 | Props в остров | JSON-safe простые типы; `data-state` атрибут; лимит ~10 KB/остров с предупреждением; полный контракт §7.8 | Phase 4 |
| Q7 | Версии Flutter | Скользящее окно из 3 stable; min 3.22; CI на min + latest; 3.41.x — с оговоркой (R1) | Phase 0 |
| Q8 | Multi-view sizing | Custom Element с фиксированными px-размерами + явные viewConstraints (§7.1); scoped-режим для массовых островов (§7.6) | Phase 4 |
| Q9 | Интерактивность | Три уровня: статика → vanilla/HTMX → Flutter (§4.3, §8, §9) | Phase 2 (HTMX), Phase 4 (vanilla + Flutter) |
| Q10 | Bot vs User доставка | Двухслойность (§6.5): контент UA-слепой (builder без UA), транспорт ветвится по UA (buffered/chunked). Тело идентично, инвариант в CI. | Phase 2 |

---

## Приложение A. Проверенные источники

**Flutter:**
- #187663 — route-level document rendering (open, design-doc)
- #46789 — SEO indexability (610 👍, open)
- #183992 — «делайте как community package»
- #171598, #181127 — closed (duplicate / out-of-scope)
- #185034 — multi-view sizing regression (open, PR в ревью)
- #175892 — OffscreenCanvas limit (open)
- #137444 — dynamic view sizing (implemented)
- #138930 — multi-view JS API (реализовано, Flutter 3.22+)
- #145954 — HTML renderer deprecation

**Документация и практика:**
- Flutter docs — multi-view embedding, `addView`/`removeView`, `ViewCollection`
- StackOverflow #78236026 — OG-теги не видны в view-source
- Astro docs — islands architecture, client directives
- Jaspr docs — Dart SSR framework
- Spark Framework — Dart SSR + Custom Elements + DSD
- Trellis — pure-Dart HTMX + SSG

**Индустриальные источники:**
- Qwik — resumability, Qwikloader, function-level code splitting
- Marko (eBay) — single-pass SSR, compile-time reactivity, out-of-order streaming (с 2014)
- Fresh (Deno) — zero-JS by default, streaming partials, View Transitions
- SolidStart — fine-grained reactivity + islands, `clientOnly`
- Enhance — SSR Web Components как чистые функции
- Stencil — compiler-based vs runtime SSR, scoped mode
- Chrome DPU — Declarative Partial Updates (`<template for="...">`)
- Declarative Shadow DOM — Web Standard (Baseline 2024)
- Nuxt — bot-aware streaming (#34411)
- Columbo — completion-order streaming (Rust)
- ParetoJS — defer() + Await для streaming SSR
- Litro — DSD + streaming SSR

**Инструменты (2026):**
- `melos` ≥ 7 (pub workspaces, Dart ≥ 3.6)
- `dart_frog` (≈1.2.x, поверх `shelf`)
- `shelf` — HTTP middleware

---

## Приложение B. Глоссарий

- **App-shell** — минимальный HTML-каркас без контента, загружающий SPA
- **CanvasKit / Skwasm** — WebGL/WASM-рендереры Flutter Web
- **Cloaking** — отдача разного контента боту и пользователю; наказуемо. **Запрещено.**
  Bot-aware streaming (тот же контент, разная доставка) — не cloaking.
- **CLS** — Cumulative Layout Shift
- **Custom Element** — нативный Web API для создания собственных HTML-элементов
- **Declarative Partial Updates (DPU)** — браузерный механизм out-of-order
  обновления DOM через `<template for="...">`
- **Declarative Shadow DOM (DSD)** — Shadow DOM, создаваемый из HTML (без JS)
- **Hydration** — оживление pre-rendered HTML клиентским кодом
- **Island** — изолированная интерактивная зона на статической странице.
  Типы: `flutter`, `vanilla`, `htmx`.
- **Resumability** — возобновление состояния без пересчёта (Qwik-модель)
- **SSG / SSR** — Static Site Generation (build-time) / Server-Side Rendering (request-time)
- **`DocumentNode`** — узел абстрактного дерева семантического документа
- **`SsgCollector`** — коллектор для self-registering виджетов
- **`WebRouteRenderMode`** — режим маршрута: `app` / `document` / `hybrid`
- **HTMX** — библиотека для гипермедиа-управляемой интерактивности (HTML-фрагменты с сервера)
- **Vanilla Island** — интерактивная зона, оживляемая чистым JS (~8 KB), без Flutter

---

## Приложение C. История версий

| Версия | Дата | Изменения |
|---|---|---|
| 1.0 | 2026-07 | Исходное ТЗ: проблема, архитектура, 6 пакетов, 9 фаз |
| 2.0 | 2026-07 | MITIGATION_PLAN: Custom Element, self-registering, 3 уровня, 3 пакета |
| **3.0** | **2026-07** | **Итоговое ТЗ — синтез всех исследований.** Добавлены: HTMX-острова, vanilla islands, resumable-модель, Qwikloader-style диспетчер, single-pass сериализатор, bot-aware streaming, Deferred Imports, DPU out-of-order стриминг, scoped-режим, clientOnly. 3 пакета, 5 фаз, 10 приёмочных сценариев. |
| **3.1** | **2026-07** | **Устранение противоречий, доведение до состояния «без узких мест».** Исправлено: (1) арифметика сроков 18–27 (было 18–25); (2) противоречие «UA-барьер vs bot-aware» → двухслойная модель §6.5 + инвариант идентичности тела; (3) возвращён `IslandHost`/`ViewCollection` (Dart-мультивью, W-6) и отдельный island entry-point (W-7); (4) расслоение web-ассетов §6.2.1 — уровни 0–1 в core, проект без Flutter не тянет Flutter-пакет; (5) реализован scoped-режим §7.6 (был в changelog, отсутствовал в теле); (6) устранено противоречие details/summary (перенесены в Phase 1); (7) уточнён single-pass (не «по образцу Marko» дословно); (8) возвращены CSP, WASM streaming, бюджет бандла островов NF-4a, hydrateManual, оговорка Flutter 3.41, исключение beamer, сводный SEO-чек-лист §5.7. |
| **3.2** | **2026-07** | **Финальная вычитка — закрыты последние пробелы.** (1) заголовок документа синхронизирован с полем версии; (2) добавлен §7.7 Virtual views (обход лимита OffscreenCanvas 16384px, R10) + W-13; (3) добавлен §7.8 — единый контракт props/`data-state` (типы, детерминизм, лимит, `IslandProps.of`, ADR Q6); (4) `ResizeObserver`-корректор внесён в механизм §7.1 и W-8 (ранее был только в R1). Перенумерованы W-13…W-19. |
| **3.3** | **2026-07** | **Устранение оставшихся нестыковок и пробелов.** (1) снят конфликт S-4 ⟂ S-5/A8: MVP-стриминг сделан **in-order прогрессивным flush** (инвариант `bytes(buffered)==bytes(concat(chunks))` верен по построению), out-of-order/DPU/fastest-first вынесены в Advanced streaming (§16.1) с суженным инвариантом и non-DPU fallback; (2) CI-матрица Flutter: блокирующие min+latest, known-issue-версии informational (NF-5, §15.4); (3) `ResizeObserver`-корректор уточнён (pinned `min==max`, rAF-коалесинг, no-op на 3.41.x) — не воспроизводит #185034; (4) C-9: «зона-скопированный» → инстанс-скопированный через `HydraScope`; (5) NF-4: base/условный JS, hard-cap, virtual-views бюджет; (6) HTMX self-hosted (совместимо с CSP); (7) `clientOnly` → ось `renderMode` (ортогональна директиве), уточнены `hydrateOnLoad`/`hydrateManual`; (8) состав 450 KB (без wasm) — §7.3/W-7/NF-4a; (9) sitemap: `SitemapSource` + sitemap-index (C-6); (10) SEO-дефолты `app`-маршрутов (§4.1/S-2); (11) новые §7.9 (жизненный цикл/ошибки гидрации) и §7.10 (a11y островов), W-9/NF-7; (12) SSR требует предсобранный island-бандл (S-10/§6.4); (13) C-11 — два режима аудита. |
| **3.4** | **2026-07** | **Точечная доводка после кросс-сверки со всеми исходными доками.** (1) **Ответственность за размещение Flutter-ассетов** сделана явной: SSG-раннер W-14 — единственный, кто копирует island-бандл + `web/`-ассеты в `dist/` (при наличии Flutter-островов); при SSR — сервер/CDN отдаёт предсобранный бандл (S-10); §6.4 SSG-диаграмма дополнена шагами сборки/копирования; W-17 — rewrite/fallback-рекомендации хостингов. (2) Снят конфликт метрики TTI Flutter-острова: §4.3 и NF-3 приведены к «холодный 4G ~3-5 сек / холодный 3G ~10-19 сек / тёплый ~1 сек». (3) В тело §14 добавлен §14.1 — пороги (R1 >1px, R2 ≥90%/100-runs, R3 LCP<2.5/Lighthouse≥70/skeleton<50KB, R5 XSS, R6 >5%, R8 30-дн флейки, R10 limit), верификация и пути эскалации (в т.ч. single-view fallback R1) — раньше делегировались в RISK_ANALYSIS. (4) NF-3 расширен: LCP<2.5, Lighthouse≥70, skeleton-HTML<50KB gzip. (5) NF-8: locale-invariance + `package:path`. (6) NF-11: полная pub.dev-готовность (example/dartdoc/`>=`/topics). (7) новый §16.2 — осознанно отклонённые идеи (Marko compile-time separation, Spark `@HydraIsland`/`adoptedStyleSheets`, Fresh partials/`prerender`-флаг, Trellis template inheritance, Enhance functional DSL) с обоснованием. |
| **3.5** | **2026-07** | **Закрытие архитектурных пробелов в SSG и ассетах.** (1) W-16 — раскрыта среда исполнения SSG-раннера: CLI-команда работает не как plain `dart run`, а через `flutter test`-харнесс (или Flutter-скомпилированный executable), инициализирующий `AutomatedTestWidgetsFlutterBinding`; разработчику не нужно знать деталей бутстрапа, но зависимость от Flutter SDK для SSG явно задокументирована. (2) S-10 — требование **абсолютных** путей (`/flutter_bootstrap.js`, `/main.dart.js`, `/canvaskit/`) или `<base href>` для загрузки ассетов на вложенных path-маршрутах; ранее некорректно упрощалось до «корректных путей» без спецификации абсолютности. |
| **3.6** | **2026-07** | **Финальная кросс-сверка спека ↔ замороженные L4-API: устранены нейминг-рассинхроны.** (1) §5.1 приведён к фактическим типам узлов: якорь — `AnchorNode` (`<a>`), `LinkNode` зарезервирован под `<head>`-овый `<link rel href>`; секции — единый `SectionNode` с осью `SectionRole` (вместо мнимых `ArticleNode`/`NavNode`/…); корень — `DocumentRootNode`; `ListNode → ListItemNode`. (2) Дублирующийся enum `SectionKind` (flutter) заменён на переиспользование core-`SectionRole` (`widgets.dart`). (3) `ARCHITECTURE.md §4.1/§4.3` синхронизированы с L4-API (пример строит `DocumentRootNode(head:, body:)`, `MetaNode(property:…)`, `SectionRole.main`). (4) `content_source: widget` — `WidgetContent.pageBuilderId` сделан опциональным; JSON-схема допускает `widget` и `widget:<Id>`. (5) JSON-LD FAQ унифицирован: тип `FAQPage`, метод `JsonLd.faq` (убраны разночтения `FAQ`/`Faq`). (6) NF-5 — разведены «окно активной поддержки» (3.44/3.41/3.38) и «CI-джобы» (только min 3.22 + latest 3.44 блокирующие; 3.41 informational; 3.38 без постоянного джоба). |

---

*Конец ТЗ v3.6. Документ является окончательной спецификацией для начала
реализации. Декомпозиция на детальные задачи — следующий шаг.*
