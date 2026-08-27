<!-- Thanks for contributing to the Caelestia plugin store! -->
<!-- Delete the sections that don't apply and fill in the rest. -->

## What does this PR do?

<!-- e.g. Add a new plugin / update a plugin / deprecate a plugin / remove a plugin -->

## Plugin

- id (folder name):
- name:
- version:
- type: `quickshell` | `kwineffect` | `theme`
- license (SPDX):

## Checklist

- [ ] The plugin lives in its own folder under `plugins/<id>/` and the folder name equals the `id` in `metadata.json`
- [ ] `metadata.json` is valid JSON and passes `python scripts/validate.py`
- [ ] A `LICENSE` file is included in the plugin folder
- [ ] No compiled binaries or archives are included (source-only policy)
- [ ] `version` follows semver and was bumped for updates
- [ ] For deprecations: `deprecated: true` and a valid `replacement` are set
- [ ] I have reviewed my plugin's code for safety and malicious behavior
