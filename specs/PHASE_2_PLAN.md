# Hydraline — Phase 2: Server `hydraline_server` (L3)

| Поле | Значение |
|---|---|
| Цель | Динамический SSR-маршрут с потоковой доставкой и bot-aware транспортом |
| Срок | 3–5 недель |
| Веха | SSR-маршрут стримит HTML; инвариант идентичности тела зелёный в CI |
| Пакет | `hydraline_server` (pure server Dart, без `flutter`) |
| Базис | `ARCHITECTURE.md` §10, спека S-1…S-11, §6.5 |
| Предусловия | Phase 1 gate (нужны сериализатор, манифесты, аудит-компаратор) |

> Инварианты: SRV1–SRV4, I1, I3.

---

## Задачи

| ID | Задача | Зависит | Приёмка | Оценка |
|---|---|---|---|---|
| P2-01 | shelf-middleware + матч маршрута по route-манифесту (document/hybrid/app) | P1-15 | S-1/S-2; unit на маршрутизацию | 2 |
| P2-02 | Контракт `DocumentBuilder(req, data)` — **без** `User-Agent` + регистрация билдеров | P2-01 | S-3/SRV1; компиляционно нет доступа к UA в билдере | 1.5 |
| P2-03 | Single-pass **in-order** стриминговый handler (прогрессивный flush: shell→статика→острова) | P2-02,P1-09 | S-4/SRV3; порядок чанков детерминирован | 2.5 |
| P2-04 | Bot-aware доставка: buffered (боты, `Content-Length`) / chunked (юзеры, `Transfer-Encoding`) + идентичность тела | P2-03 | S-5/SRV2/**I3**; `bytes(buffered)==bytes(concat(chunks))` | 2.5 |
| P2-05 | HTTP-семантика: 200/301/302/404/410/5xx, редиректы, `X-Robots-Tag`/`noindex`, канонизация путей | P2-01 | S-7/SEO-9/A6; integration | 2 |
| P2-06 | Кэширование: `Cache-Control`/`ETag`, TTL, in-memory + pluggable | P2-03 | S-8; integration на hit/miss/ETag | 2 |
| P2-07 | HTMX-хелперы: `renderFragment()`, `HtmxResponse`, `HtmxTrigger` | P1-10 | S-6/A10 (серверная часть); unit | 1.5 |
| P2-08 | Отдача `sitemap.xml`/`robots.txt` + L0–L1 core-ассетов (vanilla, self-hosted HTMX) без Flutter | P1-13,P1-14,P1-22 | S-9/§13; корректный content-type/кэш | 1.5 |
| P2-09 | `flutter_assets`: встраивание island-манифеста + **абсолютные** пути к движку (`/main.dart.js`,`/canvaskit/`) / `<base href>` | P1-16 | S-10; пути абсолютны на вложенных маршрутах | 1.5 |
| P2-10 | Адаптер Dart Frog поверх той же логики | P2-01 | S-1; integration через Frog-harness | 1.5 |
| P2-11 | Дефолты `app`-маршрутов: `noindex` + исключение из sitemap + опц. document-fallback для ботов | P2-01,P2-05 | S-2/§4.1; unit | 1 |
| P2-12 | Integration-harness (shelf + Frog) + подключение **A8** в CI | P2-04 | I3/A8 в пайплайне (`curl` vs `curl -H Googlebot`) | 2 |

**Итого: ~21.5 д (нижняя) — до ~25 д с harness-стабилизацией.**

---

## Выходной гейт фазы (ДОЛЖНО)
1. Динамический `document`/`hybrid` SSR-маршрут отдаёт корректный HTML.
2. **I3/A8** зелёный: тело побайтово идентично для бота и юзера (§6.5).
3. Статусы/редиректы/noindex корректны (A6).
4. Билдер контента компиляционно UA-слеп (SRV1).
5. Абсолютные пути к ассетам на вложенных маршрутах (S-10).
6. Покрытие server ≥ 90% (I9).

## Приёмочные сценарии, покрываемые
- **A6** (статусы/редиректы/noindex) — полностью.
- **A8** (идентичность тела бот↔юзер) — полностью.
- **A10** (HTMX-фрагмент) — серверная часть (клиент — Phase 4).
- **A1/A5** — теперь и через живой SSR/эндпоинты.

## Риски, затрагиваемые фазой
- **R7** (cloaking) — архитектурно исключён (SRV1 + I3).
- **R9** (сервер без Flutter) — форсируется I1 (нет `package:flutter`).

---

*Следующая фаза: `PHASE_3_PLAN.md` (Flutter widgets + extraction).*
