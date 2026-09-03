pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services.api
import qs.services
import "qml"
import "qml/settings"

Scope {
    id: root

    property var config: WebCursorConfig {}
    property var manager: WebCursorManager {
        config: root.config
        // Let the manager drop the fullscreen overlay before any pkexec prompt.
        windowHider: () => { root.showing = false }
    }

    property bool showing: false
    property bool buildingEffect: false
    property string buildStatusMessage: ""

    // ---- effect bootstrap (contents/ cmake) -------------------------------
    readonly property string _pluginDir: _localPath(Qt.resolvedUrl("."))

    function _localPath(url): string {
        const s = String(url || "").replace(/^file:\/\//, "")
        try { return decodeURIComponent(s) } catch (e) { return s }
    }

    function _setBuildStatus(text) {
        root.buildStatusMessage = text || ""
        if (root.manager)
            root.manager.statusMessage = root.buildStatusMessage
    }


    function bootstrapEffect() {
        if (root.buildingEffect) return
        if (!root.config || !root.config.autoBuild) return
        if (!root._pluginDir) return

        const dir = root._pluginDir
        const script =
            'dir="$1"; ' +
            'cd "$dir" || { echo "plugin-dir-missing" >&2; exit 2; }; ' +
            'if [ -f build/CMakeCache.txt ] && [ -f build/.webcursor-built ]; then ' +
            '  echo "ready"; exit 0; ' +
            'fi; ' +
            'if ! command -v cmake >/dev/null 2>&1; then ' +
            '  echo "cmake-missing" >&2; exit 3; ' +
            'fi; ' +
            'echo "configuring"; ' +
            'cmake -S . -B build >/dev/null 2>&1 || { echo "configure-failed" >&2; exit 4; }; ' +
            'echo "building"; ' +
            'cmake --build build -j 4 >/dev/null 2>&1 || { echo "build-failed" >&2; exit 5; }; ' +
            'touch build/.webcursor-built; ' +
            'echo "built"'

        buildProc.command = ["sh", "-c", script, "--", dir]
        root.buildingEffect = true
        root._setBuildStatus(qsTr("Checking the cursor effect build…"))
        console.info("[web-cursor] bootstrap build started in", dir)
        buildProc.running = true
    }

    property Process buildProc: Process {
        id: buildProc
        command: []
        stdout: StdioCollector {
            id: buildStdout
        }
        stderr: StdioCollector {
            id: buildStderr
        }
        onExited: code => {
            root.buildingEffect = false
            const output = (buildStdout.text || "").trim()
            const err = (buildStderr.text || "").trim()
            if (code === 0 && output === "ready") {
                root._setBuildStatus("")
                console.info("[web-cursor] effect already built")
            } else if (code === 0 && output === "built") {
                root._setBuildStatus(qsTr("Cursor effect built successfully"))
                console.info("[web-cursor] effect built; install it with 'sudo cmake --install build'")
            } else {
                let reason = err
                if (!reason) {
                    if (code === 3) reason = qsTr("cmake is not installed")
                    else if (code === 4) reason = qsTr("cmake configure failed")
                    else if (code === 5) reason = qsTr("cmake build failed")
                    else if (code === 2) reason = qsTr("plugin folder not found")
                    else reason = qsTr("unknown build error (%1)").arg(code)
                }
                root._setBuildStatus(qsTr("Cursor effect build failed: %1").arg(reason))
                console.error("[web-cursor] build failed:", reason)
            }
        }
    }

    function registerShortcut() {
        const hasApi = typeof CaelestiaApi !== "undefined" && !!CaelestiaApi.shortcuts
        if (!hasApi) {
            console.warn("[web-cursor] CaelestiaApi.shortcuts unavailable; settings shortcut disabled")
            return
        }
        console.info("[web-cursor] registering shortcut", root.config.shortcut)
        CaelestiaApi.shortcuts.register("webcursor_settings", "Toggle Web Cursor Settings", root.config.shortcut, () => {
            root.showing = !root.showing
            console.info("[web-cursor] shortcut fired, showing =", root.showing)
        })
    }

    Connections {
        target: root.config
        function onShortcutChanged() { registerShortcut() }
    }

    Component.onCompleted: {
        bootstrapTimer.start()
        root.manager.ensureInitialized()
        root.registerShortcut()
    }

    Timer {
        id: bootstrapTimer
        interval: 400
        repeat: false
        onTriggered: root.bootstrapEffect()
    }

    // ---- settings overlay --------------------------------------------------
    // The PanelWindow is created when the settings open and destroyed when they
    // close. There is no persistent layer surface and no map/unmap of a live
    // window, which removes the render-thread crash class seen before.
    Loader {
        id: settingsLoader
        active: root.showing

        sourceComponent: Component {
            PanelWindow {
                id: panel
                screen: Quickshell.primaryScreen
                color: "transparent"

                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.namespace: "webcursor-settings"

                Component.onCompleted: console.info("[web-cursor] overlay window created")

                WebCursorSettingsPanel {
                    anchors.fill: parent
                    showing: true
                    colors: Colors {}
                    config: root.config
                    manager: root.manager
                    buildStatus: root.buildStatusMessage
                    onCloseRequested: root.showing = false
                }
            }
        }
    }
}
