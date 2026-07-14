# ADR-0002: pub workspaces raise the minimum SDK (Dart 3.8 / Flutter 3.32)

- **Статус:** Accepted
- **Дата:** 2026-07-14
- **Контекст фазы:** Phase 0 / Phase 1 (cross-cutting)
- **Связано:** `HYDRALINE_SPEC_V3.md` NF-5/Q7, `DEVELOPMENT.md §1`,
  `PHASE_0_PLAN.md` P0-08, ADR-0001, инвариант I1

## Контекст

ADR-0001 зафиксировал переход на melos 8 + Dart **pub workspaces**
(`workspace:` в корневом `pubspec.yaml`, `resolution: workspace` в пакетах).
Первый зелёный прогон CI выявил жёсткое ограничение инструментария:

```
Error: `workspace` and `resolution` requires at least language version 3.7
```

Pub workspaces требуют **Dart ≥ 3.7**, а сама **melos ^8** — **Dart ≥ 3.8**.
Flutter 3.22 (заявленный в спеке как минимум, NF-5/Q7) поставляется с Dart 3.4
и физически не может участвовать в pub-workspace — `dart pub get` падает ещё до
анализа. Flutter 3.29 несёт Dart 3.7 (workspace резолвится, но melos не
устанавливается: `melos requires SDK >=3.8.0`). Первый Flutter SDK с Dart 3.8 —
**Flutter 3.32**, он и становится минимумом.

Таким образом требования спеки «melos ≥ 7» (→ pub workspaces + Dart ≥ 3.8) и
«min Flutter 3.22» **взаимно несовместимы**.

## Рассмотренные варианты

1. **Поднять минимум до Dart 3.8 / Flutter 3.32**, сохранив pub workspaces.
2. **Отказаться от pub workspaces** (убрать `workspace:`/`resolution:`),
   вернувшись к melos-bootstrap + `pubspec_overrides.yaml`, чтобы сохранить
   Flutter 3.22. Противоречит направлению melos ≥ 7 (pub workspaces — основной
   путь) и `DEVELOPMENT.md §2`, где `pubspec.yaml` описан как pub workspace.

## Решение

Принят вариант 1 (подтверждено владельцем продукта):

- Минимальные SDK: **Dart ≥ 3.8.0**, **Flutter ≥ 3.32.0**.
- `environment.sdk: ^3.8.0` во всех пакетах и в корне; `environment.flutter:
  ">=3.32.0"` в `hydraline_flutter`.
- CI-матрица `flutter`: `3.32.0` (min) + `3.44.6` (latest), плюс `3.41.x`
  informational (R1). Джоб `3.22` удалён.
- **Обновляет NF-5/Q7:** заявленный минимум Flutter меняется с 3.22 на 3.29.

Дополнительно (следствие того же прогона CI): melos-скрипты вызывают вложенный
`melos exec` через `dart run melos:melos exec`, а CI — `dart run melos:melos run
<script>`. Это убирает зависимость от наличия `melos` в `PATH` раннера и
работает одинаково на Windows и Linux.

## Последствия

- **Плюсы:** совместимость с pub workspaces и melos 8; единый `dart pub get`;
  переносимый вызов melos без PATH; зелёный CI.
- **Минусы / компромиссы:** пользователи Flutter 3.22–3.28 не поддерживаются
  (изменение продуктового требования NF-5). `HYDRALINE_SPEC_V3.md` и
  `DEVELOPMENT.md` следует привести в соответствие (задача update-docs).
- **Влияние на инварианты:** I1/I9/I10 без изменений; матрица §9.1 обновлена.

## Проверка

- `dart pub get` резолвит workspace на Dart 3.8+.
- CI-джоб `Flutter 3.32.0` зелёный; вызовы `dart run melos:melos run …`
  проходят на Windows и Linux.
