import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."

// The window switcher's list (see core/SwitcherController.qml), drawn where the
// left module is: the module's pill grows downward into a list of windows and
// the selection follows Tab. Never takes input.
PanelWindow {
    id: sl
    required property var modelData
    screen: modelData
    readonly property string outputName: modelData.name

    readonly property bool active: SwitcherController.shown && SwitcherController.screen === outputName
    property real p: active ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: 220
            easing.type: sl.active ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    // ---- geometry ----
    readonly property int rowH: 34
    readonly property int pad: 6
    readonly property int maxRows: 9
    readonly property int iconSize: 20
    readonly property real pillH: Theme.px(Theme.barHeight, devicePixelRatio)
    readonly property real room: Math.max(0, modelData.width / 2 - 16)
    readonly property real listW: Math.min(460, room)
    readonly property int count: SwitcherController.entries.length
    readonly property int rows: Math.min(maxRows, Math.max(1, count))
    readonly property real listH: pad * 2 + rows * rowH
    readonly property real boxW: Math.round(210 + (listW - 210) * p)
    readonly property real boxH: Math.round(pillH + (listH - pillH) * p)

    BarModeFollower {
        id: mode
        output: sl.outputName
        outputWidth: sl.modelData.width
        outputHeight: sl.modelData.height
    }
    readonly property real c: mode.c

    anchors {
        top: true
        left: true
    }
    implicitWidth: Theme.surfaceSize(listW + 16 + 8, devicePixelRatio)
    implicitHeight: Theme.surfaceSize(Theme.topMargin + pad * 2 + maxRows * rowH + 8, devicePixelRatio)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: p > 0.001
    WlrLayershell.namespace: "window-switcher-list"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // Scroll (in rows) that keeps the selection in view.
    readonly property real scrollTarget: Math.max(0, Math.min(count - rows, SwitcherController.selectedIndex - (rows - 1) / 2))
    property real scroll: scrollTarget
    Behavior on scroll {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: box
        x: 16 + (Theme.compactPadding - 16) * sl.c
        y: Theme.topMargin + (Theme.compactTopFor(sl.pillH, sl.devicePixelRatio) - Theme.topMargin) * sl.c
        width: sl.boxW
        height: sl.boxH
        radius: Theme.closedRadius + (Theme.openRadius - Theme.closedRadius) * sl.p
        color: Theme.pill
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.6 * sl.p + 0.0)
        clip: true
        opacity: Math.min(1, sl.p * 3)

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: sl.pad
            clip: true
            opacity: sl.p

            // Selection highlight, gliding between rows.
            Rectangle {
                visible: SwitcherController.selectedIndex >= 0
                x: 0
                width: body.width
                height: sl.rowH
                y: (SwitcherController.selectedIndex - sl.scroll) * sl.rowH
                radius: Theme.closedRadius - 2
                color: Theme.raisedHover
                border.width: 1
                border.color: Theme.alpha(Theme.highlight, 0.75)
                Behavior on y {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Repeater {
                model: SwitcherController.entries
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: index === SwitcherController.selectedIndex
                    readonly property var entry: modelData.app_id ? DesktopEntries.heuristicLookup(modelData.app_id) : null
                    y: (index - sl.scroll) * sl.rowH
                    width: body.width
                    height: sl.rowH
                    visible: y > -sl.rowH && y < body.height

                    IconImage {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: sl.iconSize
                        source: NiriService.windowIcon(row.modelData)
                    }
                    Text {
                        id: appName
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.3)
                        text: row.entry ? row.entry.name : (row.modelData.app_id || "")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
                    Text {
                        x: 10 + sl.iconSize + 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, appName.x - 10 - x)
                        text: row.modelData.title || row.modelData.app_id || ""
                        color: row.current ? Theme.text : Theme.alpha(Theme.text, 0.75)
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
