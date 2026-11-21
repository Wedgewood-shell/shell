import QtQuick
import Quickshell
import "../.."

Row {
    id: netRow
    property bool active: IslandController.islandMode === "network"
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

    readonly property bool up: NetworkService.netEvKind !== "none"

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: NetworkService.netGlyph(NetworkService.netEvHotspot && NetworkService.netEvKind !== "none" ? "hotspot" :
                                                                                                           NetworkService.netEvKind,
                                      NetworkService.netEvSignal)
        color: netRow.up ? Theme.highlight : Theme.danger
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
        width: Math.min(implicitWidth, 260)
        elide: Text.ElideRight
        text: netRow.up ? NetworkService.netEvName : (NetworkService.netEvPrev ? NetworkService.netEvPrev : "Network")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: netRow.up ? (NetworkService.netEvHotspot ? "·  Mobile hotspot" : "·  Connected") : "·  Disconnected"
        color: netRow.up ? Theme.success : Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: NetworkService.netEvKind === "wifi"
        text: NetworkService.netEvSignal + "%"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
}
