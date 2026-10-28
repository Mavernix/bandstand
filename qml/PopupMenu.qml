// the shell's menu box at a point, with a click-catcher behind it that dismisses it

import QtQuick
import "shell" as Shell

Item {
    id: popup

    // the desktop settings object, MenuBox reads its looks from it
    required property var settings

    // items in shell/MenuBox.qml's shape, see MenuItems.js
    property var items: []
    // top left corner in window coordinates
    property point openAt: Qt.point(0, 0)
    property bool opened: false

    signal chosen(int id)
    signal dismissed()

    anchors.fill: parent
    visible: opened

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: popup.dismissed()
    }

    Shell.MenuBox {
        settings: popup.settings
        items: popup.items
        // kept inside the window
        x: Math.max(0, Math.min(popup.openAt.x, popup.width - width))
        y: Math.max(0, Math.min(popup.openAt.y, popup.height - height))
        onChosen: id => popup.chosen(id)
    }
}
