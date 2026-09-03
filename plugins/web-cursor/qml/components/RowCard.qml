// Rounded surface container for a single setting row / group (the visual
// counterpart of the shell's "ConnectedRect").
//
// Put exactly one child inside; it is inset by `padding` and the card sizes
// itself from the child's implicit height so the surrounding ColumnLayout can
// lay out without explicit heights.
import QtQuick
import ".."

Rectangle {
    id: root

    default property alias content: contentItem.data
    property var colors: null

    readonly property int padding: Style.paddingLarge

    implicitHeight: (contentItem.data.length > 0
        ? contentItem.data[0].implicitHeight : 0) + padding * 2
    radius: Style.radiusXLarge
    color: colors ? colors.surface : "#00000000"
    border.color: colors ? colors.outline : "transparent"
    border.width: Style.borderThin * 0.5

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
