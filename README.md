# Caelestia Community Plugin Store

> The official community appstore for [Caelestia](https://github.com/ladybug-me/caelestia-dots-kde) - the KDE Plasma 6 desktop shell.

This repository is a machine-readable store of plugins for the Caelestia desktop shell. Each folder under [`plugins/`](plugins/) is one plugin. Plugins are contributed by the community via pull requests; every change is validated by CI and reviewed by a maintainer before it is merged.

> ⚠️ Security note - Plugins are third-party code that runs on your machine with the privileges of the desktop shell. This store is source-only: compiled binaries and archives are rejected by CI, and every change is human-reviewed. Still, only install plugins you trust. See [SECURITY.md](SECURITY.md).

## Repository layout

| Path | Purpose |
| --- | --- |
| `plugins/<id>/` | One directory per plugin. The directory name is the plugin's unique, immutable id. |
| `plugins/<id>/metadata.json` | Required plugin manifest. |
| `plugins/<id>/LICENSE` | Required license file for the plugin. |
| `schemas/plugin.schema.json` | JSON Schema for `metadata.json`. |
| `scripts/validate.py` | Validates the whole store (run in CI and locally). |
| `scripts/build_index.py` | Regenerates `index.json`. |
| `index.json` | Generated registry consumed by the shell / other programs. |
| `docs/ingestion-contract.md` | Spec for programs that ingest this store. |
| `template-plugin/` | Copy-me scaffold for new plugins (not part of the store). |

## Adding a plugin

See [CONTRIBUTING.md](CONTRIBUTING.md). In short:

1. Fork this repository.
2. Copy `template-plugin/` to `plugins/<your-plugin-id>/` and fill it in.
3. Open a pull request. CI validates the structure; a maintainer reviews and merges.

## Consumers

Programs that want to read this store should follow [`docs/ingestion-contract.md`](docs/ingestion-contract.md) - either clone the repository and read each `metadata.json`, or fetch the generated `index.json` with a single request.

## Maintainers

- [@ladybug-me](https://github.com/ladybug-me)

## License

The repository's infrastructure (docs, scripts, schemas, workflows) is licensed under the GPL-3.0 - see [`LICENSE`](LICENSE). Each plugin folder is licensed independently under the license declared in its own `LICENSE` file and `metadata.json`.
