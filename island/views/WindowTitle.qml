import QtQuick
import Quickshell
import "../.."

Item {
    id: view
    property bool active: IslandController.islandMode === "window"
    implicitWidth: titleText.width + (CaptureService.recording ? 72 : 0)
    implicitHeight: 42
    // base state: window title (with a recording indicator while capturing)
    Row {
        id: recBadge
        visible: CaptureService.recording
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 18
        spacing: 8
        opacity: (!view.active) ? 0 : 1
        Rectangle {
            id: recDot
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 5
            color: "#ff5c5c"
            SequentialAnimation on opacity {
                running: CaptureService.recording
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.25
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(new Date(0, 0, 0, 0, Math.floor(CaptureService.recSecs / 60) % 60,
                                         CaptureService.recSecs % 60), "mm:ss")
            color: "#ff9a9a"
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    Text {
        id: titleText
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: CaptureService.recording ? 36 : 0
        Behavior on anchors.horizontalCenterOffset {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        width: Math.min(implicitWidth, 560)
        elide: Text.ElideRight
        text: NiriService.windowTitle
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
        opacity: (!view.active) ? 0 : 1
        scale: (!view.active) ? 0.92 : 1
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
    }
}
