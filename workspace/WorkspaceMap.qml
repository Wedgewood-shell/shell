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
    // Live finger tracking: the camera follows input directly, with no easing.
    property bool scrubbing: false
    property real scrubIndex0: 0
    property real scrubX0: 0
    property int scrubWs: -1
    // Tile highlighted while scrubbing; held until the real focus is applied by panTo.
    property int scrubFocusId: -1
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
        scrubFocusId = -1
        animateCamera = animated !== false
        cameraX = point.x
        cameraY = point.y
        animateCamera = true
    }
    // ---- live scrubbing (touchpad gestures) ----
    // Workspace rows in visual order, each with the camera point that focuses it.
    function scrubStops() {
        return Object.values(scene.rows).sort((a, b) => a.y - b.y).map(r => {
            const p = focusPoint(r.id, -1)
            return {
                id: r.id,
                x: p.x,
                y: p.y
            }
        })
    }
    // Fractional row index under the camera, so a scrub resumes mid-animation.
    function indexAtCamera(stops) {
        if (stops.length < 2)
            return 0
        if (cameraY <= stops[0].y)
            return 0
        for (let i = 0; i < stops.length - 1; i++)
            if (cameraY <= stops[i + 1].y)
                return i + (cameraY - stops[i].y) / Math.max(1, stops[i + 1].y - stops[i].y)
        return stops.length - 1
    }
    // Past an edge, travel keeps going but with diminishing returns.
    function rubber(value, low, high, limit) {
        const squash = over => limit * (1 - Math.exp(-over / limit))
        return value < low ? low - squash(low - value) : value > high ? high + squash(value - high) : value
    }
    function beginScrub() {
        // Stop in-flight camera easing so it cannot fight the fingers.
        cameraXAnimation.stop()
        cameraYAnimation.stop()
        scrubbing = true
        scrubIndex0 = indexAtCamera(scrubStops())
        scrubX0 = cameraX
        const stops = scrubStops()
        scrubWs = stops.length ? stops[Math.round(scrubIndex0)].id : -1
        scrubFocusId = nearestTileId(scrubWs, cameraX)
    }
    // Tile of a row whose centre is closest to x; its active window if x is null.
    function nearestTileId(wsId, x) {
        const row = scene.rows[wsId]
        const tiles = Object.values(scene.tiles).filter(t => t.ws === wsId)
        if (!tiles.length)
            return -1
        if (x === null && row && scene.tiles[row.activeId])
            return row.activeId
        const target = x === null ? 0 : x
        let best = tiles[0]
        for (const t of tiles)
            if (Math.abs(t.x + t.w / 2 - target) < Math.abs(best.x + best.w / 2 - target))
                best = t
        return best.id
    }
    function endScrub() {
        scrubbing = false
    }
    // `workspaces` is signed travel in workspace units (+ = toward later rows).
    function scrubVertical(workspaces) {
        const stops = scrubStops()
        if (!stops.length)
            return
        const index = rubber(scrubIndex0 + workspaces, 0, stops.length - 1, 0.3)
        const lower = Math.max(0, Math.min(stops.length - 1, Math.floor(index)))
        const upper = Math.min(stops.length - 1, lower + 1)
        const t = index - lower
        cameraX = stops[lower].x + (stops[upper].x - stops[lower].x) * t
        cameraY = stops[lower].y + (stops[upper].y - stops[lower].y) * t
        scrubWs = stops[Math.max(0, Math.min(stops.length - 1, Math.round(index)))].id
        scrubFocusId = nearestTileId(scrubWs, null)
    }
    // `pixels` is signed travel in map pixels (+ = camera moves toward later columns).
    function scrubHorizontal(pixels) {
        const tiles = Object.values(scene.tiles).filter(t => t.ws === scrubWs)
        if (!tiles.length)
            return
        const low = Math.min(...tiles.map(t => t.x + t.w / 2))
        const high = Math.max(...tiles.map(t => t.x + t.w / 2))
        cameraX = rubber(scrubX0 + pixels, low, high, width * 0.15)
        scrubFocusId = nearestTileId(scrubWs, cameraX)
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
        enabled: map.ready && map.animateCamera && !map.scrubbing
        NumberAnimation {
            id: cameraXAnimation
            duration: map.panDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on cameraY {
        enabled: map.ready && map.animateCamera && !map.scrubbing
        NumberAnimation {
            id: cameraYAnimation
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
                    readonly property bool highlighted: tile !== null && (map.scrubFocusId >= 0 ? uid === map.scrubFocusId : tile.focused)
                    property bool positioned: false
                    Component.onCompleted: Qt.callLater(() => positioned = true)
                    visible: tile !== null
                    x: tile ? tile.x : 0
                    y: tile ? tile.y : 0
                    width: tile ? tile.w : 0
                    height: tile ? tile.h : 0
                    radius: 7 * map.previewScale
                    color: highlighted ? "#2d3a60" : "#222a42"
                    border.width: highlighted ? Math.max(1, 2 * map.previewScale) : 1
                    border.color: highlighted ? Theme.highlight : "#3a4663"
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
