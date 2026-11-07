import QtQuick
import Quickshell
import ".."

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.topMargin
        left: 16
        right: 16
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: 50
    color: "transparent"

    // ---- left: focused window ----
    WindowTitlePill {
        anchors.left: parent.left
        maxWidth: Math.min(Theme.windowTitleMaxWidth, Math.max(0, bar.width / 2 - Theme.islandBaseWidth / 2 - 24))
    }

    // ---- center: dynamic island ----
    Island {
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: (OverlayController.launcherBusy && OverlayController.launcherScreen === bar.modelData.name) || (WorkspaceController.hudBusy && WorkspaceController.hudScreen === bar.modelData.name) ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.islandFadeDuration
            }
        }
        onImplicitWidthChanged: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
        Component.onCompleted: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
    }

    // ---- right: tray + status ----
    Row {
        anchors.right: parent.right
        spacing: 8

        Pill {
            visible: trayRow.implicitWidth > 0
            implicitWidth: trayRow.implicitWidth + 26
            Tray {
                id: trayRow
                anchors.centerIn: parent
                window: bar
            }
        }

        StatusPill {}
    }
}
