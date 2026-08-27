# Contributing to the Caelestia Plugin Store

Thanks for contributing! This store is the official community appstore for the Caelestia desktop shell. Every plugin is a folder under `plugins/`, contributed through a pull request and merged by a maintainer after review.

## Store rules

- Source only. No compiled binaries or archives. CI rejects them.
- One folder, one plugin. The folder name is the plugin's unique id: lowercase letters, digits and single hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`), e.g. `my-cool-widget`.
- Ids are immutable. Once published, an id cannot be renamed. To rename, add a new plugin and deprecate the old one.
- Human review required. All changes to `plugins/` need a maintainer's review before merge.

## Adding a new plugin

1. Fork this repository and clone your fork.
2. Copy `template-plugin/` to `plugins/<id>/`.
3. Fill in `metadata.json`. Required fields: `id`, `name`, `description`, `version`, `type`, `author`, `license`. See [`schemas/plugin.schema.json`](schemas/plugin.schema.json).
4. Add a `LICENSE` file for your plugin (see [Licensing](#licensing)).
5. Add your plugin content. Type-specific requirements:
   - `quickshell` - at least one `.qml` file.
   - `kwineffect` - a KPackage layout with `metadata.desktop`, plus `kwineffect.kpluginId` in the manifest.
   - `theme` - theme source files.
6. Test locally (requires Python and `jsonschema`):
   ```
   pip install jsonschema
   python scripts/validate.py
   ```
7. Open a pull request. CI runs `validate.py`; a maintainer reviews and merges.

## Updating a plugin

Edit the plugin folder in place and bump `version` using [semver](https://semver.org/) (`MAJOR.MINOR.PATCH`, optionally with `-prerelease` and/or `+build`). Open a pull request.

## Deprecating a plugin

Set `"deprecated": true` and `"replacement": "<new-id>"` in `metadata.json`, then open a pull request. Deprecated plugins stay in the store so existing installs keep working, but consumers should not recommend them for new installs.

## Removing a plugin

Open a pull request that deletes the plugin folder. Removal is irreversible and requires a maintainer's approval - prefer deprecation unless the plugin is broken or unsafe.

## Choosing a type

- `quickshell` - QML widgets loaded by the shell.
- `kwineffect` - KDE KWin effects (standard KPackage layout).
- `theme` - colors / QML styling packs.

To request a new type, open an issue; the maintainers extend the schema and the validator.

## Naming rules

- The `id` (folder name) must match `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Reserved names cannot be used (see `scripts/validate.py`): `.git`, `.github`, `docs`, `schemas`, `scripts`, `plugins`, `template-plugin`, `index.json`, etc.
- Full URLs (with a scheme, e.g. `https://…`) are required for `homepage` and `repository`.

## Licensing

- The store's own infrastructure (docs, scripts, schemas, workflows) is GPL-3.0.
- Each plugin must declare its license with an [SPDX id](https://spdx.org/licenses/) in `metadata.json` and include a `LICENSE` file. Any OSI- or FSF-approved license is accepted. When in doubt, use `GPL-3.0-or-later`.

## Validation and CI

- `.github/workflows/validate.yml` runs `scripts/validate.py` on every pull request and push to `main`.
- `.github/workflows/build-index.yml` regenerates `index.json` after every merge to `main`, so you never need to edit it by hand.

## Maintainer review checklist

- CI passes.
- The plugin is source-only - no binaries or archives.
- `id` is unique and not reserved; the folder name equals the manifest `id`.
- A `LICENSE` file is present and the license is acceptable.
- The plugin is not malicious: no surprise downloads, data exfiltration, hidden network calls, or unexpected shelling out.
- For updates: the version was bumped with semver.
- For deprecations: `replacement` points at a real plugin.
