# Hydraline — Бюджеты производительности и их измерение

| Поле | Значение |
|---|---|
| Базис | `HYDRALINE_SPEC_V3.md` NF-1..NF-4a, NF-3, §4.3, R3; `RISK_ANALYSIS.md` R3 |
| Назначение | Свести все перф-бюджеты в один контроль + определить, чем и как они меряются |
| Правило | Превышение любого hard-cap → **регрессионный алерт CI** (блокирующий для JS-бюджетов) |

---

## 1. JS-бюджеты (min+gzip, NF-4) — hard-caps

| Ассет | Cap | Уровень | Грузится |
|---|---|---|---|
| Диспетчер | ≤ 2 KB | 2 (база) | при наличии Flutter-островов |
| Custom Element | ≤ 2 KB | 2 (база) | при наличии Flutter-островов |
| Service Worker | ≤ 2 KB | 2 (база) | при наличии Flutter-островов |
| **Базовый L2 собственный JS** | **≤ 6 KB** | 2 | сумма трёх выше |
| Vanilla Islands | ≤ 8 KB | 1 | при наличии vanilla-островов |
| HTMX (vendored, self-hosted) | ~14 KB | 1 | при наличии HTMX-островов |
| Virtual-views менеджер | ≤ 2 KB | 2 (deferred) | только на странице с virtual-островом |

**Инвариант AS1:** уровни 0–1 **не тянут** базовый L2-JS. Нет Flutter-островов →
`flutter_bootstrap.js` не вставляется (`I6`/`A9`).

## 2. Бюджет бандла островов (NF-4a)

| Компонент | Бюджет |
|---|---|
| Базовый island JS-бандл (`main.dart.js` entry + runtime glue + `IslandHost`) | ≈ **450 KB** gzip (без `canvaskit.wasm` и deferred-чанков) |
| `canvaskit.wasm` | ~1.1 MB (отдельно, SW/CDN-кэш) |
| Один остров + уникальные зависимости (deferred-чанк) | < 100 KB gzip (иначе devtools рекомендует code-split) |
| Рост `main.dart.js` между версиями hydraline | ≤ **5%** (регресс-тест) |
| Для сравнения: полное приложение | ≈ 2.5 MB |

## 3. Core Web Vitals и время (NF-3)

| Метрика | Цель | Условие |
|---|---|---|
| FCP | < 1 сек | статический HTML (уровень 0) |
| LCP | < 2.5 сек | `document`/`hybrid` |
| CLS | ≈ 0 | зарезервированные px-размеры островов (`I8`) |
| TTFB | < 100 мс | стриминговый SSR (первый чанк — shell) |
| SSR median рендер | < 50 мс | `document`-маршрут без учёта данных (`NF-1`) |
| Lighthouse (mobile, throttled) | ≥ 70 | `document`/`hybrid` |
| Skeleton-HTML острова (до гидрации) | < 50 KB gzip | — |

### TTI Flutter-острова (честные цифры, §4.3)
| Сценарий | TTI |
|---|---|
| Холодный кэш, 4G | ~3–5 сек (target < 5) |
| Холодный кэш, 3G | ~10–19 сек (деградация — причина трёх уровней) |
| Тёплый кэш (SW) | ~1 сек |

> На 3G Flutter-остров медленный **by design** Flutter Web — поэтому критичный
> интерактив уводится на уровни 0–1 (vanilla/HTMX), а тяжёлый Flutter — по директиве
> (`hydrateOnVisible`/`hydrateOnInteraction`).

---

## 4. Как измеряется (инструменты и гейты)

| Бюджет | Инструмент | Где | Гейт |
|---|---|---|---|
| JS hard-caps (NF-4) | bundle-size проверка (gzip) собственных ассетов | CI, Phase 1/4 | блокирующий алерт при превышении |
| Island-бандл 450 KB / +5% | размер `main.dart.js` (сборка `--target`) | CI, Phase 3/4 | регресс-алерт |
| Deferred-чанк < 100 KB | devtools-предупреждение | dev + CI | warning |
| LCP/CLS/TTI/Lighthouse≥70 | **Lighthouse CI** (throttled, cold-cache 4G) | E2E-джоб, Phase 4 (P4-15) | WARN/регресс-алерт (R3) |
| Skeleton-HTML < 50 KB | размер сериализованного скелетона | Phase 1 | warning |
| SSR median < 50 мс | микробенч сериализатора/handler'а | Phase 1/2 | бенч-отчёт |
| TTFB < 100 мс | замер первого чанка стриминга | Phase 2 | integration |
| canvas−host ≤ 1px (sizing) | E2E-скриншот-детектор, 3 браузера | Phase 4 (`I7`) | FAIL при >1px |

### Lighthouse CI — конфигурация (ориентир)
- Профиль: mobile, throttled 4G, cold cache.
- Прогон на эталонных примерах (`EXAMPLES.md`): Blog/Docs — perf ≥ 90 ожидаемо
  (нет Flutter), Product (hybrid) — perf ≥ 70.
- Ассерты: `categories:performance ≥ 0.70`, `cumulative-layout-shift ≤ 0.02`,
  `largest-contentful-paint ≤ 2500`.

---

## 5. Пороги регрессии и эскалация (R3, §14.1)

| Триггер | Порог | Действие |
|---|---|---|
| TTI 4G | > 5 сек | документировать; критичное → уровень 1/чистый JS |
| LCP | > 2.5 сек | оптимизация скелетона/preload |
| Lighthouse | < 70 | анализ бандла, code-split |
| Skeleton-HTML | > 50 KB gzip | сократить fallback |
| Рост `main.dart.js` | > 5% | ревью deferred-структуры |
| JS hard-cap | любое превышение | **блок CI** до возврата в бюджет |

---

## 6. Оптимизации (реализованные в архитектуре)

- **Три уровня интерактивности** — движок только когда нужен (§4.3).
- **Отдельный island entry-point** (`--target=lib/island_main.dart`) — без бизнес-логики (W-7).
- **Per-island deferred imports** — код острова по триггеру (§7.3).
- **Диспетчер** грузит движок при первом триггере (W-9).
- **Service Worker + WASM streaming + preload** — тёплый визит ~1с (W-11).
- **Single-pass сериализатор** — без квадратичности, O(узлы + текст) (`SER3`).
- **Virtual views** — экономия GPU на высоких островах (W-13).

---

*Изменение бюджетов — только через версионирование этого файла + синхронизацию
с `HYDRALINE_SPEC_V3.md` NF-3/NF-4/NF-4a.*
