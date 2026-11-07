import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import ".."

// One persistent scene. Window delegates live here rather than inside workspace
// delegates, so moving a window between rows never recreates its tile.
Item {
    id: map

    property string outputName: ""
    property var wins: NiriService.windows
    property var workspaceData: NiriService.workspaces
    property int activeWs: -1
    property real referenceHeight: 960
    property real previewScale: Theme.workspacePreviewScale
    property real rowHeight: 112 * previewScale
    property real rowGap: NiriService.layoutGap * windowScale
    property int panDuration: 560
    property bool animateChanges: true
    property bool animateCamera: true
    property bool ready: false
    property real cameraX: 0
    property real cameraY: 0
    readonly property real windowScale: rowHeight / Math.max(1, referenceHeight)
    readonly property var scene: buildScene()
    readonly property int tileCount: windowIds.count
    readonly property int workspaceCount: workspaceIds.count

    function buildScene() {
        const spaces = Object.values(workspaceData).filter(w => w.output === outputName).sort((a, b) => a.idx - b.idx)
        const rows = {}, tiles = {}
        let y = 0
        for (let i = 0; i < spaces.length; i++) {
            const ws = spaces[i], layout = NiriService.computeLayout(ws.id, wins)
            const height = layout.H > 0 ? layout.H * windowScale : rowHeight
            rows[ws.id] = {
                id: ws.id,
                y: y,
                height: height,
                width: Math.max(280 * previewScale, layout.W * windowScale),
                activeId: ws.active_window_id
            }
            for (const tile of layout.tiles) {
                tiles[tile.id] = {
                    id: tile.id,
                    ws: ws.id,
                    appId: tile.app_id,
                    focused: tile.focused,
                    x: tile.x * windowScale,
                    y: y + tile.y * windowScale,
                    w: tile.w * windowScale,
                    h: tile.h * windowScale
                }
            }
            y += height + rowGap
        }
        return {
            rows: rows,
            tiles: tiles
        }
    }

    // Insert/remove only the IDs that actually changed. A focus, layout, or
    // workspace change updates bindings on the same delegates.
    function syncIds(model, ids) {
        const wanted = new Set(ids)
        for (let i = model.count - 1; i >= 0; i--)
            if (!wanted.has(model.get(i).uid))
                model.remove(i)
        const present = new Set()
        for (let i = 0; i < model.count; i++)
            present.add(model.get(i).uid)
        for (const id of ids)
            if (!present.has(id))
                model.append({
                    uid: id
                })
    }
    function syncModels() {
        syncIds(workspaceIds, Object.keys(scene.rows).map(Number))
        // Keep tiles for other outputs and temporarily unassigned/floating windows
        // alive too; only an actual window close removes their delegate.
        syncIds(windowIds, Object.keys(wins).map(Number))
    }
    onSceneChanged: syncModels()
    onWinsChanged: syncModels()
    Component.onCompleted: {
        syncModels()
        Qt.callLater(() => map.ready = true)
    }

    function focusPoint(wsId, windowId) {
        const row = scene.rows[wsId]
        if (!row)
            return null
        let tile = scene.tiles[windowId]
        if (!tile || tile.ws !== wsId)
            tile = scene.tiles[row.activeId]
        if (!tile || tile.ws !== wsId)
            tile = Object.values(scene.tiles).find(t => t.ws === wsId && t.focused) || Object.values(scene.tiles).find(t => t.ws === wsId)
        return Qt.point(tile ? tile.x + tile.w / 2 : row.width / 2, row.y + row.height / 2)
    }
    function panTo(wsId, windowId, animated) {
        const point = focusPoint(wsId, windowId)
        if (!point)
            return
        animateCamera = animated !== false
        cameraX = point.x
        cameraY = point.y
        animateCamera = true
    }
    function tileItem(id) {
        for (let i = 0; i < tileRepeater.count; i++) {
            const item = tileRepeater.itemAt(i)
            if (item && item.uid === id)
                return item
        }
        return null
    }

    Behavior on cameraX {
        enabled: map.ready && map.animateCamera
        NumberAnimation {
            duration: map.panDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on cameraY {
        enabled: map.ready && map.animateCamera
        NumberAnimation {
            duration: map.panDuration
            easing.type: Easing.InOutCubic
        }
    }

    ListModel {
        id: workspaceIds
    }
    ListModel {
        id: windowIds
    }

    // Multiply horizontal and vertical alpha ramps into one reusable mask.
    Canvas {
        id: edgeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available)
            requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const horizontal = ctx.createLinearGradient(0, 0, width, 0)
            horizontal.addColorStop(0, "transparent")
            horizontal.addColorStop(0.10, "white")
            horizontal.addColorStop(0.90, "white")
            horizontal.addColorStop(1, "transparent")
            ctx.fillStyle = horizontal
            ctx.fillRect(0, 0, width, height)
            ctx.globalCompositeOperation = "destination-in"
            const vertical = ctx.createLinearGradient(0, 0, 0, height)
            vertical.addColorStop(0, "transparent")
            vertical.addColorStop(0.15, "white")
            vertical.addColorStop(0.85, "white")
            vertical.addColorStop(1, "transparent")
            ctx.fillStyle = vertical
            ctx.fillRect(0, 0, width, height)
        }
    }

    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: edgeMask
        }
        Item {
            id: world
            x: viewport.width / 2 - map.cameraX
            y: viewport.height / 2 - map.cameraY

            Repeater {
                model: workspaceIds
                delegate: Item {
                    id: workspaceRow
                    required property int uid
                    readonly property var row: map.scene.rows[uid] || null
                    property bool positioned: false
                    Component.onCompleted: Qt.callLater(() => positioned = true)
                    visible: row !== null
                    x: 0
                    y: row ? row.y : 0
                    width: row ? row.width : 0
                    height: row ? row.height : 0
                    Behavior on y {
                        enabled: map.ready && map.animateChanges && workspaceRow.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on width {
                        enabled: map.ready && map.animateChanges && workspaceRow.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !Object.values(map.scene.tiles).some(t => t.ws === workspaceRow.uid)
                        text: "Empty workspace"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(8, 12 * map.previewScale)
                    }
                }
            }

            Repeater {
                id: tileRepeater
                model: windowIds
                delegate: Rectangle {
                    id: tileRect
                    required property int uid
                    readonly property var tile: map.scene.tiles[uid] || null
                    property bool positioned: false
                    Component.onCompleted: Qt.callLater(() => positioned = true)
                    visible: tile !== null
                    x: tile ? tile.x : 0
                    y: tile ? tile.y : 0
                    width: tile ? tile.w : 0
                    height: tile ? tile.h : 0
                    radius: 7 * map.previewScale
                    color: tile && tile.focused ? "#2d3a60" : "#222a42"
                    border.width: tile && tile.focused ? Math.max(1, 2 * map.previewScale) : 1
                    border.color: tile && tile.focused ? Theme.highlight : "#3a4663"
                    Behavior on x {
                        enabled: map.ready && map.animateChanges && tileRect.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on y {
                        enabled: map.ready && map.animateChanges && tileRect.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on width {
                        enabled: map.ready && map.animateChanges && tileRect.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on height {
                        enabled: map.ready && map.animateChanges && tileRect.positioned
                        NumberAnimation {
                            duration: map.panDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: Math.max(1, Math.min(30 * map.previewScale * Theme.workspaceIconScale, Math.min(tileRect.width, tileRect.height) * 0.8))
                        source: tileRect.tile ? NiriService.iconFor(tileRect.tile.appId) : ""
                    }
                }
            }
        }
    }
}
