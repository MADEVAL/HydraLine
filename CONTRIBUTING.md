# Contributing to Hydraline

Thanks for your interest in contributing!

## Setup

```bash
dart pub global activate melos
git clone https://github.com/MADEVAL/HydraLine.git
cd hydraline
melos bootstrap
```

## Development workflow

1. Create a feature branch: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`
2. Write tests first (TDD — test-driven development)
3. Implement the change
4. Run the full suite: `melos run test`
5. Verify analysis: `melos run analyze`
6. Ensure formatting: `melos run format`
7. Open a pull request

## Commit conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(scope): summary
fix(scope): summary
docs(scope): summary
test(scope): summary
refactor(scope): summary
```

Scopes: `core`, `server`, `flutter`, `web`, `ci`, `docs`

## Pull requests

- Fill in the PR template (all sections)
- All checks must pass (analysis, formatting, tests)
- Keep changes focused — one concern per PR

## Code style

- Pure Dart in `hydraline` and `hydraline_server` — no `package:flutter`, no `dart:ui`, no `dart:html`
- Flutter code lives only in `hydraline_flutter`
- Document public API with dartdoc
- Use English for all code, comments, and documentation

## Questions?

Open an issue or discussion on GitHub.
