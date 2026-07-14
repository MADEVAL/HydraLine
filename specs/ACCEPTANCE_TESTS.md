# Hydraline — Приёмочные тесты (A1–A10)

| Поле | Значение |
|---|---|
| Базис | `HYDRALINE_SPEC_V3.md` §17.2, `REQUIREMENTS_TRACEABILITY.md §5`, `EXAMPLES.md` |
| Назначение | Перевести приёмочные сценарии в исполнимые E2E-проверки (Given/When/Then) |
| Инструменты | Playwright (браузер), `curl`/HTTP-клиент, CLI-аудит (C-11), Lighthouse CI |
| Гейт | Все A1–A10 зелёные = условие релиза MVP (`PHASE_4_PLAN` выходной гейт) |

> Все проверки — на детерминированных эталонных примерах (`EXAMPLES.md`). Каждый
> сценарий указывает пример-фикстуру, фазу готовности и связанный инвариант.

---

## A1 — Валидный HTML без JS
- **Фикстура:** Blog `/blog/:slug` · **Фаза:** 1(core)+2/4 · **Инвариант:** I4
```
Given маршрут document
When  GET без исполнения JS (view-source / curl)
Then  тело содержит <title>, <meta name=description>, og:*, twitter:*,
      <script type=application/ld+json>, h1..h6, <a href>, <img alt>
And   HTML детерминирован (совпадает с golden)
```
**Проверка:** `curl` + парс DOM в Playwright с `javaScriptEnabled:false`; `hydraline audit --standalone`.

## A2 — Соц-превью строится (OG/Twitter в исходнике)
- **Фикстура:** Blog · **Фаза:** 1
```
Given страница с OpenGraph и Twitter Card
When  симулятор бота забирает HTML (без JS)
Then  og:title/description/image/url и twitter:card присутствуют в view-source
```
**Проверка:** `hydraline audit --standalone <url>` → exit 0, отчёт содержит теги.

## A3 — Hybrid: статика мгновенно, острова по директиве, CLS≈0
- **Фикстура:** Product `/product/:id` · **Фаза:** 4 · **Инвариант:** I8
```
Given hybrid-маршрут с vanilla+HTMX+Flutter островами
When  страница открыта в браузере
Then  статический контент виден сразу (FCP)
And   vanilla-острова интерактивны ~мгновенно
And   Flutter-остров гидрируется по своей директиве (onVisible)
And   CLS ≤ 0.02 (зарезервированные размеры)
```
**Проверка:** Playwright timeline + Lighthouse CI (CLS-ассерт).

## A4 — `app`-приложение работает без изменений (аддитивность)
- **Фикстура:** Product (рядом `app`-маршрут дашборда) · **Фаза:** 3
```
Given существующее Flutter app-приложение + подключён hydraline
When  открыт app-маршрут
Then  приложение работает как прежде (CanvasKit), hydraline ничего не ломает
```
**Проверка:** widget/integration + smoke-E2E на app-маршруте.

## A5 — sitemap.xml и robots.txt валидны и соответствуют манифесту
- **Фикстура:** Blog/Docs · **Фаза:** 1+2
```
Given route-манифест
When  сгенерированы sitemap.xml и robots.txt
Then  все document/hybrid-маршруты в sitemap; app-маршруты исключены
And   sitemap проходит XSD-валидацию; при >50k URL — sitemap-index (SM1)
And   robots.txt ссылается на sitemap
```
**Проверка:** XML-схема-валидатор + сверка с манифестом; отдельный тест автосплита.

## A6 — SSR: корректные статусы/редиректы/noindex
- **Фикстура:** Product · **Фаза:** 2
```
Given SSR-маршруты
When  запрос существующего/несуществующего/перемещённого пути
Then  200 / 404 / 301|302 соответственно; 410 для удалённого; 5xx при ошибке
And   noindex-маршрут отдаёт meta noindex + X-Robots-Tag
```
**Проверка:** integration-тесты HTTP-семантики.

## A7 — No-JS: страница осмысленна и навигируема
- **Фикстура:** Blog/Docs · **Фаза:** 4
```
Given любой document-маршрут
When  браузер с отключённым JS
Then  контент читается, ссылки/навигация работают, аккордеоны (<details>) работают
```
**Проверка:** Playwright `javaScriptEnabled:false` + проверка кликов по ссылкам.

## A8 — Идентичность тела бот↔юзер (не cloaking) ⭐
- **Фикстура:** Product · **Фаза:** 2 · **Инвариант:** I3
```
Given детерминированный вход
When  запрос с UA=Googlebot (buffered) и обычным UA (chunked)
Then  bytes(buffered) == bytes(concat(chunks))   // тело побайтово идентично
And   отличается только Transfer-Encoding
```
**Проверка:** `hydraline audit --server-integration`; integration-сравнение байтов; CI-гейт джоб 7.

## A9 — Нет островов → нет `flutter_bootstrap.js` ⭐
- **Фикстура:** Blog/Docs · **Фаза:** 4 · **Инвариант:** I6/AS1
```
Given страница без IslandType.flutter
When  страница загружена
Then  flutter_bootstrap.js НЕ запрошен; Flutter-движок не грузится
```
**Проверка:** Playwright network-лог (нет запроса bootstrap/main.dart.js/canvaskit).

## A10 — HTMX-остров без перезагрузки и без движка
- **Фикстура:** Landing/Product · **Фаза:** 2+4
```
Given HTMX-остров (hx-get)
When  срабатывает триггер
Then  сервер отдаёт HTML-фрагмент (без <html>/<head>)
And   DOM заменяется без перезагрузки страницы и без загрузки Flutter-движка
```
**Проверка:** Playwright (нет navigation-события, нет bootstrap-запроса) + fragment-тест сервера.

---

## Сводная таблица прогона

| # | Фикстура | Инструмент | Фаза | Инвариант | CI-джоб |
|---|---|---|---|---|---|
| A1 | Blog | curl + Playwright + audit | 1/2/4 | I4 | audit, e2e |
| A2 | Blog | audit | 1 | — | audit |
| A3 | Product | Playwright + Lighthouse | 4 | I8 | e2e |
| A4 | Product/app | widget + e2e | 3 | — | flutter, e2e |
| A5 | Blog/Docs | XML-валидатор | 1/2 | SM1 | test |
| A6 | Product | integration | 2 | — | test:server |
| A7 | Blog/Docs | Playwright (no-JS) | 4 | — | e2e |
| A8 | Product | audit + integration | 2 | **I3** | test:server |
| A9 | Blog/Docs | Playwright (network) | 4 | **I6** | e2e |
| A10 | Landing/Product | Playwright + fragment | 2/4 | — | e2e, test:server |

**Условие релиза MVP:** все 10 зелёные + инварианты I1–I10 (см. `ARCHITECTURE.md §15`).

---

*Изменение сценариев синхронизируется с `HYDRALINE_SPEC_V3.md §17.2` и `EXAMPLES.md`.*
