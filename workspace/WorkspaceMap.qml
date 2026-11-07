import QtQuick
import Quickshell
import ".."
import QtQuick
import Quickshell.Widgets

// A workspace drawn as its window columns: one rounded tile per window with the app icon centred in it.
// Tiles are keyed by window id, so when a window moves inside the workspace its tile slides there.
Item {
    id: map

    property int wsId: -1
    property var wins: NiriService.windows       // swap in a snapshot to show an older layout
    property int hiddenId: -1                  // window whose tile is drawn elsewhere (flying)
    property real boxW: 320
    property real boxH: 120

    width: boxW
    height: boxH

    readonly property var layout: NiriService.computeLayout(wsId, wins)
    readonly property real s: layout.W > 0 ? Math.min(boxW / layout.W, boxH / layout.H) : 1
    readonly property real offX: (boxW - layout.W * s) / 2
    readonly property real offY: (boxH - layout.H * s) / 2

    // The set of delegates only changes when windows come or go, so moved windows keep their delegate (and animate).
    property var ids: []
    function syncIds() {
        const n = layout.tiles.map(t => t.id).sort((a, b) => a - b)
        if (n.join(",") !== ids.join(","))
            ids = n
    }
    onLayoutChanged: syncIds()
    Component.onCompleted: syncIds()

    function rectOf(id) {
        const t = layout.tiles.find(x => x.id === id)
        return t ? Qt.rect(offX + t.x * s, offY + t.y * s, t.w * s, t.h * s) : null
    }
    function appOf(id) {
        const t = layout.tiles.find(x => x.id === id)
        return t ? t.app_id : ""
    }

    Text {
        anchors.centerIn: parent
        visible: map.layout.tiles.length === 0
        text: "Empty workspace"
        color: "#6d7694"
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Repeater {
        model: map.ids
        delegate: Rectangle {
            id: tileRect
            required property int modelData
            readonly property var tile: map.layout.tiles.find(t => t.id === modelData) ?? null

            visible: tile !== null
            opacity: modelData === map.hiddenId ? 0 : 1
            x: tile ? map.offX + tile.x * map.s : 0
            y: tile ? map.offY + tile.y * map.s : 0
            width: tile ? tile.w * map.s : 0
            height: tile ? tile.h * map.s : 0
            radius: 7
            color: tile && tile.focused ? "#2d3a60" : "#222a42"
            border.width: tile && tile.focused ? 2 : 1
            border.color: tile && tile.focused ? Theme.highlight : "#313a58"

            Behavior on x {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Math.max(14, Math.min(34, Math.min(tileRect.width, tileRect.height) * 0.5))
                source: tileRect.tile ? NiriService.iconFor(tileRect.tile.app_id) : ""
            }
        }
    }
}
