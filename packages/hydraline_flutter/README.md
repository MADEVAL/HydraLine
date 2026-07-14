# hydraline_flutter

Flutter package for [Hydraline](../../README.md): `Seo.*` widgets, `Island`,
`HydraApp`, `IslandHost`, the SSG runner and the level-2 web runtime assets
(Custom Element, dispatcher, Service Worker).

## Flutter version policy (NF-5, Q7)

- **Minimum supported: Flutter 3.35.0** (`environment.flutter: ">=3.35.0"`),
  the first SDK bundling Dart 3.9 — required by pub workspaces (see
  `docs/adr/0002-pub-workspaces-min-sdk.md`). This supersedes the original
  3.22 target from the spec.
- CI runs the minimum and the latest stable SDK as blocking jobs.

> ⚠️ **Flutter 3.41.x known issue (#185034, R1).** A multi-view sizing
> regression can make a canvas mismatch its host on 3.41.x. Hydraline pins
> explicit `viewConstraints` and degrades the `ResizeObserver` corrector to a
> no-op on 3.41.x. This SDK line is covered by an **informational (non-blocking)**
> CI job only; prefer 3.22+ or the latest stable.

> Status: pre-MVP skeleton (Phase 0). Widgets/islands land in Phase 3–4 — see
> `specs/PHASE_3_PLAN.md`.
