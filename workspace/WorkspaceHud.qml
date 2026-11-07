import QtQuick
import Quickshell
import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Workspace "island" state: shows the workspace you switched to with a map of its windows, flies a window's
// icon between two workspaces when it is moved, and slides tiles when columns are shifted.
// It never takes keyboard focus or input.
PanelWindow {
    id: hud

    property bool open: false
    property string kind: "switch"             // "switch" | "move" | "shift"
    property int ws: -1
    property int fromWs: -1
    property int moveId: -1
    property var snap: ({})
    property bool useSnap: false               // draw the "before" layout first so the change animates
    property int dir: 0
    property int phase: 0                      // move: 0 = before, 1 = flying, 2 = landed

    property bool showContent: false
    Timer {
        id: contentTimer
        interval: 150
        onTriggered: hud.showContent = hud.open
    }
    onOpenChanged: {
        if (open)
            contentTimer.restart()
        else {
            contentTimer.stop()
            showContent = false
        }
    }

    readonly property bool isMove: kind === "move"
    readonly property bool srcIsTop: NiriService.wsIdx(fromWs) < NiriService.wsIdx(ws)

    screen: Quickshell.screens.find(s => s.name === WorkspaceController.hudScreen) ?? Quickshell.screens[0]
    visible: open || WorkspaceController.hudBusy
    color: "transparent"
    anchors.top: true
    margins.top: 8
    implicitWidth: 460
    implicitHeight: 360
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-hud"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}                            // click-through

    // ---- lifecycle ----
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
            stepTimer.stop()
            settleTimer.stop()
            contentTimer.stop()
            flyAnim.stop()
            hud.open = false
            hud.showContent = false
            WorkspaceController.hudBusy = false
        }
    }

    function begin() {
        kind = WorkspaceController.hudKind
        ws = WorkspaceController.hudWs
        fromWs = WorkspaceController.hudFrom
        moveId = WorkspaceController.hudWinId
        snap = WorkspaceController.hudSnap
        dir = WorkspaceController.hudDir
        phase = 0
        useSnap = kind !== "switch"
        flyAnim.stop()
        const wasOpen = open
        WorkspaceController.hudBusy = true
        settleTimer.stop()
        open = true
        linger.interval = kind === "switch" ? 1500 : 2400
        linger.restart()
        if (kind === "switch")
            slide.restart()
        else {
            stepTimer.interval = wasOpen ? 90 : 480
            stepTimer.restart()
        }
    }

    Timer {
        id: linger
        onTriggered: {
            hud.open = false
            settleTimer.restart()
        }
    }
    Timer {
        id: settleTimer
        interval: 360
        onTriggered: WorkspaceController.hudBusy = false
    }
    Timer {
        id: stepTimer
        onTriggered: {
            if (hud.isMove)
                hud.startFlight()
            else
                hud.useSnap = false
            // shift: now show the real layout, tiles slide into place
        }
    }

    // ---- a moved window's icon flying from its old workspace to the new one ----
    property real fx: 0
    property real fy: 0
    property real fw: 0
    property real fh: 0
    property string flyApp: ""
    property real tx: 0
    property real ty: 0
    property real tw: 0
    property real th: 0

    function startFlight() {
        const sm = srcIsTop ? mapTop : mapBottom
        const dm = srcIsTop ? mapBottom : mapTop
        const fr = sm.rectOf(moveId), tr = dm.rectOf(moveId)
        useSnap = false
        // the source workspace reflows without the window
        if (!fr || !tr) {
            phase = 2
            return
        }
        const fp = pill.mapFromItem(sm, fr.x, fr.y), tp = pill.mapFromItem(dm, tr.x, tr.y)
        flyApp = dm.appOf(moveId)
        fx = fp.x
        fy = fp.y
        fw = fr.width
        fh = fr.height
        tx = tp.x
        ty = tp.y
        tw = tr.width
        th = tr.height
        phase = 1
        flyAnim.restart()
    }

    ParallelAnimation {
        id: flyAnim
        NumberAnimation {
            target: flyer
            property: "x"
            from: hud.fx
            to: hud.tx
            duration: 560
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: flyer
            property: "y"
            from: hud.fy
            to: hud.ty
            duration: 560
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: flyer
            property: "width"
            from: hud.fw
            to: hud.tw
            duration: 560
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: flyer
            property: "height"
            from: hud.fh
            to: hud.th
            duration: 560
            easing.type: Easing.InOutCubic
        }
        onFinished: hud.phase = 2
    }

    // ---- the pill ----
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        clip: true
        radius: hud.open ? 18 : 12
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        readonly property real openW: 380
        readonly property real openH: hud.isMove ? 306 : 198
        readonly property real islandW: OverlayController.islandWidths[WorkspaceController.hudScreen] !== undefined
                                        ? OverlayController.islandWidths[WorkspaceController.hudScreen] : 300

        width: hud.open ? openW : islandW
        height: hud.open ? openH : 42
        opacity: WorkspaceController.hudBusy ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: 400
                easing.type: hud.open ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 0.9
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 400
                easing.type: hud.open ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 0.9
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 300
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        Item {
            id: content
            anchors.fill: parent
            opacity: hud.showContent ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: hud.showContent ? 220 : 90
                }
            }

            // header: workspace name (+ where the window came from) and a dot per workspace on this output
            Row {
                x: 20
                y: 0
                height: 42
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.highlight
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hud.isMove ? NiriService.moveLabel(hud.fromWs, hud.ws) : NiriService.wsLabel(hud.ws)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                y: 0
                height: 42
                spacing: 5
                Repeater {
                    model: NiriService.wsOnOutput(WorkspaceController.hudScreen)
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool here: modelData.id === hud.ws || (hud.isMove && modelData.id
                                                                                 === hud.fromWs)
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        width: modelData.id === hud.ws ? 18 : 6
                        radius: 3
                        color: modelData.id === hud.ws ? Theme.highlight : here ? "#5b6ca8" : "#3a4468"
                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
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

            Rectangle {
                x: 16
                y: 42
                width: parent.width - 32
                height: 1
                color: "#2b3350"
            }

            // switch / shift: a single workspace map
            Item {
                id: slideBox
                visible: !hud.isMove
                x: 20
                y: 52
                width: 340
                height: 130
                property real yOff: 0
                transform: Translate {
                    y: slideBox.yOff
                }

                WorkspaceMap {
                    id: mapSingle
                    wsId: hud.ws
                    wins: hud.useSnap ? hud.snap : NiriService.windows
                    boxW: 340
                    boxH: 130
                }
            }
            ParallelAnimation {
                id: slide
                NumberAnimation {
                    target: slideBox
                    property: "yOff"
                    from: hud.dir * 30
                    to: 0
                    duration: 420
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: slideBox
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 280
                }
            }

            // move: source and destination workspaces stacked in screen order
            Item {
                visible: hud.isMove
                anchors.fill: parent

                Text {
                    x: 22
                    y: 50
                    text: NiriService.wsLabel(hud.srcIsTop ? hud.fromWs : hud.ws)
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                WorkspaceMap {
                    id: mapTop
                    x: 20
                    y: 68
                    wsId: hud.srcIsTop ? hud.fromWs : hud.ws
                    wins: (hud.srcIsTop && hud.useSnap) ? hud.snap : NiriService.windows
                    hiddenId: hud.srcIsTop ? (hud.phase >= 1 ? hud.moveId : -1) : (hud.phase < 2 ? hud.moveId : -1)
                    boxW: 340
                    boxH: 92
                }
                Text {
                    x: 22
                    y: 68 + 92 + 8
                    text: NiriService.wsLabel(hud.srcIsTop ? hud.ws : hud.fromWs)
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                WorkspaceMap {
                    id: mapBottom
                    x: 20
                    y: 68 + 92 + 26
                    wsId: hud.srcIsTop ? hud.ws : hud.fromWs
                    wins: (!hud.srcIsTop && hud.useSnap) ? hud.snap : NiriService.windows
                    hiddenId: hud.srcIsTop ? (hud.phase < 2 ? hud.moveId : -1) : (hud.phase >= 1 ? hud.moveId : -1)
                    boxW: 340
                    boxH: 92
                }
            }

            // the window travelling between the two maps
            Rectangle {
                id: flyer
                visible: hud.isMove && hud.phase === 1
                radius: 7
                color: "#2d3a60"
                border.width: 2
                border.color: Theme.highlight
                z: 10
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.max(14, Math.min(34, Math.min(flyer.width, flyer.height) * 0.5))
                    source: NiriService.iconFor(hud.flyApp)
                }
            }
        }
    }
}
