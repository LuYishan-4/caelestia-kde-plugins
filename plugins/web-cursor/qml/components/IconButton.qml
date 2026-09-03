// Icon button with a ligature/icon-font glyph. `glyph` should be a unicode
// codepoint from the shell's icon font (see style.qml fontFamilyIcons /
// fontFamilyNerdIcons).
import QtQuick
import ".."

Rectangle {
    id: root

    signal clicked()

    property string glyph: ""
    property string tip: ""
    property var colors: null
    property bool tonal: false
    property bool filled: false
    property bool clickEnabled: true
    property int size: 30
    property string iconFont: Style.fontFamilyIcons

    readonly property color _accent: colors ? colors.primary : Style.fallbackAccent
    readonly property color _onAccent: colors ? colors.primaryText : "#ffffff"
    readonly property color _hoverFill: colors ? colors.surfaceVariant : "#33ffffff"
    readonly property color _glyphColor: !root.clickEnabled ? (colors ? colors.outline : "#808080")
        : (filled ? _onAccent : (tonal ? (colors ? colors.primary : _accent) : (colors ? colors.surfaceText : "#e0e0e0")))

    width: size
    height: size
    radius: 10
    opacity: clickEnabled ? 1 : 0.4
    color: filled ? _accent : (hoverArea.containsMouse ? _hoverFill : "transparent")
    Behavior on color { ColorAnimation { duration: Style.animFast } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: root.iconFont
        font.pixelSize: Math.round(root.size * 0.55)
        color: root._glyphColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (root.clickEnabled) root.clicked() }
    }

    StyledToolTip {
        text: root.tip
        visible: hoverArea.containsMouse && root.tip.length > 0
        delay: Style.tooltipDelay
        colors: root.colors
    }
}
