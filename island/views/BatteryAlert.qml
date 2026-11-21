import QtQuick
import Quickshell
import "../.."

Row {
    id: batRow
    property bool active: IslandController.islandMode === "battery"
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

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BatteryService.onBat ? BatteryService.batteryIcon() : "\uf240"
        color: BatteryService.onBat ? (BatteryService.battery <= 15 ? Theme.danger : Theme.text) : Theme.success
        font.family: Theme.fontFamily
        font.pixelSize: 17
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !BatteryService.onBat
        text: "\uf0e7"
        color: Theme.warning
        font.family: Theme.fontFamily
        font.pixelSize: 16
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        height: 6
        radius: 3
        color: Theme.raised
        Rectangle {
            height: parent.height
            radius: 3
            width: parent.width * BatteryService.battery / 100
            color: BatteryService.onBat ? (BatteryService.battery <= 15 ? Theme.danger : BatteryService.battery <= 30
                                                                          ? Theme.warning : Theme.highlight) :
                                          Theme.success
            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BatteryService.battery + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "·  " + (BatteryService.onBat ? "On battery" : "Plugged in")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
}
