import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia
import Caelestia.Config as ShellConfig
import qs.components.controls
import qs.components.containers
import qs.components
import qs.modules.nexus.common as Common
import "../.." // For Config

Item {
    id: root
    property var colors
    property bool showing: false
    
    signal closeClicked()
    
    anchors.fill: parent
    visible: showing || opacity > 0
    opacity: showing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
    z: 1000
    
    onShowingChanged: {
        console.log("SettingsPanel showing changed:", showing, "colors:", colors, "surfaceContainer:", colors ? colors.surfaceContainer : "null")
    }
    
    function openCaptureDialog(name, currentKey, targetItem) {
        shortcutDialogLoader.active = true
        shortcutDialogLoader.item.shortcutName = name
        shortcutDialogLoader.item.currentKey = currentKey
        shortcutDialogLoader.item.targetItem = targetItem
        shortcutDialogLoader.item.open()
    }
    
    Loader {
        id: shortcutDialogLoader
        active: false
        sourceComponent: Common.KeyCaptureDialog {
            onConfirm: function(name, newKey) {
                Config.saveKey("components.appWallpaper.shortcut", newKey)
            }
            onClear: function(name) {
                Config.saveKey("components.appWallpaper.shortcut", Config.defaultConfig.components.appWallpaper.shortcut)
            }
            onUnblocked: function() {
                shortcutDialogLoader.active = false
            }
        }
    }
    
    // Dim background
    MouseArea {
        anchors.fill: parent
        onClicked: root.showing = false
        
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.5
        }
    }
    
    // Main Modal
    Rectangle {
        id: modalRect
        width: 600
        height: Math.min(parent.height - 100, 750)
        anchors.centerIn: parent
        color: colors ? Qt.rgba(colors.surfaceContainer.r, colors.surfaceContainer.g, colors.surfaceContainer.b, 0.95) : "transparent"
        radius: ShellConfig.Tokens.rounding.extraLarge
        clip: true
        
        // Scale and slide animation
        scale: root.showing ? 1.0 : 0.95
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        
        // Close Button (Sticky)
        Text {
            z: 11
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: ShellConfig.Tokens.padding.largeIncreased
            anchors.rightMargin: ShellConfig.Tokens.padding.largeIncreased
            text: "\uF00D" // nf-fa-times
            font.family: "Symbols Nerd Font"
            font.pixelSize: 24
            color: colors ? (closeMouse.containsMouse ? colors.primary : colors.surfaceText) : "white"
            
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showing = false
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        
        // Content
        VerticalFadeFlickable {
            id: flickable
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: contentLayout.implicitHeight + ShellConfig.Tokens.padding.largeIncreased * 2
            
            ScrollBar.vertical: ScrollBar {
                active: flickable.contentHeight > flickable.height
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: width / 2
                    color: colors ? colors.primary : "white"
                    opacity: parent.active ? 0.8 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
            
            ColumnLayout {
                id: contentLayout
                width: modalRect.width - ShellConfig.Tokens.padding.largeIncreased * 2
                x: ShellConfig.Tokens.padding.largeIncreased
                y: ShellConfig.Tokens.padding.largeIncreased
                spacing: 0
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Settings"
                        font: ShellConfig.Tokens.font.title.large
                        color: colors ? colors.surfaceText : "white"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    TextButton {
                        text: "RESET"
                        type: TextButton.Filled
                        Layout.rightMargin: 30
                        onClicked: {
                            Config.resetToDefault()
                        }
                    }
                }
                
                // --- General ---
                Common.SectionHeader { text: "General"; first: false }
                
                Common.SelectRow {
                    label: "Display Mode"
                    subtext: "Layout style of the wallpaper browser"
                    first: true
                    last: false
                    property var modeIds: ["slice", "hex", "grid"]
                    active: menuItems[Math.max(0, modeIds.indexOf(Config.displayMode))]
                    
                    menuItems: [
                        MenuItem { text: "Slice" },
                        MenuItem { text: "Hex" },
                        MenuItem { text: "Grid" }
                    ]
                    
                    onSelected: function(item) {
                        var idx = menuItems.indexOf(item)
                        if (idx >= 0) {
                            Config.saveKey("components.appWallpaper.displayMode", modeIds[idx])
                        }
                    }
                }
                
                Common.ShortcutRow {
                    label: "Toggle Shortcut"
                    actionName: "wallpaper_selector"
                    keybind: Config.shortcut
                    isOverridden: Config.shortcut !== Config.defaultConfig.components.appWallpaper.shortcut
                    first: false
                    last: true
                    onAddClicked: function(target) {
                        root.openCaptureDialog("Toggle Wallpaper Selector", Config.shortcut, target)
                    }
                    onKeybindEdited: function(newKeybind) {
                        Config.saveKey("components.appWallpaper.shortcut", newKeybind)
                    }
                    onResetClicked: function() {
                        Config.saveKey("components.appWallpaper.shortcut", Config.defaultConfig.components.appWallpaper.shortcut)
                    }
                }
                
                // --- Slice Settings ---
                Common.SectionHeader { text: "Slice Mode" }
                
                SettingsSlider {
                    label: "Inactive Width"
                    first: true
                    from: 50; to: 400; stepSize: 5
                    actualValue: Config.sliceWidth
                    onUpdated: val => Config.saveKey("components.appWallpaper.sliceWidth", val)
                }
                SettingsSlider {
                    label: "Expanded Width"
                    from: 400; to: 1600; stepSize: 10
                    actualValue: Config.expandedWidth
                    onUpdated: val => Config.saveKey("components.appWallpaper.expandedWidth", val)
                }
                SettingsSlider {
                    label: "Height"
                    from: 200; to: 1000; stepSize: 10
                    actualValue: Config.sliceHeight
                    onUpdated: val => Config.saveKey("components.appWallpaper.sliceHeight", val)
                }
                SettingsSlider {
                    label: "Skew Offset"
                    from: -150; to: 150; stepSize: 5
                    actualValue: Config.skewOffset
                    onUpdated: val => Config.saveKey("components.appWallpaper.skewOffset", val)
                }
                SettingsSlider {
                    label: "Spacing"
                    last: true
                    from: -100; to: 100; stepSize: 2
                    actualValue: Config.sliceSpacing
                    onUpdated: val => Config.saveKey("components.appWallpaper.sliceSpacing", val)
                }
                
                // --- Hex Settings ---
                Common.SectionHeader { text: "Hex Mode" }
                
                SettingsSlider {
                    label: "Hex Radius"
                    first: true
                    from: 50; to: 300; stepSize: 5
                    actualValue: Config.hexRadius
                    onUpdated: val => Config.saveKey("components.appWallpaper.hexRadius", val)
                }
                SettingsSlider {
                    label: "Rows"
                    from: 1; to: 10; stepSize: 1
                    actualValue: Config.hexRows
                    onUpdated: val => Config.saveKey("components.appWallpaper.hexRows", val)
                }
                SettingsSlider {
                    label: "Columns"
                    from: 1; to: 20; stepSize: 1
                    actualValue: Config.hexCols
                    onUpdated: val => Config.saveKey("components.appWallpaper.hexCols", val)
                }
                SettingsSlider {
                    label: "Arc Intensity"
                    last: true
                    from: 0.0; to: 3.0; stepSize: 0.1
                    actualValue: Config.hexArcIntensity
                    onUpdated: val => Config.saveKey("components.appWallpaper.hexArcIntensity", val)
                }
                
                // --- Grid Settings ---
                Common.SectionHeader { text: "Grid Mode" }
                
                SettingsSlider {
                    label: "Columns"
                    first: true
                    from: 1; to: 15; stepSize: 1
                    actualValue: Config.gridColumns
                    onUpdated: val => Config.saveKey("components.appWallpaper.gridColumns", val)
                }
                SettingsSlider {
                    label: "Rows"
                    from: 1; to: 10; stepSize: 1
                    actualValue: Config.gridRows
                    onUpdated: val => Config.saveKey("components.appWallpaper.gridRows", val)
                }
                SettingsSlider {
                    label: "Thumbnail Width"
                    from: 100; to: 800; stepSize: 10
                    actualValue: Config.gridThumbWidth
                    onUpdated: val => Config.saveKey("components.appWallpaper.gridThumbWidth", val)
                }
                SettingsSlider {
                    label: "Thumbnail Height"
                    last: true
                    from: 50; to: 600; stepSize: 10
                    actualValue: Config.gridThumbHeight
                    onUpdated: val => Config.saveKey("components.appWallpaper.gridThumbHeight", val)
                }
                
                Item { Layout.preferredHeight: ShellConfig.Tokens.padding.largeIncreased } // Bottom padding
            }
        }
    }
    
    // Inline wrapper to normalize our min/max into 0..1 for the SliderRow
    component SettingsSlider : Common.SliderRow {
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real actualValue: 0
        
        signal updated(real val)
        
        value: Math.max(0.0, Math.min(1.0, (actualValue - from) / (to - from)))
        valueLabel: Number(actualValue).toFixed(stepSize < 1 ? 1 : 0)
        
        onInteraction: function(v) {
            var val = from + v * (to - from)
            val = Math.round(val / stepSize) * stepSize
            updated(val)
        }
    }
}
