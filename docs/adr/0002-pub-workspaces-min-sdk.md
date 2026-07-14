# ADR-0002: pub workspaces + melos 8 raise the minimum SDK (Dart 3.9 / Flutter 3.35)

- **Статус:** Accepted
- **Дата:** 2026-07-14
- **Контекст фазы:** Phase 0 / Phase 1 (cross-cutting)
- **Связано:** `HYDRALINE_SPEC_V3.md` NF-5/Q7, `DEVELOPMENT.md §1`,
  `PHASE_0_PLAN.md` P0-08, ADR-0001, инвариант I1

## Контекст

ADR-0001 зафиксировал переход на melos 8 + Dart **pub workspaces**
(`workspace:` в корневом `pubspec.yaml`, `resolution: workspace` в пакетах).
Прогоны CI выявили жёсткую цепочку ограничений инструментария:

- **pub workspaces** требуют **Dart ≥ 3.7** (`workspace`/`resolution requires
  language version 3.7`). Flutter 3.22 (заявленный минимум спеки, NF-5/Q7)
  несёт Dart 3.4 и падает на `dart pub get` ещё до анализа.
- **melos ^8** (8.2.2) требует **Dart ≥ 3.9** (`melos requires SDK >=3.9.0`).
  Значит Flutter 3.29 (Dart 3.7) и 3.32 (Dart 3.8) тоже непригодны для
  workspace c melos.
- Первый Flutter SDK с Dart 3.9 — **Flutter 3.35**, он и становится минимумом.

Итог: требования спеки «melos ≥ 7» (→ pub workspaces + Dart ≥ 3.9) и «min
Flutter 3.22» **взаимно несовместимы**.

## Рассмотренные варианты

1. **Поднять минимум до Dart 3.9 / Flutter 3.35**, сохранив pub workspaces.
2. **Отказаться от pub workspaces** (убрать `workspace:`/`resolution:`),
   вернувшись к melos-bootstrap + `pubspec_overrides.yaml`, чтобы сохранить
   Flutter 3.22. Противоречит направлению melos ≥ 7 и `DEVELOPMENT.md §2`.

## Решение

Принят вариант 1 (подтверждено владельцем продукта):

- Минимальные SDK: **Dart ≥ 3.9.0**, **Flutter ≥ 3.35.0**.
- `environment.sdk: ^3.9.0` во всех пакетах и в корне; `environment.flutter:
  ">=3.35.0"` в `hydraline_flutter`.
- CI-матрица `flutter`: `3.35.0` (min) + `3.44.6` (latest), плюс `3.41.x`
  informational (R1).
- **Обновляет NF-5/Q7:** заявленный минимум Flutter меняется с 3.22 на 3.35.

Дополнительно (следствие тех же прогонов CI): melos-скрипты вызывают вложенный
`melos exec` через `dart run melos:melos exec`, а CI — `dart run melos:melos run
<script>`. Это убирает зависимость от наличия `melos` в `PATH` раннера и
работает одинаково на Windows и Linux.

## Последствия

- **Плюсы:** совместимость с pub workspaces и melos 8; единый `dart pub get`;
  переносимый вызов melos без PATH; зелёный CI.
- **Минусы / компромиссы:** пользователи Flutter 3.22–3.34 не поддерживаются
  (изменение продуктового требования NF-5). `HYDRALINE_SPEC_V3.md` и
  `DEVELOPMENT.md` следует привести в соответствие (задача update-docs).
- **Влияние на инварианты:** I1/I9/I10 без изменений; матрица §9.1 обновлена.

## Проверка

- `dart pub get` резолвит workspace на Dart 3.9+.
- CI-джоб `flutter 3.35.0` зелёный; вызовы `dart run melos:melos run …`
  проходят на Windows и Linux.
