// Settings UI for the web cursor effect.
//
// Port of `caelestia-dots-kde/shell/modules/nexus/pages/desktop/WebCursorPage.qml`
// into the plugin's own QML architecture (mirroring the wallpaper-selector
// plugin): no dependency on shell-only `qs.components` / `nexus.common`
// controls — rows, switches and steppers are the plugin's own components and
// all state lives in the `WebCursorConfig` / `WebCursorManager` singletons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import ".."
import "../components"

Item {
    id: root

    signal closeRequested()

    property bool showing: false
    property var colors: null
    property var config: null
    property var manager: null
    property string buildStatus: ""

    visible: showing || opacity > 0
    opacity: showing ? 1 : 0
    enabled: showing
    Behavior on opacity { NumberAnimation { duration: Style.animMedium; easing.type: Easing.InOutQuad } }

    onShowingChanged: {
        if (root.showing) {
            root.forceActiveFocus()
            if (root.manager) root.manager.refreshThemes()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        }
    }

    // Dim background - swallows clicks outside the modal.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.5
        }
    }

    // Modal card
    Rectangle {
        id: modal
        width: Math.max(340, Math.min(720, parent.width - 80))
        height: Math.max(360, Math.min(parent.height - 120, contentLayout.implicitHeight + 120))
        anchors.centerIn: parent
        radius: Style.radiusXLarge + 4
        clip: true
        color: colors ? colors.surfaceContainer : "transparent"
        scale: root.showing ? 1.0 : 0.95
        Behavior on scale { NumberAnimation { duration: Style.animEnter; easing.type: Easing.OutBack } }

        // Modal guard so clicks inside do not bubble to the dim layer.
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Style.paddingLarge
                Layout.leftMargin: Style.paddingXLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: qsTr("Web Cursor")
                        font.family: Style.fontFamilyHeading
                        font.pixelSize: Style.fontTitleLarge
                        font.weight: Font.DemiBold
                        color: colors ? colors.surfaceText : "#e0e0e0"
                    }
                    Text {
                        text: qsTr("HTML/CSS cursor rendered through KWin by Ultralight")
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontCaption
                        color: colors ? colors.surfaceVariantText : "#b0b0b0"
                    }
                }

                IconButton {
                    glyph: "\uF00D" // nf-fa-times (Symbols Nerd Font)
                    iconFont: Style.fontFamilyNerdIcons
                    colors: root.colors
                    tip: qsTr("Close")
                    onClicked: root.closeRequested()
                }
            }

            // Scrollable content
            Flickable {
                id: contentFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: contentLayout.implicitHeight + Style.paddingXLarge
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    parent: contentFlick
                    anchors.top: contentFlick.top
                    anchors.right: contentFlick.right
                    anchors.bottom: contentFlick.bottom
                    active: contentFlick.contentHeight > contentFlick.height
                    visible: active
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: colors ? colors.primary : Style.fallbackAccent
                    }
                }

                ColumnLayout {
                    id: contentLayout
                    width: contentFlick.width - Style.paddingXLarge * 2
                    x: Style.paddingXLarge
                    y: Style.paddingMedium
                    spacing: Style.spacingMedium

                    // Effect bootstrap status (see main.qml bootstrapEffect).
                    Text {
                        Layout.fillWidth: true
                        visible: root.buildStatus.length > 0
                        text: root.buildStatus
                        color: colors ? colors.tertiary : "#8bceff"
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontCaption
                        wrapMode: Text.WordWrap
                    }

                    // ---- Enable -------------------------------------------------
                    RowCard {
                        Layout.fillWidth: true
                        colors: root.colors
                        SwitchRow {
                            anchors.fill: parent
                            text: qsTr("Enable Web Cursor")
                            subtext: qsTr("Render the selected HTML/CSS cursor through KWin")
                            checked: root.config ? root.config.enabled : false
                            colors: root.colors
                            onToggled: on => { on ? root.manager.enable() : root.manager.disable() }
                        }
                    }

                    // ---- Theme picker -------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.spacingLarge

                        SectionHeader {
                            Layout.fillWidth: true
                            text: qsTr("Cursor Theme")
                            colors: root.colors
                            first: true
                        }
                        IconButton {
                            glyph: "\uF0415" // mdi-plus
                            colors: root.colors
                            tonal: true
                            tip: qsTr("Install theme from folder")
                            onClicked: themeUploadDialog.open()
                        }
                    }

                    RowCard {
                        Layout.fillWidth: true
                        colors: root.colors
                        RowLayout {
                            anchors.fill: parent
                            spacing: Style.spacingLarge

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: qsTr("Current theme")
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.fontCaption
                                    color: colors ? colors.surfaceVariantText : "#b0b0b0"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.config ? root.config.selectTheme : ""
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.fontBodyLarge
                                    color: colors ? colors.surfaceText : "#e0e0e0"
                                    elide: Text.ElideRight
                                }
                            }
                            IconButton {
                                glyph: "\uF0450" // mdi-refresh
                                colors: root.colors
                                tip: qsTr("Reload themes")
                                onClicked: root.manager.reload()
                            }
                        }
                    }

                    Repeater {
                        model: root.manager ? root.manager.themeList : []

                        delegate: RowCard {
                            required property string modelData
                            readonly property var details: root.manager.getThemeDetails(modelData)

                            Layout.fillWidth: true
                            colors: root.colors

                            RowLayout {
                                anchors.fill: parent
                                spacing: Style.spacingLarge

                                Image {
                                    readonly property real baseSize: 56
                                    Layout.preferredWidth: baseSize
                                    Layout.preferredHeight: baseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    sourceSize.width: 112
                                    sourceSize.height: 112
                                    source: details.iconPath || ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    cache: false
                                    visible: status === Image.Ready
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.fontBody
                                        color: colors ? colors.surfaceText : "#e0e0e0"
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: details.describe.length > 0
                                        text: details.describe
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.fontCaption
                                        color: colors ? colors.surfaceVariantText : "#b0b0b0"
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: qsTr("By %1 · minimum %2 × %3").arg(details.author).arg(details.minWidth).arg(details.minHeight)
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.fontTiny
                                        color: colors ? colors.surfaceVariantText : "#b0b0b0"
                                    }
                                }

                                IconButton {
                                    readonly property bool active: root.config && root.config.selectTheme === modelData
                                    glyph: active ? "\uF012C" : "\uF040A" // mdi-check / mdi-play
                                    colors: root.colors
                                    filled: active
                                    tonal: !active
                                    tip: active ? qsTr("Current theme") : qsTr("Apply")
                                    onClicked: root.manager.useTheme(modelData)
                                }
                                IconButton {
                                    glyph: "\uF0770" // mdi-folder-open
                                    colors: root.colors
                                    tip: qsTr("Open theme folder")
                                    onClicked: root.manager.openThemeFolder(modelData)
                                }
                                IconButton {
                                    visible: root.manager.isUserTheme(modelData)
                                    glyph: "\uF0226" // mdi-delete
                                    colors: root.colors
                                    tip: qsTr("Remove theme")
                                    onClicked: root.manager.removeTheme(modelData)
                                }
                            }
                        }
                    }

                    // ---- Size -----------------------------------------------------
                    SectionHeader {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.spacingLarge
                        text: qsTr("Size")
                        colors: root.colors
                    }

                    RowCard {
                        Layout.fillWidth: true
                        colors: root.colors
                        StepperRow {
                            anchors.fill: parent
                            text: qsTr("Cursor width")
                            subtext: qsTr("Render width in pixels")
                            min: 1
                            max: 1920
                            value: root.config ? root.config.width : 128
                            colors: root.colors
                            onMoved: value => {
                                root.config.width = value
                                root.manager.save()
                            }
                        }
                    }

                    RowCard {
                        Layout.fillWidth: true
                        colors: root.colors
                        StepperRow {
                            anchors.fill: parent
                            text: qsTr("Cursor height")
                            subtext: qsTr("Render height in pixels")
                            min: 1
                            max: 1080
                            value: root.config ? root.config.height : 128
                            colors: root.colors
                            onMoved: value => {
                                root.config.height = value
                                root.manager.save()
                            }
                        }
                    }

                    // ---- Ignored applications --------------------------------------
                    SectionHeader {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.spacingLarge
                        text: qsTr("Ignored Applications")
                        colors: root.colors
                    }

                    RowCard {
                        Layout.fillWidth: true
                        colors: root.colors
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Style.spacingSmall

                            Repeater {
                                model: root.config ? root.config.blacklist : []

                                delegate: RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        font.family: Style.fontFamily
                                        font.pixelSize: Style.fontBody
                                        color: colors ? colors.surfaceText : "#e0e0e0"
                                        elide: Text.ElideRight
                                    }
                                    IconButton {
                                        glyph: "\uF0156" // mdi-close
                                        colors: root.colors
                                        size: 24
                                        tip: qsTr("Remove")
                                        onClicked: root.manager.removeBlacklist(modelData)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.spacingSmall

                                TextField {
                                    id: blacklistInput
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Window class or application name")
                                    color: colors ? colors.surfaceText : "#e0e0e0"
                                    placeholderTextColor: colors ? colors.surfaceVariantText : "#b0b0b0"
                                    selectByMouse: true
                                    font.family: Style.fontFamily
                                    font.pixelSize: Style.fontBody
                                    background: Rectangle {
                                        radius: Style.radiusMedium
                                        color: colors ? colors.surface : "transparent"
                                        border.color: colors ? colors.outline : "transparent"
                                        border.width: 1
                                    }
                                    onAccepted: addBlacklistFromInput()
                                }
                                IconButton {
                                    glyph: "\uF0415" // mdi-plus
                                    colors: root.colors
                                    tonal: true
                                    tip: qsTr("Add to ignore list")
                                    onClicked: addBlacklistFromInput()
                                }
                            }
                        }
                    }

                    // ---- Status -----------------------------------------------------
                    Text {
                        Layout.fillWidth: true
                        visible: root.manager && root.manager.statusMessage.length > 0
                        text: root.manager ? root.manager.statusMessage : ""
                        color: colors ? colors.surfaceVariantText : "#b0b0b0"
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontCaption
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    FolderDialog {
        id: themeUploadDialog
        title: qsTr("Choose a cursor theme folder")
        acceptLabel: qsTr("Install")
        onAccepted: {
            const raw = selectedFolder
            const folder = typeof raw === "string"
                ? raw
                : raw.toString().replace(/^file:\/\//, "")
            root.manager.uploadTheme(folder, "")
        }
    }

    function addBlacklistFromInput() {
        const text = blacklistInput.text
        root.manager.addBlacklist(text)
        blacklistInput.clear()
        blacklistInput.text = ""
    }
}
