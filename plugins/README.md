# Plugins

Each directory in this folder is one plugin for the Caelestia desktop shell.

- The directory name is the plugin's unique, immutable id (lowercase kebab-case).
- Every plugin needs at least `metadata.json` and `LICENSE`.
- Plugins are contributed via pull request - see [`CONTRIBUTING.md`](../CONTRIBUTING.md) and the [`template-plugin/`](../template-plugin/) scaffold.
- This folder is the source of truth; `index.json` at the repository root is regenerated from it by CI.
