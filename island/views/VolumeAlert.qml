import QtQuick
import Quickshell
import "../.."

Row {
    id: volRow
    property bool active: IslandController.islandMode === "volume"
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

    VolumeIcon {
        anchors.verticalCenter: parent.verticalCenter
        s: 1.15
        kind: AudioService.outputKind
        volume: AudioService.volume
        muted: AudioService.muted
        base: Theme.text
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
            width: parent.width * Math.min(1, AudioService.volume)
            color: AudioService.muted ? Theme.muted : Theme.highlight
            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: AudioService.muted ? "muted" : Math.round(AudioService.volume * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.features: Theme.tabularFigures
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 210)
        elide: Text.ElideRight
        text: "·  " + AudioService.sinkName
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
}
