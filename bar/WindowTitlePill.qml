import QtQuick
import Quickshell
import ".."

Pill {
    id: pill
    property real maxWidth: Theme.windowTitleMaxWidth
    property string lastTitle: ""
    readonly property string title: NiriService.windowTitle || ((OverlayController.launcherOpen || OverlayController.launcherBusy) ? lastTitle : "")
    accent: "#4d7c9cff"
    visible: title.length > 0 && maxWidth > 54
    implicitWidth: Math.min(maxWidth, titleLabel.implicitWidth + 54)
    clip: true
    Component.onCompleted: lastTitle = NiriService.windowTitle
    Connections {
        target: NiriService
        function onWindowTitleChanged() {
            if (NiriService.windowTitle)
                pill.lastTitle = NiriService.windowTitle
        }
    }
    IconLabel {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf2d0"
        color: "#c7d2ff"
    }
    IconLabel {
        id: titleLabel
        x: 40
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, pill.width - 54)
        text: pill.title
        elide: Text.ElideRight
        color: "#c7d2ff"
    }
}
