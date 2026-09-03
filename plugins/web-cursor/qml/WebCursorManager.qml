// QML port of `caelestia-dots-kde/shell/services/WebCursor.qml`.
//
// Adaptations for the plugin environment:
//   * the shell's `GlobalConfig.webCursor.cursor` became the `config`
//     property (a `WebCursorConfig` instance, see Config.qml) injected by the
//     plugin entry point,
//   * user/system theme detection is folded into a single listing pass
//     (instead of one `readlink` subprocess per theme).
//
// Everything else mirrors the original: system themes are symlinked into the
// user themes dir, uploads copy folders, and the KWin effect is controlled
// through its D-Bus interface (busctl), never through `kwinrc` reconfigure.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Instance of WebCursorConfig (Config.qml); assigned by main.qml.
    property var config: null

    signal themeUploadFinished(bool success, string error)
    signal themeRemoveFinished(bool success, string error)

    property var themeList: []
    property var _themeKinds: ({})
    property string statusMessage: ""

    readonly property string systemThemesDir: "/usr/share/caelestia/webcursor"

    function userThemesDir() {
        return root.config ? root.config.themesDir : ""
    }

    // ---- built-in themes -> user dir linking ------------------------------
    function ensureInitialized() {
        linkProc.command = ["sh", "-c",
            'user="$1"; sys="$2"; ' +
            'mkdir -p "$user" || exit 1; ' +
            'for f in "$user"/*; do ' +
            '  [ -e "$f" ] && continue; ' +
            '  [ -L "$f" ] && rm -f -- "$f"; ' +
            'done; ' +

            '[ -d "$sys" ] || exit 0; ' +
            'for d in "$sys"/*/; do ' +
            '  [ -d "$d" ] || continue; ' +
            '  n=$(basename "$d"); ' +
            '  [ -f "$d/CursorData.json" ] && [ -f "$d/index.html" ] || continue; ' +
            '  target="$user/$n"; ' +
            '  [ -e "$target" ] || [ -L "$target" ] || ln -s -- "$d" "$target"; ' +
            'done',
            "--", root.userThemesDir(), root.systemThemesDir]
        linkProc.running = true
    }

    property Process linkProc: Process {
        id: linkProc
        command: []
        onExited: () => { root.refreshThemes() }
    }

    // ---- theme listing -----------------------------------------------------
    // Lists every valid theme folder in the user themes dir. A line looks like
    // "<name>|user" for a real (uploaded) theme or "<name>|system" for a
    // symlink to the built-in themes.
    function refreshThemes() {
        listProc.command = ["sh", "-c",
            'dir="$1"; [ -d "$dir" ] || exit 0; ' +
            'for d in "$dir"/*/; do ' +
            '  [ -d "$d" ] || continue; ' +
            '  n=$(basename "$d"); ' +
            '  [ -f "$d/CursorData.json" ] && [ -f "$d/index.html" ] || continue; ' +
            '  if [ -L "$d" ]; then echo "$n|system"; else echo "$n|user"; fi; ' +
            'done',
            "--", root.userThemesDir()]
        listProc.running = true
    }

    property Process listProc: Process {
        id: listProc
        stdout: StdioCollector {
            id: listStdout
            onStreamFinished: {
                const names = []
                const kinds = {}
                const lines = (listStdout.text || "").split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line) continue
                    const sep = line.lastIndexOf("|")
                    if (sep <= 0) continue
                    const name = line.substring(0, sep)
                    kinds[name] = line.substring(sep + 1)
                    names.push(name)
                }
                root._themeKinds = kinds
                root.themeList = names
            }
        }
    }

    function themePath(name: string) {
        if (!name || name.indexOf("/") !== -1 || name.indexOf("\\") !== -1)
            return ""
        return `${root.userThemesDir()}/${name}`
    }

    // true when the theme was uploaded by the user (a real folder); false for
    // symlinked built-in themes.
    function isUserTheme(name: string) {
        return root._themeKinds[name] === "user"
    }

    function getThemeDetails(name: string) {
        const details = { iconPath: "", author: qsTr("Unknown"), describe: "", minWidth: 128, minHeight: 128 }
        const path = root.themePath(name)
        if (!path) return details
        try {
            const xhr = new XMLHttpRequest()
            xhr.open("GET", "file://" + path + "/CursorData.json", false)
            xhr.send()
            if (xhr.status !== 200 && xhr.status !== 0) return details
            const obj = JSON.parse(xhr.responseText)
            if (obj.IconPath) details.iconPath = "file://" + path + "/" + obj.IconPath
            details.author = obj.Author || details.author
            details.describe = obj.describe || ""
            details.minWidth = parseInt(obj.minWidth, 10) || 128
            details.minHeight = parseInt(obj.minHeight, 10) || 128
        } catch (e) {
            console.warn("Failed to read theme data:", name, e)
        }
        return details
    }

    function openThemeFolder(name: string) {
        const path = root.themePath(name)
        if (path) Quickshell.execDetached(["xdg-open", path])
    }

    // ---- upload / remove ---------------------------------------------------
    function uploadTheme(srcPath: string, themeName: string) {
        const src = String(srcPath || "").replace(/^file:\/\//, "")
        if (!src) {
            root.statusMessage = qsTr("Invalid folder")
            root.themeUploadFinished(false, root.statusMessage)
            return
        }
        let name = String(themeName || "").trim()
        if (!name) {
            const parts = src.split("/").filter(p => p.length > 0)
            name = parts.length > 0 ? parts[parts.length - 1] : ""
        }
        name = name.replace(/[/\\]/g, "") // prevent path traversal
        if (!name) {
            root.statusMessage = qsTr("Invalid folder or theme name")
            root.themeUploadFinished(false, root.statusMessage)
            return
        }

        const dst = `${root.userThemesDir()}/${name}`
        const script =
            'src="$1"; dst="$2"; ' +
            '[ -d "$src" ] || { echo "source is not a directory" >&2; exit 1; }; ' +
            '[ -f "$src/CursorData.json" ] && [ -f "$src/index.html" ] || { echo "selected folder is not a valid cursor theme" >&2; exit 1; }; ' +
            '[ -L "$dst" ] && rm -f -- "$dst"; ' +
            'rm -rf -- "$dst" || exit 1; mkdir -p -- "$dst" || exit 1; ' +
            'cp -r -- "$src"/. "$dst"/ || exit 1'
        uploadProc.command = ["sh", "-c", script, "--", src, dst]
        uploadProc._themeName = name
        uploadProc.running = true
    }

    property Process uploadProc: Process {
        id: uploadProc
        property string _themeName: ""
        stderr: StdioCollector {
            id: uploadStderr
        }
        onExited: code => {
            if (code === 0) {
                root.refreshThemes()
                root.setTheme(uploadProc._themeName)
                root.statusMessage = qsTr("Theme uploaded successfully")
                root.themeUploadFinished(true, "")
            } else {
                root.statusMessage = (uploadStderr.text || "").trim() || qsTr("Theme upload failed")
                root.themeUploadFinished(false, root.statusMessage)
            }
        }
    }

    function removeTheme(themeName: string) {
        if (!themeName) {
            root.themeRemoveFinished(false, qsTr("Empty theme name"))
            return
        }
        const dst = `${root.userThemesDir()}/${themeName}`
        const script =
            'dst="$1"; ' +
            '[ -e "$dst" ] || [ -L "$dst" ] || exit 2; ' +
            '[ -L "$dst" ] && { echo "cannot remove a built-in theme" >&2; exit 3; }; ' +
            'rm -rf -- "$dst"'
        removeProc.command = ["sh", "-c", script, "--", dst]
        removeProc._themeName = themeName
        removeProc.running = true
    }

    property Process removeProc: Process {
        id: removeProc
        property string _themeName: ""
        stderr: StdioCollector {
            id: removeStderr
        }
        onExited: code => {
            if (code === 0) {
                if (root.config && root.config.selectTheme === removeProc._themeName)
                    root.config.selectTheme = ""
                root.refreshThemes()
                root.statusMessage = qsTr("Theme removed successfully")
                root.themeRemoveFinished(true, "")
            } else if (code === 3) {
                root.statusMessage = qsTr("Built-in themes cannot be removed")
                root.themeRemoveFinished(false, root.statusMessage)
            } else {
                root.statusMessage = qsTr("Theme not found")
                root.themeRemoveFinished(false, root.statusMessage)
            }
        }
    }

    // ---- apply / control the KWin effect -----------------------------------
    function setTheme(themeName: string) {
        if (!root.config) return
        root.config.selectTheme = themeName
    }

    function useTheme(themeName: string) {
        root.setTheme(themeName)
        root.statusMessage = qsTr("Theme applied successfully")
    }

    function reload() {
        root.refreshThemes()
        root.statusMessage = qsTr("Reloaded successfully")
    }

    function enable() {
        if (!root.config) return
        root.config.enabled = true
        kwinToggleProc.command = ["sh", "-c",
            'busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects loadEffect s ultralightwebcursor 2>/dev/null; ' +
            'busctl --user call org.kde.KWin /UltralightCursor org.kde.kwin.KWin.KwinCursorEffect enable 2>/dev/null; ' +
            'true']
        kwinToggleProc.running = true
        root.save()
        root.statusMessage = qsTr("Enabled")
    }

    function disable() {
        if (!root.config) return
        root.config.enabled = false
        kwinToggleProc.command = ["sh", "-c",
            'busctl --user call org.kde.KWin /UltralightCursor org.kde.kwin.KWin.KwinCursorEffect disable 2>/dev/null; ' +
            'true']
        kwinToggleProc.running = true
        root.save()
        root.statusMessage = qsTr("Disabled")
    }

    property Process kwinToggleProc: Process {
        id: kwinToggleProc
        command: []
    }

    // ---- Blacklist (delegates to the config object) ------------------------
    function addBlacklist(app: string) {
        if (root.config) root.config.addBlacklist(app)
    }

    function removeBlacklist(app: string) {
        if (root.config) root.config.removeBlacklist(app)
    }

    // ---- Apply size / config changes to KWin -------------------------------
    // Only reloadHtml: /KWin reconfigure makes KWin re-read kwinrc and
    // unload/reload effect plugins, which destroys and re-creates the
    // Ultralight renderer and crashes KWin.
    function save() {
        if (!root.config) return
        root.config.saveNow()
        reconfigureProc.running = true
        root.statusMessage = qsTr("Saved")
    }

    property Process reconfigureProc: Process {
        id: reconfigureProc
        command: ["sh", "-c",
            'busctl --user call org.kde.KWin /UltralightCursor org.kde.kwin.KWin.KwinCursorEffect reloadHtml 2>/dev/null; ' +
            'true']
    }
}
