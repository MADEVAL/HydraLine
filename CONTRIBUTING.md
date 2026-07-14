# Contributing to Hydraline

Thanks for your interest in contributing!

## Setup

```bash
dart pub global activate melos
git clone https://github.com/MADEVAL/HydraLine.git
cd HydraLine
dart pub get
```

## Development workflow

1. Create a feature branch: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`
2. Write tests first (TDD — test-driven development)
3. Implement the change
4. Run the full suite: `melos run test`
5. Verify analysis: `melos run analyze`
6. Ensure formatting: `melos run format`
7. Run everything at once with `melos run precommit`
8. Open a pull request using the
   [PR template](.github/PULL_REQUEST_TEMPLATE/pull_request_template.md)

Bug reports and feature requests have templates too:
[bug report](.github/ISSUE_TEMPLATE/bug_report.md) ·
[feature request](.github/ISSUE_TEMPLATE/feature_request.md).

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
- Keep builders deterministic — no `DateTime.now()` / random values at render time

## Security issues

Never report vulnerabilities in public issues — see the
[Security Policy](SECURITY.md).

## Questions?

Open an issue or discussion on GitHub. Community expectations are described
in the [Code of Conduct](CODE_OF_CONDUCT.md).
