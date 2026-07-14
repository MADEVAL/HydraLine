---
name: update-docs
description: "Documentation update agent. Use after code changes — new API surface, new DocumentNode, serializer/escaping changes, server/route behavior, new melos scripts, or invariant changes. Keeps specs/ and package docs consistent with code."
---
# Update Docs After Code Changes

## Overview

Code without matching docs is a lie waiting to bite the next developer. Every code change must be reflected in docs.

**Core principle:** `git diff` tells you what changed. The doc map tells you where to write.

**Violating the letter of this process is violating the spirit of documentation.**

## The Iron Law

```
NO CODE CHANGE WITHOUT DOC UPDATE
```

If you committed code without updating docs, update them now.

## When to Use

Use after ANY change under `packages/*/lib/**` that touches public API, behavior,
invariants, or configuration. Internal-only refactors that don't change public API,
contracts, invariants, or CLI/scripts may skip — but when in doubt, update.

## The Doc Map

Hydraline docs live in `specs/` (product + engineering L1–L4), in each package
(`packages/*/api/`, `example/`, dartdoc), and at repo root (`AGENTS.md`, `CHANGELOG`).
Here is what each doc covers and what triggers an update.

### Source of Truth Docs (highest priority)

| Doc | Covers | Update When |
|-----|--------|-------------|
| `specs/HYDRALINE_SPEC_V3.md` | Продуктовое ТЗ v3.x: цели, не-цели, режимы маршрутов, инварианты продукта | Изменение продуктового поведения, режимов (`app`/`document`/`hybrid`), не-целей. |
| `specs/ARCHITECTURE.md` | L1: компоненты, контракты, потоки данных, **инварианты §15** (`I1..I10`, `SER*`, `SRV*`, `N*`, `S*`) | Новый/изменённый компонент, контракт, поток данных или инвариант. |
| `specs/DEVELOPMENT.md` | L2: среда, топология, melos-скрипты §5, стратегия тестов §6, CI-гейты §9, DoD §11 | Новый melos-скрипт, изменение CI-гейтов, порогов покрытия, топологии пакетов. |
| `specs/packages/<pkg>/api/*.dart` | L4: замороженные API-контракты (сигнатуры до реализации) | Любое изменение публичной сигнатуры пакета — контракт обновляется синхронно с `lib/`. |
| `specs/packages/hydraline_flutter/api/JS_RUNTIME_CONTRACT.md` | Контракт JS-рантайма островов | Изменение JS-контракта гидрации/островов. |
| `specs/hydraline.routes.schema.json` | JSON-схема конфигурации маршрутов | Новое/изменённое поле конфигурации маршрутов. |

### Traceability & Quality Docs

| Doc | Covers | Update When |
|-----|--------|-------------|
| `specs/REQUIREMENTS_TRACEABILITY.md` | Покрытие всех требований (цель 100%) | Новое требование, новая реализация закрывающая требование, новый тест-доказательство. |
| `specs/ACCEPTANCE_TESTS.md` | Сценарии приёмки A1–A10 | Новый/изменённый приёмочный сценарий или его критерий. |
| `specs/SECURITY.md` | Модель угроз, escaping/`SafeUrl`, XSS-политика | Изменение поверхности безопасности, экранирования, векторов. |
| `specs/PERFORMANCE.md` | Бюджеты производительности и их измерение | Изменение бюджета (FCP/TTI/размер бандла) или способа измерения. |
| `specs/EXAMPLES.md` | 4 эталонных примера (=E2E-фикстуры) | Изменение/добавление эталонного примера. |
| `specs/PHASE_*_PLAN.md` | L3: задачи фаз с приёмкой | Завершение/переопределение задачи фазы. |

### Per-Package Docs

| Location | Covers | Update When |
|----------|--------|-------------|
| dartdoc (`///`) в `lib/**` | Публичный API каждого пакета | Новый/изменённый публичный класс, метод, поле, typedef. |
| `packages/<pkg>/example/` | Рабочий пример использования пакета (NF-11, pub.dev) | Изменение публичного API, влияющее на использование. |
| `packages/<pkg>/CHANGELOG.md` | История версий пакета (SemVer, Conventional Commits) | Любое поведенческое изменение — новая запись CHANGELOG. |

### Process / Meta

| Doc | Purpose | Update When |
|-----|---------|-------------|
| `AGENTS.md` (root) | Команды, границы, правила для агентов | Новый melos-скрипт, изменение границ (I1) или правил разработки. |
| `specs/docs/adr/` | Architecture Decision Records | Нетривиальное решение → новый ADR по `TEMPLATE.md` (изменение старого = новый ADR «Supersedes ADR-XXXX»). |

## The Update Process

### Step 1: Identify What Changed

```powershell
git diff <start-commit>..<end-commit> --stat
git diff <start-commit>..<end-commit> -- packages/
```

Categorize each file change:
- **New public API** → update L4 contract (`specs/packages/*/api/`), dartdoc, `example/`, CHANGELOG
- **Behavior/invariant change** → update `ARCHITECTURE.md` (+§15 invariants), traceability, relevant quality doc
- **New melos script / CI gate** → update `DEVELOPMENT.md §5/§9` and `AGENTS.md`
- **Deleted API** → remove from L4 contract and dartdoc references

### Step 2: Cross-Reference Against the Doc Map

For each category of change, consult the doc map above. One code change often requires updates to multiple docs.

