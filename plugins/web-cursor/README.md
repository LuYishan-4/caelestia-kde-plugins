# Ultralight Web Cursor

A KWin effect that replaces the system cursor with an animated HTML/CSS/JS cursor, rendered by [Ultralight](https://ultralig.ht/). The cursor is a real HTML page, so themes are plain folders with an `index.html` (see `contents/WebCursor/`).

This folder is packaged as a Caelestia plugin store `kwineffect` plugin in standard KPackage layout: `metadata.desktop` at the root and the effect source under `contents/`.

## Dependencies

Build dependencies (Arch package names in parentheses):

- KDE Frameworks 6 / KWin development headers (`kwin6-devel`)
- Qt 6 (`qt6-base`), Extra CMake Modules (`extra-cmake-modules`)
- `epoxy`
- The **Ultralight SDK** (https://ultralig.ht/). The SDK is *not* bundled on purpose: this store is source-only and the `.so` binaries are too large to ship. `CMakeLists.txt` looks for an extracted SDK at `ULTRALIGHT_ROOT` (default `./ThirdParty`, expected layout `ThirdParty/bin/*.so`, `ThirdParty/include`, `ThirdParty/resources`). If none is found there it **detects the missing SDK and downloads it automatically** from the ThirdParty GitHub mirror (<https://github.com/LuYishan-4/ThirdParty>, branch `main` by default, cached into the build directory), so a plain `cmake -B build -S .` just works.

  Automatic download can be tuned or disabled with these cache variables:

  ```sh
  cmake -B build -S . \
    -DULTRALIGHT_REPO=LuYishan-4/ThirdParty \
    -DULTRALIGHT_REF=main \
    -DULTRALIGHT_DOWNLOAD_URL="https://..." \
    -DULTRALIGHT_DOWNLOAD=OFF -DULTRALIGHT_ROOT=/path/to/ultralight-sdk
  ```

  Anything you keep inside this folder (e.g. a copy of the SDK at `ThirdParty/`, like the one at <https://github.com/LuYishan-4/ThirdParty>) is git-ignored and must never be committed.

## Build & install

```sh
cmake -B build -S .          # fetches the Ultralight SDK automatically if needed
cmake --build build
sudo cmake --install build
```

This installs:

- the effect plugin `ultralightwebcursor` into KWin's effect plugin dir,
- the Ultralight runtime libraries into `/usr/lib/webkde_core`,
- the built-in cursor themes and Ultralight resources into `/usr/share/caelestia/webcursor`.

## Enable

```sh
kwriteconfig6 --file kwinrc --group Plugins --key ultralightwebcursorEnabled true
qdbus org.kde.KWin /Effects org.kde.kwin.Effects.reconfigure
```

or at runtime through D-Bus:

```sh
busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects loadEffect s ultralightwebcursor
busctl --user call org.kde.KWin /UltralightCursor org.kde.kwin.KWin.KwinCursorEffect enable
```

## Configuration

The effect reads `webCursor.cursor` from `~/.config/caelestia/shell.json`
(`enabled`, `width`, `height`, `selectTheme`, `themesDir`, `blacklist`). Settings
can be applied live over D-Bus:

```sh
busctl --user call org.kde.KWin /UltralightCursor org.kde.kwin.KWin.KwinCursorEffect reloadHtml
```

To change the active theme, update `webCursor.cursor.selectTheme` in
`~/.config/caelestia/shell.json` and trigger `reloadHtml`.

## Settings UI (`quickshell` side)

The plugin also ships a Quickshell settings UI that mirrors the Nexus page from
[`caelestia-dots-kde`](https://github.com/LuYishan-4/caelestia-dots-kde)
(`shell/modules/nexus/pages/desktop/WebCursorPage.qml`) plus its service and
config layer:

| Source (caelestia-dots-kde) | Port in this folder |
| --- | --- |
| `shell/plugin/src/Caelestia/Config/webcursorconfig.hpp` | `qml/Config.qml` (`WebCursorConfig`, persists to the shared `shell.json`) |
| `shell/services/WebCursor.qml` | `qml/WebCursorManager.qml` |
| `shell/modules/nexus/pages/desktop/WebCursorPage.qml` | `qml/settings/WebCursorSettingsPanel.qml` |

QML layout follows the `wallpaper-selector` plugin: `main.qml` is the entry
`Scope`, `qml/` is the module (with `qmldir`), and the shell-agnostic controls
live in `qml/components/`. The UI writes the same `webCursor.cursor` keys the
effect reads, manages theme upload/remove, and talks to the running KWin effect
over D-Bus (`busctl`), exactly like the original Nexus page.

- The settings overlay is toggled with the `webcursor_settings` shortcut
  (default `Meta+Shift+C`); override it with the `webCursor.shortcut` key in
  `shell.json`.
- On first load `main.qml` checks whether the `contents/` CMake project has
  been built (`<plugin dir>/build`) and runs `cmake -S . -B build` +
  `cmake --build build` automatically when it has not. Disable with
  `webCursor.build.auto: false` in `shell.json`. Building only produces the
  artifacts; installing the effect into KWin still requires
  `sudo cmake --install build`.
- The folder manifest is still `type: kwineffect`; the QML half is meant to be
  loaded as a `quickshell` root once the store supports shipping both halves.

## Store layout

- `metadata.json` - Caelestia plugin store manifest (`type: kwineffect`).
- `metadata.desktop` - KWin effect metadata.
- `CMakeLists.txt` - the effect's own build script (source-only; no build artifacts are committed).
- `contents/` - effect source (KPackage `contents/` layout) and bundled cursor themes.
- `main.qml` + `qml/` - Quickshell settings UI (see above).

Validate locally with:

```sh
python scripts/validate.py
```
