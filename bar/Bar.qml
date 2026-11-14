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
        spacing: 0

        Item {
            visible: trayWrap.visible
            width: trayWrap.width + 8
            height: Theme.barHeight
            Pill {
                id: trayWrap
                color: "transparent"
                border.width: 0
                visible: trayRow.implicitWidth > 0
                implicitWidth: trayRow.implicitWidth + 26
                Tray {
                    id: trayRow
                    anchors.centerIn: parent
                    window: bar
                }
            }
        }

        StatusPill {}

        // Date/time, shown here while a non-clock base state owns the island.
        Item {
            id: clockSlot
            readonly property bool shown: IslandController.clockInBar
            property real p: shown ? 1 : 0
            Behavior on p {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }
            visible: p > 0
            height: Theme.barHeight
            width: (barClock.implicitWidth + 26 + 8) * p
            clip: true
            Pill {
                anchors.right: parent.right
                width: barClock.implicitWidth + 26
                height: parent.height
                color: "transparent"
                border.width: 0
                opacity: clockSlot.p
                Text {
                    id: barClock
                    anchors.centerIn: parent
                    text: SystemService.clockText
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
