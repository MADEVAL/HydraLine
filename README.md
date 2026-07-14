```
   __  __          __           __    _          
  / / / /_  ______/ /________ _/ /   (_)___  ___ 
 / /_/ / / / / __  / ___/ __ `/ /   / / __ \/ _ \
/ __  / /_/ / /_/ / /  / /_/ / /___/ / / / /  __/
/_/ /_/\__, /\__,_/_/   \__,_/_____/_/_/ /_/\___/ 
      /____/                                      
```

# Hydraline

SEO / SSR / prerender + islands for Flutter Web.

Hydraline turns Flutter Web's canvas into real, crawlable HTML — without
sacrificing interactivity. Static HTML loads instantly; interactive islands
hydrate on demand.

## Packages

| Package | Purpose |
|---|---|
| [`hydraline`](packages/hydraline/) | Core — DocumentNode model, HTML serializer, SEO metadata, escaping |
| [`hydraline_server`](packages/hydraline_server/) | Server — SSR streaming, HTMX helpers, bot-aware shelf/Dart Frog delivery |
| [`hydraline_flutter`](packages/hydraline_flutter/) | Flutter — Seo.* widgets, Island, HydraApp, SSG runner |

## Quick start

```yaml
dependencies:
  hydraline: ^0.0.1
  hydraline_server: ^0.0.1
  hydraline_flutter: ^0.0.1
```

```bash
dart pub get
melos bootstrap
melos run test
```

## Documentation

Full docs at [`docs/`](docs/).

## Community

- [Contributing](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

## License

MIT — [Yevhen Leonidov](https://leonidov.dev) / [Globus Studio](https://globus.studio)
