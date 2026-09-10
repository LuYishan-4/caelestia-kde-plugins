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
        windowHider: () => { root.showing = false }
    }

    property bool showing: false
    property bool buildingEffect: false
    property bool sdkReady: false
    property bool sdkMissing: false
    property bool artifactReady: false
    property string buildStatusMessage: ""
    property var shortcutHandle: null

    readonly property string _pluginDir: _localPath(Qt.resolvedUrl("."))
    // The store installs the settings UI next to its KWin effect dependency.
    readonly property string _effectPluginDir: _pluginDir + "/../web-cursor"

    function _localPath(url): string {
        const s = String(url || "").replace(/^file:\/\//, "")
        try { return decodeURIComponent(s) } catch (e) { return s }
    }

    function _setBuildStatus(text) {
        root.buildStatusMessage = text || ""
        if (root.manager)
            root.manager.statusMessage = root.buildStatusMessage
    }

    function checkSdk() {
        if (!root._effectPluginDir) return
        if (sdkCheckProc.running) return
        sdkCheckProc.command = ["sh", "-c",
            'sdk="$1/ThirdParty"; ' +
            '[ -f "$sdk/include/AppCore/App.h" ] && ' +
            '[ -f "$sdk/bin/libUltralightCore.so" ] && ' +
            '[ -d "$sdk/resources" ] && echo ready || echo missing',
            "--", root._effectPluginDir]
        sdkCheckProc.running = true
    }

    property Process sdkCheckProc: Process {
        id: sdkCheckProc
        command: []
        stdout: StdioCollector { id: sdkCheckStdout }
        onExited: () => {
            const ready = (sdkCheckStdout.text || "").trim() === "ready"
            const changed = ready !== root.sdkReady
            root.sdkReady = ready
            root.sdkMissing = !ready
            // Only announce on transitions; the periodic check must not clobber
            // build/install progress messages.
            if (changed)
                root._setBuildStatus(ready
                    ? qsTr("Ultralight SDK found in ThirdParty. Ready to build.")
                    : qsTr("Ultralight SDK is not installed in ThirdParty."))
        }
    }

    function checkBuildArtifact() {
        if (artifactCheckProc.running) return
        artifactCheckProc.command = ["sh", "-c",
            'find "$1/build" -type f -name ultralightwebcursor.so -size +0c -print -quit 2>/dev/null | grep -q . && echo ready || echo missing',
            "--", root._effectPluginDir]
        artifactCheckProc.running = true
    }

    property Process artifactCheckProc: Process {
        id: artifactCheckProc
        command: []
        stdout: StdioCollector { id: artifactCheckStdout }
        onExited: () => {
            const ready = (artifactCheckStdout.text || "").trim() === "ready"
            const becameReady = ready && !root.artifactReady
            root.artifactReady = ready
            if (becameReady && !root.buildingEffect)
                root._setBuildStatus(qsTr("Effect library ready: ultralightwebcursor.so"))
        }
    }

    function buildEffect() {
        if (root.buildingEffect) return
        if (!root._effectPluginDir) return
        if (!root.sdkReady) {
            root._setBuildStatus(qsTr("Install the Ultralight SDK in the ThirdParty folder before building."))
            root.checkSdk()
            return
        }

        const dir = root._effectPluginDir
        const script =
            'dir="$1"; ' +
            'cd "$dir" || { echo "plugin-dir-missing" >&2; exit 2; }; ' +
            'if find build -type f -name ultralightwebcursor.so -size +0c -print -quit 2>/dev/null | grep -q .; then ' +
            '  echo "ready"; exit 0; ' +
            'fi; ' +
            'if ! command -v cmake >/dev/null 2>&1; then ' +
            '  echo "cmake-missing" >&2; exit 3; ' +
            'fi; ' +
            'echo "configuring"; ' +
            'cmake -S . -B build || { echo "configure-failed" >&2; exit 4; }; ' +
            'echo "building"; ' +
            'cmake --build build -j 4 >/dev/null 2>&1 || { echo "build-failed" >&2; exit 5; }; ' +
            'find build -type f -name ultralightwebcursor.so -size +0c -print -quit 2>/dev/null | grep -q . || { echo "artifact-missing" >&2; exit 6; }; ' +
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
                root._setBuildStatus(qsTr("Build output is ready."))
                console.info("[web-cursor] effect build output already exists")
            } else if (code === 0 && output === "built") {
                root._setBuildStatus(qsTr("Build completed; verifying ultralightwebcursor.so…"))
            } else {
                root.sdkMissing = (output + "\n" + err).indexOf("Ultralight SDK was not found") !== -1
                let reason = err
                if (root.sdkMissing)
                    reason = qsTr("Ultralight SDK is not installed")
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
            root.checkSdk()
            root.checkBuildArtifact()
        }
    }

    // ---- system install after a fresh build --------------------------------
    // `cmake --install` writes into system dirs, so it goes through pkexec.
    property bool installingEffect: false

    function _installEffect() {
        if (root.installingEffect) return
        if (!root.artifactReady) {
            root._setBuildStatus(qsTr("Cannot install: ultralightwebcursor.so is not built yet"))
            return
        }
        root.installingEffect = true
        root.showing = false
        root._setBuildStatus(qsTr("Installing the cursor effect…"))
        console.info("[web-cursor] installing effect with pkexec")
        installProc.command = ["pkexec", "cmake", "--install", root._effectPluginDir + "/build"]
        installProc.running = true
    }

    property Process installProc: Process {
        id: installProc
        command: []
        stdout: StdioCollector {
            id: installStdout
        }
        stderr: StdioCollector {
            id: installStderr
        }
        onExited: code => {
            root.installingEffect = false
            const err = (installStderr.text || "").trim()
            if (code === 0) {
                root._setBuildStatus(qsTr("Cursor effect installed successfully"))
                console.info("[web-cursor] effect installed; reconfigure KWin to load it")
            } else {
                root._setBuildStatus(qsTr("Cursor effect install %1: %2").arg(
                    err.length > 0 ? qsTr("failed") : qsTr("cancelled"), err))
                console.error("[web-cursor] install failed:", err)
            }
        }
    }

    function registerShortcut() {
        const hasApi = typeof CaelestiaApi !== "undefined" && !!CaelestiaApi.shortcuts
        if (!hasApi) {
            console.warn("[web-cursor] CaelestiaApi.shortcuts unavailable; settings shortcut disabled")
            return
        }
        if (root.shortcutHandle) {
            root.shortcutHandle.destroy()
            root.shortcutHandle = null
        }
        console.info("[web-cursor] registering shortcut", root.config.shortcut)
        root.shortcutHandle = CaelestiaApi.shortcuts.register("webcursor_settings", "Toggle Web Cursor Settings", root.config.shortcut, () => {
            root.showing = !root.showing
            console.info("[web-cursor] shortcut fired, showing =", root.showing)
        })
    }

    Connections {
        target: root.config
        function onShortcutChanged() { registerShortcut() }
    }

    Component.onCompleted: {
        root.manager.ensureInitialized()
        root.registerShortcut()
        root.checkSdk()
        root.checkBuildArtifact()
    }

    // Poll the SDK and the build artifact so the panel reflects changes made
    // outside the UI (files copied in/removed, builds from a terminal).
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.checkSdk()
            root.checkBuildArtifact()
        }
    }

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
                    sdkMissing: root.sdkMissing
                    sdkReady: root.sdkReady
                    artifactReady: root.artifactReady
                    buildingEffect: root.buildingEffect
                    installingEffect: root.installingEffect
                    onBuildRequested: root.buildEffect()
                    onInstallRequested: root._installEffect()
                    onCloseRequested: root.showing = false
                }
            }
        }
    }
}
