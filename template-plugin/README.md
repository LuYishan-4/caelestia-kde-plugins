# Template Plugin

A starting point for new Caelestia plugins. This folder is not part of the store - it lives at the repository root so it is never validated or ingested.

## How to use it

1. Copy this folder into the store: `plugins/<your-plugin-id>/`.
2. Rename it to your plugin id (lowercase letters, digits and single hyphens).
3. Edit `metadata.json`:
   - `id` must equal the folder name.
   - Fill in `name`, `description`, `version`, `author`, `license`.
   - Change `type` to `quickshell`, `kwineffect`, or `theme` as appropriate.
   - `mediaurl` is optional and may be a web URL, an absolute local path, or a plugin-relative path.
   - `icon` is optional; use `default`, a Material Symbols ligature name like `wallpaper`, or a local image path such as `icon.png`.
   - `shell-compat.min` should be the oldest Caelestia shell version your plugin supports.
4. Replace `LICENSE` with the license for your plugin.
5. Replace `main.qml` with your actual plugin content.
6. Add an image file if you want a local icon/media asset and reference it in `metadata.json`.
7. Test: `pip install jsonschema && python scripts/validate.py`
8. Open a pull request. See [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## Type-specific requirements (enforced by CI)

- `quickshell` - at least one `.qml` file.
- `kwineffect` - a KPackage layout with `metadata.desktop`, plus `kwineffect.kpluginId`.
- `theme` - theme source files.

## Required files (every plugin)

- `metadata.json` - the manifest.
- `LICENSE` - your plugin's license.
