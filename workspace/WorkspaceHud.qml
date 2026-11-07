import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// A moving viewport over a persistent workspace/window scene; never takes input.
PanelWindow {
    id: hud

    property bool open: false
    property string kind: "switch"
    property int ws: -1
    property int fromWs: -1
    property int moveId: -1
    property var snap: ({})
    property bool useSnap: false
    readonly property real closedWidth: OverlayController.islandWidths[screen ? screen.name : WorkspaceController.hudScreen] ?? 300
    readonly property int motionDuration: 400
    readonly property bool isMove: kind === "move"
    readonly property real workspaceHeight: map.rowHeight
    readonly property int viewportHeight: Math.ceil(workspaceHeight * 1.5)
    readonly property int titleWidth: 180
    readonly property int mapWidth: 396
    readonly property int expandedWidth: 16 + titleWidth + 12 + mapWidth + 16
    readonly property int expandedHeight: Math.max(Theme.barHeight, viewportHeight) + 24

    screen: Quickshell.screens.find(s => s.name === WorkspaceController.hudScreen) ?? Quickshell.screens[0]
    visible: open || handoff.retained
    color: "transparent"
    anchors.top: true
    margins.top: Theme.topMargin
    // Reserve the same surface envelope as the launcher. Following the pill's
    // animated width forces Wayland buffer/configure churn on every frame.
    implicitWidth: 720
    // Derived from the resting content size, never from the animated pill.
    implicitHeight: expandedHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-hud"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: WorkspaceController
        function onHudSerialChanged() {
            hud.begin()
        }
    }
    Connections {
        target: OverlayController
        function onDismissHud() {
            linger.stop()
            hud.open = false
            hud.useSnap = false
        }
    }

    function begin() {
        const wasOpen = open
        kind = WorkspaceController.hudKind
        ws = WorkspaceController.hudWs
        fromWs = WorkspaceController.hudFrom
        moveId = WorkspaceController.hudWinId
        snap = WorkspaceController.hudSnap
        useSnap = !wasOpen && kind !== "switch" && Object.keys(snap).length > 0
        if (!wasOpen) {
            // Prime the old geometry while hidden. Release it in this same turn,
            // so tile movement, camera movement and the pill morph start together.
            const originId = kind === "focus" ? WorkspaceController.hudFromWinId : moveId
            map.panTo(fromWs >= 0 ? fromWs : ws, originId, false)
        }
        open = true
        useSnap = false
        map.panTo(ws, moveId)
        linger.interval = isMove ? 2400 : 1600
        linger.restart()
    }

    Timer {
        id: linger
        onTriggered: {
            hud.open = false
            hud.useSnap = false
        }
    }
    IslandMorph {
        id: geometry
        expanded: hud.open
        collapsedWidth: hud.closedWidth
        expandedWidth: hud.expandedWidth
        expandedHeight: hud.expandedHeight
        duration: hud.motionDuration
        openingEasing: Easing.InOutCubic
    }
    IslandHandoff {
        id: handoff
        surface: hud
        expanded: hud.open
        currentHeight: pill.height
        expandedHeight: hud.expandedHeight
        morphing: geometry.running
        onCoveredChanged: WorkspaceController.hudBusy = covered
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        width: geometry.width
        height: geometry.height
        radius: geometry.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        opacity: 1
        Island {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: Theme.barHeight
            color: "transparent"
            border.width: 0
            opacity: handoff.islandOpacity
            Behavior on opacity {
                enabled: hud.open
                NumberAnimation {
                    duration: 120
                }
            }
        }

        Item {
            id: content
            width: hud.expandedWidth
            height: hud.expandedHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: handoff.contentOpacity
            Behavior on opacity {
                enabled: hud.open
                NumberAnimation {
                    duration: 120
                }
            }

            Column {
                id: titlebar
                x: 16
                width: hud.titleWidth
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Row {
                    width: parent.width
                    height: Math.max(titleIcon.implicitHeight, titleText.implicitHeight)
                    spacing: 10
                    Text {
                        id: titleIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Theme.highlight
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }
                    Text {
                        id: titleText
                        anchors.verticalCenter: parent.verticalCenter
                        width: titlebar.width - titleIcon.implicitWidth - 10
                        elide: Text.ElideRight
                        text: hud.isMove ? NiriService.moveLabel(hud.fromWs, hud.ws) : NiriService.wsLabel(hud.ws)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }
                Row {
                    id: dots
                    x: titleIcon.implicitWidth + 10
                    height: 6
                    spacing: 5
                    Repeater {
                        model: NiriService.wsOnOutput(WorkspaceController.hudScreen)
                        delegate: Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: modelData.id === hud.ws ? 18 : 6
                            height: 6
                            radius: 3
                            color: modelData.id === hud.ws ? Theme.highlight : "#3a4468"
                            Behavior on width {
                                NumberAnimation {
                                    duration: 220
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }
                }
            }
            WorkspaceMap {
                id: map
                x: 16 + hud.titleWidth + 12
                y: 12
                // Keep the viewport's size fixed during the pill's reveal, so only
                // clipping changes; the world does not resize with the animation.
                width: hud.mapWidth
                height: hud.viewportHeight
                outputName: WorkspaceController.hudScreen
                wins: hud.useSnap ? hud.snap : NiriService.windows
                activeWs: hud.ws
                referenceHeight: hud.screen ? hud.screen.height : 960
                animateChanges: hud.open
                panDuration: hud.motionDuration
            }
        }
    }
}
