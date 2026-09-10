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
    property bool effectInstalled: false
    property string artifactFingerprint: ""
    property string buildStatusMessage: ""
    property var shortcutHandle: null

    // Guards for the one-shot bootstrap build/install; the periodic checks
    // below must not rerun them every time they fire.
    property bool _artifactChecked: false
    property bool _autoBuildTried: false
    property bool _autoInstallTried: false

    readonly property string _pluginDir: _localPath(Qt.resolvedUrl("."))
    // The settings UI ships in the same folder as the KWin effect, so the
    // CMake project and its ThirdParty/ SDK live right next to this file.
    readonly property string _effectPluginDir: _pluginDir

    // Remembers the built artifact that was last installed into the system, so
    // the automatic install runs once per build instead of on every start.
    readonly property string _installMarker: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/caelestia/webcursor/installed-fingerprint"

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
            root._maybeAutoBuild()
        }
    }

    function checkBuildArtifact() {
        if (artifactCheckProc.running) return
        // Echoes three lines: ready/missing, the artifact hash, and whether that
        // exact artifact is the one already installed into the system.
        artifactCheckProc.command = ["sh", "-c",
            'f=$(find "$1/build" -type f -name ultralightwebcursor.so -size +0c -print -quit 2>/dev/null); ' +
            '[ -n "$f" ] || { echo missing; exit 0; }; ' +
            'echo ready; ' +
            'fp=$(sha256sum "$f" 2>/dev/null | cut -d" " -f1); echo "$fp"; ' +
            '[ -f "$2" ] && [ "$(cat "$2")" = "$fp" ] && echo installed || echo not-installed',
            "--", root._effectPluginDir, root._installMarker]
        artifactCheckProc.running = true
    }

    property Process artifactCheckProc: Process {
        id: artifactCheckProc
        command: []
        stdout: StdioCollector { id: artifactCheckStdout }
        onExited: () => {
            const lines = (artifactCheckStdout.text || "").split("\n")
            const ready = (lines[0] || "").trim() === "ready"
            const becameReady = ready && !root.artifactReady
            root.artifactReady = ready
            root.artifactFingerprint = ready ? (lines[1] || "").trim() : ""
            root.effectInstalled = ready && (lines[2] || "").trim() === "installed"
            root._artifactChecked = true
            if (becameReady && !root.buildingEffect)
                root._setBuildStatus(qsTr("Effect library ready: ultralightwebcursor.so"))
            root._maybeAutoBuild()
            root._maybeAutoInstall()
        }
    }

    // Build the effect once, on startup, when the Ultralight SDK is present, the
    // build output is missing and the user has not opted out of auto-building.
    // Installing the plugin from the store then gets the effect built for the
    // automatic system install below.
    function _maybeAutoBuild() {
        if (root._autoBuildTried || !root._artifactChecked) return
        if (root.artifactReady || root.buildingEffect || !root.sdkReady) return
        if (!root.config.autoBuild) return
        root._autoBuildTried = true
        root.buildEffect()
    }

    // Install the built effect into KWin automatically, once per build. This is
    // the same privileged `pkexec cmake --install` the panel's Install button
    // runs; the marker file records which artifact was installed. A build that
    // changes the artifact (e.g. after a plugin update) installs again.
    function _maybeAutoInstall() {
        if (root._autoInstallTried || !root._artifactChecked) return
        if (!root.artifactReady || root.effectInstalled) return
        if (root.buildingEffect || root.installingEffect) return
        if (!root.config.autoInstall) return
        root._autoInstallTried = true
        root._installEffect()
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
        console.info("[web-cursor] installing effect with pkexec") // caelestia-audit: allow-privilege
        installProc.command = ["pkexec", "cmake", "--install", root._effectPluginDir + "/build"] // caelestia-audit: allow-privilege
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
                markInstalledProc.command = ["sh", "-c",
                    'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
                    "--", root._installMarker, root.artifactFingerprint]
                markInstalledProc.running = true
            } else {
                // pkexec exit 126 means the polkit dialog was dismissed. Take
                // that as "do not install automatically" and stop asking; the
                // panel's Install button remains available.
                const dismissed = code === 126
                if (dismissed && root.config.autoInstall)
                    root.config.autoInstall = false
                if (dismissed)
                    root._setBuildStatus(qsTr("Cursor effect install dismissed; automatic install disabled. Use Install to retry."))
                else
                    root._setBuildStatus(qsTr("Cursor effect install %1: %2").arg(
                        err.length > 0 ? qsTr("failed") : qsTr("cancelled"), err))
                console.error("[web-cursor] install failed:", err)
            }
        }
    }

    // Records the artifact that is now live in the system, so the next start
    // does not offer to install it again, and brings the effect up in KWin.
    property Process markInstalledProc: Process {
        id: markInstalledProc
        command: []
        onExited: () => {
            root.checkBuildArtifact()
            if (root.config.enabled)
                root.manager.enable()
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
