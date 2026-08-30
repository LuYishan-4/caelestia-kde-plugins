import QtQuick
import QtQml
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData

    // Directory holding the sprite frames. The default points at the frames
    // bundled with this plugin (resolved relative to this folder). Override
    // with a "root:/..." path, a "~/..." path, or an absolute path.
    property string spritePath: "sprites/"
    // Number of cats on this screen.
    property int petCount: 1

    screen: modelData
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    function shellBase() {
        if (typeof Quickshell.shellDir === "string" && Quickshell.shellDir)
            return Quickshell.shellDir;
        if (typeof Quickshell.configDir === "string" && Quickshell.configDir)
            return Quickshell.configDir;
        return "";
    }

    function resolveSpriteDir() {
        let dir = spritePath;
        if (dir.startsWith("root:/")) {
            dir = shellBase() + "/" + dir.substring("root:/".length);
        } else if (dir.startsWith("~/")) {
            dir = (Quickshell.env("HOME") || "") + dir.substring(1);
        }
        // Absolute filesystem paths become file URLs; relative paths stay
        // relative so QtQuick.Image resolves them against this plugin folder.
        if (dir.startsWith("/"))
            dir = "file://" + dir;
        if (dir && !dir.endsWith("/"))
            dir += "/";
        return dir;
    }

    readonly property string spriteDir: resolveSpriteDir()

    Item {
        id: spriteContainer
        anchors.fill: parent

        Repeater {
            id: spriteRepeater
            model: root.petCount > 0 ? root.petCount : 1

            ShimejiSprite {
                screenSize: Qt.size(root.screen.width, root.screen.height)
                spriteDir: root.spriteDir
            }
        }
    }

    Instantiator {
        id: spriteRegions
        model: spriteRepeater.count

        delegate: Region {
            item: spriteRepeater.itemAt(index)
        }
    }

    mask: Region {
        regions: {
            let arr = [];
            for (let i = 0; i < spriteRegions.count; i++) {
                let obj = spriteRegions.objectAt(i);
                if (obj)
                    arr.push(obj);
            }
            return arr;
        }
    }
}
