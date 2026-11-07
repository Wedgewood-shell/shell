import QtQuick
import Quickshell
import ".."
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: tray
    property var window
    // tray ids to hide (the Wi-Fi menu replaces nm-applet)
    readonly property var hiddenIds: ["nm-applet"]
    spacing: 8

    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: entry
            required property var modelData
            visible: tray.hiddenIds.indexOf(modelData.id) < 0
            width: 20
            height: 20
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            IconImage {
                anchors.fill: parent
                source: entry.modelData.icon
            }
            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.window: tray.window
                anchor.item: entry
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu)
                        entry.modelData.activate()
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate()
                    else if (entry.modelData.hasMenu)
                        menu.open()
                }
            }
        }
    }
}
