# Hydraline — Phase 1: Core `hydraline` (L3)

| Поле | Значение |
|---|---|
| Цель | Детерминированный безопасный HTML из модели; полный SEO-набор из ядра |
| Срок | 5–7 недель |
| Веха | Golden + property-тесты зелёные; `DocumentNode → HTML` детерминирован и безопасен |
| Пакет | `hydraline` (pure Dart, без `dart:ui`) |
| Базис | `ARCHITECTURE.md` §4–§9, спека C-1…C-13 |
| Предусловия | Phase 0 gate пройден |

> Инварианты: N1–N5, S1–S5, SER1–SER5, SM1, RM1, CO1–CO4, I1/I2/I4.

---

## Задачи

| ID | Задача | Зависит | Приёмка | Оценка |
|---|---|---|---|---|
| P1-01 | `DocumentNode` (sealed) + иерархия-скелет (§4.1); сериализатор — исчерпывающий `switch` по типу узла, без внешнего visitor'а | — | N1/N4/N5; unit на контракт узла | 2 |
| P1-02 | `escaping.dart`: `escapeHtmlText`/`escapeHtmlAttribute` + `SafeUrl` (allowlist схем) | — | S1–S3; unit на векторах | 2 |
| P1-03 | Блочные/инлайн узлы: heading, paragraph, text, anchor(`SafeUrl`), image(`SafeUrl`), list, section/article/nav/header/footer/main, blockquote, pre/code, time | P1-01,P1-02 | N3 (нельзя сконструировать с непроверенным URL); unit на каждый | 4 |
| P1-04 | Табличные узлы: `TableNode`/`TableRowNode`/`TableCellNode(header)` (текст в ячейках) | P1-01 | Q4; unit + golden | 1.5 |
| P1-05 | `DetailsNode`/`SummaryNode` (no-JS аккордеон, нужен уровню 0/vanilla) | P1-01 | Q4/§4.3; golden | 1 |
| P1-06 | Островные узлы: `IslandPlaceholderNode`,`HtmxIslandNode`,`VanillaIslandNode` + `IslandSpec`/`IslandSize`/`HydrationDirective`/`IslandRenderMode`/`IslandStyleMode` | P1-01 | C-7; сериализуются в корректные плейсхолдеры | 2 |
| P1-07 | `UnsafeHtmlNode` (opt-in) + хук санитайзера + предупреждение валидатора при его отсутствии | P1-01 | S3; unit + warning-тест | 1 |
| P1-08 | `HtmlSerializer.serialize` (single-pass, детерминированный) + golden-инфраструктура (нормализация `\n`) | P1-03,P1-04,P1-05,P1-06 | SER1–SER3/SER5, I4; golden-набор | 3 |
| P1-09 | `serializeToStream` (in-order, прогрессивный flush) + тест идентичности тела | P1-08 | SER4 (`serialize==concat(stream)`) | 2 |
| P1-10 | `serializeFragment` (без `<html>/<head>`) для HTMX | P1-08 | C-4; golden на фрагмент | 1 |
| P1-11 | `metadata.dart`: `SeoMeta`, OG (полный), Twitter Card, произвольные `<meta>`/`<link>`, charset/viewport/lang/hreflang | P1-02 | C-2/SEO-1,2,3,8; golden на `<head>` | 2 |
| P1-12 | `structured_data.dart`: JSON-LD билдеры (Article/Product/BreadcrumbList/WebPage/Organization/FAQPage/Event/Recipe/Review + Raw) | P1-02 | C-3/SEO-4; golden на `ld+json` | 2.5 |
| P1-13 | `sitemap.dart` + `SitemapSource`/`SitemapEntry` + автосплит в sitemap-index (>50k URL / >50MB) | P1-02 | C-6/SM1/SEO-5; unit на порог сплита | 2 |
| P1-14 | `robots.txt`-генератор | — | C-6/SEO-6; unit | 0.5 |
| P1-15 | `route_manifest.dart`: парсер `hydraline.routes.yaml` + Dart-builder (тот же YAML) | P1-11 | C-8/RM1; round-trip YAML↔модель | 2.5 |
| P1-16 | `island_manifest.dart`: сериализация/десериализация + контракт `data-state` (типы/лимит) | P1-06 | C-7/DS1–DS4; property на JSON-safe | 2 |
| P1-17 | `SsgCollector` (pure Dart, инстанс-скопированный, `seal()`, dedup по key, N5-проверка) | P1-03,P1-06 | CO1/CO4; unit на изоляцию инстансов и dedup | 2 |
| P1-18 | `validators.dart`: длины title/description, обязательность alt, дубли canonical, битые hreflang | P1-11 | C-10/SEO-11; unit | 1.5 |
| P1-19 | `audit.dart` — standalone-режим (view-source, метаданные/OG/JSON-LD, валидаторы, exit-code) | P1-12,P1-18 | C-11(a)/A1/A2; CLI e2e на example-HTML | 2.5 |
| P1-20 | `audit.dart` — server-integration-режим (сравнение buffered↔chunked, каркас A8) | P1-19 | C-11(b); юнит на компаратор (полный A8 — Phase 2) | 1 |
| P1-21 | Property/fuzz XSS-набор (glados + fuzz), тег `security` | P1-08 | I2/S4 (0 XSS/10^6, 0 падений/60с) | 2 |
| P1-22 | Web-ассеты L0–L1: vanilla islands (~8 KB) + HTMX-glue, сборка + поставка как file/string-ассеты | P1-08 | C-12/§13; размер ≤8 KB (бюджет-гейт); юнит на наличие ассета | 3 |

**Итого: ~25.5 д (нижняя) — до ~35 д с golden-стабилизацией и property-итерациями.**

---

## Выходной гейт фазы (ДОЛЖНО)
1. Golden-набор стабилен на Windows + Linux (I4/I10).
2. Property/fuzz: 0 XSS на 10^6 входов, 0 падений за 60с (I2).
3. `serialize == concat(serializeToStream)` (SER4) — доказано тестом.
4. Обе ветки sitemap-источника + автосплит работают (SM1).
5. CLI-аудит standalone возвращает корректный exit-code (A1/A2 на статике).
6. Покрытие core ≥ 90% (I9).

## Приёмочные сценарии, покрываемые (частично)
- **A1** (валидный HTML без JS) — на сгенерированном ядром HTML.
- **A2** (OG/Twitter в исходнике) — через аудит.
- **A5** (sitemap/robots) — генераторы + валидность.
- **A7** (no-JS осмысленность) — семантика узлов.

## Риски, затрагиваемые фазой
- **R5** (XSS) — закрывается P1-02/P1-07/P1-21.
- **R8** (golden-флейки) — P1-08 инфраструктура нормализации.

---

*Следующая фаза: `PHASE_2_PLAN.md` (Server).*
