pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services.api

import "qml" as PluginStyle
import "qml/wallpaper" as WallpaperQml

Scope {
    id: root

    property alias showing: selector.showing
    
    // Register the toggle shortcut
    Component.onCompleted: {
        CaelestiaApi.shortcuts.register("wallpaper_selector", "Toggle Wallpaper Selector", "Meta+Shift+W", () => {
            root.showing = !root.showing;
        });
    }

    WallpaperQml.WallpaperSelector {
        id: selector
        colors: PluginStyle.Colors {}
    }
}
