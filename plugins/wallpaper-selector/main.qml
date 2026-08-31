pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services.api
import qs.services

import "qml" as PluginStyle
import "qml/wallpaper" as WallpaperQml

Scope {
    id: root

    property bool showing: false
    property string activeScreen: ""

    Component.onCompleted: {
        CaelestiaApi.shortcuts.register("wallpaper_selector", "Toggle Wallpaper Selector", "Meta+Shift+E", () => {
            if (!root.showing) {
                if (typeof CaelestiaApi.windows.kwin !== "undefined" && CaelestiaApi.windows.kwin) {
                    root.activeScreen = CaelestiaApi.windows.kwin.cursorOutputName() || "";
                } else if (typeof Hypr !== "undefined" && Hypr) {
                    root.activeScreen = Hypr.focusedMonitor ? Hypr.focusedMonitor.name : "";
                }
                root.showing = true;
            } else {
                root.showing = false;
            }
        });
    }

    Variants {
        model: Quickshell.screens

        WallpaperQml.WallpaperSelector {
            required property var modelData
            screen: modelData
            showing: root.showing
            isMainScreen: modelData.name === root.activeScreen
            colors: PluginStyle.Colors {}
            
            Connections {
                target: root
                function onShowingChanged() {
                    if (showing !== root.showing) {
                        showing = root.showing;
                    }
                }
            }
            
            onShowingChanged: {
                if (!showing && root.showing) {
                    root.showing = false;
                }
            }
        }
    }
}
