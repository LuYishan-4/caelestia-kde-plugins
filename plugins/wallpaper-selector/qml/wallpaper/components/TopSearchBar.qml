import QtQuick
import QtQuick.Controls
import Caelestia
import Caelestia.Config as ShellConfig
import qs.components.controls
import qs.services.api
import qs.components

StyledRect {
    id: root

    property var colors
    property alias text: searchInput.text

    signal escapePressed()
    signal accepted()

    color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.95)
    border.width: 1
    border.color: colors.outline
    radius: ShellConfig.Tokens.rounding.full
    implicitWidth: searchIcon.implicitWidth + searchInput.width + ShellConfig.Tokens.padding.medium * 2 + ShellConfig.Tokens.spacing.small
    implicitHeight: searchInput.implicitHeight

    MaterialIcon {
        id: searchIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: ShellConfig.Tokens.padding.medium
        text: "search"
        color: colors.surfaceText
    }

    StyledTextField {
        id: searchInput
        anchors.left: searchIcon.right
        anchors.leftMargin: ShellConfig.Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        width: 250
        placeholderText: qsTr("Search wallpapers...")
        color: colors.surfaceText
        placeholderTextColor: Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6)
        
        topPadding: ShellConfig.Tokens.padding.medium
        bottomPadding: ShellConfig.Tokens.padding.medium

        onTextChanged: CaelestiaApi.visuals.wallpaper.searchText = text
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
    }

    function forceSearchFocus() {
        searchInput.forceActiveFocus()
    }
    
    function appendSearchText(newText) {
        searchInput.text += newText
        forceSearchFocus()
    }
    
    function backspaceSearchText() {
        if (searchInput.text.length > 0) {
            searchInput.text = searchInput.text.slice(0, -1)
        }
    }
}
