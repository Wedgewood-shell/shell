import QtQuick
import Quickshell
import "../.."

Row {
    id: btRow
    property bool active: IslandController.islandMode === "bluetooth"
    spacing: 12
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fadeDuration
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    readonly property var dev: IslandController.btDevice
    readonly property bool hasBat: !!(IslandController.btUp && dev && dev.batteryAvailable)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BluetoothService.btGlyph(btRow.dev ? btRow.dev.icon : "")
        color: IslandController.btUp ? Theme.highlight : Theme.muted
        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        font.family: Theme.fontFamily
        font.pixelSize: 18
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 240)
        elide: Text.ElideRight
        text: btRow.dev ? (btRow.dev.name || btRow.dev.deviceName) : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: IslandController.btUp ? "·  Connected" : "·  Disconnected"
        color: IslandController.btUp ? Theme.success : Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: btRow.hasBat
        spacing: 6
        Text {
            text: BatteryService.batteryGlyph(btRow.hasBat ? btRow.dev.battery : 0)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }
        Text {
            text: btRow.hasBat ? Math.round(btRow.dev.battery * 100) + "%" : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.features: Theme.tabularFigures
            font.pixelSize: 14
        }
    }
}
