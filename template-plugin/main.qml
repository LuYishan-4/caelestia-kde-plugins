// A minimal Caelestia (Quickshell) widget - replace with your own plugin.
import Quickshell
import QtQuick

PanelWindow {
    anchors {
        top: true
        left: true
    }

    color: "transparent"

    Text {
        anchors.centerIn: parent
        text: "Hello from your plugin"
        color: "#e0e0e0"
        font.pixelSize: 16
    }
}
