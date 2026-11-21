import QtQuick
import Quickshell
import ".."

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // Compact while a window spans this output's width: the floating pills become
    // a flush, full-width strip with a background, and modules shrink.
    readonly property bool compact: NiriService.spansOutput(modelData.name, modelData.width)
    property real c: compact ? 1 : 0
    Behavior on c {
        NumberAnimation {
            duration: Theme.compactDuration
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real moduleScale: 1 - (1 - Theme.compactScale) * c
    readonly property real stripY: Theme.topMargin * (1 - c)
    readonly property real stripH: Theme.barHeight + (Theme.compactBarHeight - Theme.barHeight) * c
    readonly property real sidePad: 16 + (Theme.compactPadding - 16) * c

    // The surface is flush with the screen edges; the resting margins are drawn inside it.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.topMargin + Theme.barHeight
    // Switches at once (windows resize once, not every frame).
    exclusiveZone: compact ? Theme.compactBarHeight : Theme.topMargin + 50
    color: "transparent"
    mask: Region {
        item: hitArea
    }
    Item {
        id: hitArea
        y: bar.stripY
        width: parent.width
        height: bar.stripH
    }

    Rectangle {
        id: background
        width: parent.width
        height: bar.stripY + bar.stripH
        color: Theme.compactBackground
        opacity: bar.c
        visible: opacity > 0
    }

    Item {
        id: content
        x: bar.sidePad
        y: bar.stripY
        width: parent.width - 2 * bar.sidePad
        height: bar.stripH

        // Left: focused window / switcher lives in WindowSwitcher (its own surface).

        // ---- center: dynamic island ----
        Island {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            scale: bar.moduleScale
            opacity: (OverlayController.launcherBusy && OverlayController.launcherScreen === bar.modelData.name) ? 0 : 1
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
            anchors.verticalCenter: parent.verticalCenter
            scale: bar.moduleScale
            transformOrigin: Item.Right
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
                        font.features: Theme.tabularFigures
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
