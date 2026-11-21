import QtQuick
import Quickshell
import "../.."

Row {
    id: briRow
    property bool active: IslandController.islandMode === "brightness"
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
        text: Theme.cp(BrightnessService.briFrac < 0.34 ? 0xF00DE : BrightnessService.briFrac < 0.67 ? 0xF00DF :
                                                                                                       0xF00E0)

        color: Theme.warning
        font.family: Theme.fontFamily
        font.pixelSize: 17
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
            width: parent.width * BrightnessService.briFrac
            color: Theme.warning
            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: Math.round(BrightnessService.briFrac * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.features: Theme.tabularFigures
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
}