**Example: adding a new `DocumentNode` (e.g. `HeadingNode`) to core:**
- `specs/packages/hydraline/api/document_node.dart` — add the frozen L4 signature
- dartdoc in `packages/hydraline/lib/**` — document the public class
- `specs/ARCHITECTURE.md` — if it introduces/affects a serializer contract or invariant (`SER*`, `I4`)
- `specs/REQUIREMENTS_TRACEABILITY.md` — link the requirement it satisfies + its test
- `packages/hydraline/example/` + `packages/hydraline/CHANGELOG.md`

**Example: adding a new server route mode / delivery behavior:**
- `specs/HYDRALINE_SPEC_V3.md` — route-mode semantics
- `specs/ARCHITECTURE.md` — server contract + invariant (`SRV*`, `I3`)
- `specs/ACCEPTANCE_TESTS.md` — affected A-scenario (e.g. A8 no-cloaking)
- `specs/packages/hydraline_server/api/server.dart` — L4 signature
- CHANGELOG + `example/`

### Step 3: Consistency Checks

Facts that appear in MULTIPLE docs must stay in sync. Common ones to verify:
- **Invariant IDs** (`I1..I10`, `SER*`, `SRV*`, `N*`, `S*`) — `ARCHITECTURE.md §15` is canonical; references elsewhere must match.
- **Coverage thresholds** (core/server ≥ 90%, flutter ≥ 80%) — `AGENTS.md`, `DEVELOPMENT.md §6.4`, `CONTRIBUTING.md`.
- **SDK/Flutter versions** (Dart ≥ 3.6, Flutter ≥ 3.22) — `AGENTS.md`, `DEVELOPMENT.md §1`, `README.md`, package `pubspec.yaml`.
- **melos script names** — `AGENTS.md`, `DEVELOPMENT.md §5`, `melos.yaml` (source).
- **Public API signatures** — `specs/packages/*/api/*.dart` (L4) must match `packages/*/lib/**`.

### Step 4: Verify Consistency

After all edits, run a quick sanity check:

```powershell
git diff --stat HEAD -- specs/ AGENTS.md packages/
```

Read through the diffs. Ask:
- Do all cross-references still point to valid sections/files?
- Are invariant IDs, thresholds, and versions consistent across files?
- Does the L4 contract (`api/`) match the real signature in `lib/`?
- Are dates and version strings current?

## HARD-GATE Rules

1. **Spec wins.** `specs/HYDRALINE_SPEC_V3.md` (product) and `specs/ARCHITECTURE.md` (invariants) are the source of truth. If another doc contradicts them, the other doc is wrong — fix it.
2. **L4 contract mirrors `lib/`.** Any public signature change in `packages/*/lib/**` MUST be mirrored in `specs/packages/*/api/*.dart`. They must never drift.
3. **Never invent docs.** Only document what exists in source. Run `git diff`, not `grep` on speculation. Documentation reflects reality.
4. **Invariants are precise.** Don't paraphrase an invariant; reference its ID (`I1`, `SER2`, …) and keep the definition identical to `ARCHITECTURE.md §15`.
5. **Cross-references are live.** If you rename a section or file, update every reference to it (markdown links and "§N"-style references).
6. **CHANGELOG per package.** Every behavioral change gets a CHANGELOG entry in the affected package (SemVer + Conventional Commits).

## Common Anti-Patterns

| Anti-Pattern | Reality |
|---|---|
| "The code is self-documenting" | dartdoc the public API. Write the doc. |
| "I'll update docs later" | Later never comes. Do it now. |
| "The L4 contract is just a sketch" | It's frozen. If the signature changed, the contract changed. |
| "Invariant wording doesn't matter" | Drifting invariant text breaks CI reasoning and reviews. Copy it exactly. |
| "One example is enough for all packages" | Each package ships its own `example/` (pub.dev / NF-11). |
| "Skip the CHANGELOG, it's minor" | Behavior changed → users need the entry. |

## Quick-Reference: Per-Change-Type Checklist

### New/changed public API (any package)
- [ ] `specs/packages/<pkg>/api/*.dart`: update frozen L4 signature
- [ ] dartdoc in `packages/<pkg>/lib/**`
- [ ] `packages/<pkg>/example/`: reflect new usage
- [ ] `packages/<pkg>/CHANGELOG.md`: add entry
- [ ] `specs/REQUIREMENTS_TRACEABILITY.md`: link requirement + test

### New/changed invariant or contract
- [ ] `specs/ARCHITECTURE.md §15`: define/update invariant (canonical)
- [ ] Update every doc that references the invariant ID
- [ ] `specs/REQUIREMENTS_TRACEABILITY.md`: covering test
- [ ] Relevant quality doc (`SECURITY.md` / `PERFORMANCE.md` / `ACCEPTANCE_TESTS.md`)

### New melos script or CI gate
- [ ] `specs/DEVELOPMENT.md §5` (scripts) / §9 (gates)
- [ ] `AGENTS.md`: command table
- [ ] `melos.yaml`: source definition

### New route/config field
- [ ] `specs/hydraline.routes.schema.json`
- [ ] `specs/HYDRALINE_SPEC_V3.md`: semantics
- [ ] `specs/packages/hydraline_server/api/server.dart` if API-visible

### Nontrivial architectural decision
- [ ] New ADR in `specs/docs/adr/` via `TEMPLATE.md`
- [ ] Link from `ARCHITECTURE.md` if it changes L1
