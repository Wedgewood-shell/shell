import QtQuick
import Quickshell
import "../.."

// Base state while a Helium window is focused: the address bar's URL.
Item {
    id: view
    property bool active: IslandController.islandMode === "helium"
    implicitWidth: Theme.islandHeliumWidth - 36
    implicitHeight: 42
    readonly property string url: HeliumService.url
    readonly property bool secure: url.startsWith("https://")
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
    IconLabel {
        id: lead
        anchors.verticalCenter: parent.verticalCenter
        x: 18
        text: view.secure ? Theme.cp(0xF033E) : Theme.cp(0xF059F)
        color: view.secure ? Theme.highlight : Theme.muted
        font.pixelSize: 14
    }
    Rectangle {
        id: recDot
        visible: CaptureService.recording
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 18
        width: 9
        height: 9
        radius: 5
        color: "#ff5c5c"
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: recDot.visible ? recDot.left : parent.right
        anchors.rightMargin: 18
        elide: Text.ElideRight
        text: view.url
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
}
