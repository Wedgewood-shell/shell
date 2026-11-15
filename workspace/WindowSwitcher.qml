import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."

// Left bar module. At rest: the focused window's pill. On a focus change it
// grows rightward into a strip of the workspace's columns (the strip slides
// under a fixed pill); on a workspace change the neighbouring workspaces are
// stacked above/below and the stack scrolls vertically. Never takes input.
PanelWindow {
    id: sw
    required property var modelData
    screen: modelData
    readonly property string outputName: modelData.name

    // ---- geometry ----
    readonly property int adjPitch: 40         // pill centre <-> adjacent row centre
    readonly property int pitch: 30            // between further rows
    readonly property int lift: 30             // pill drop in vertical mode (one row peeks above)
    readonly property int tileH: 22
    readonly property int tileGap: 6
    readonly property int pillGap: 8           // pill slot <-> neighbouring tiles
    readonly property int sideRoom: 116        // max strip visible left of the pill
    readonly property int edgePad: 12          // strip edge fade zone
    // Label column fits the widest label; labels are right-aligned against the tiles.
    readonly property real labelW: Math.ceil(Math.max(0, ...rows.map(w => labelMetrics.advanceWidth(NiriService.wsLabel(w.id))))) + 10
    // Room left of the pill: only as much as the current workspace's columns need
    // (the most they can need, so it holds still while switching within it).
    property real leftRoom: Math.min(sideRoom, scene.leftNeed + edgePad)
    Behavior on leftRoom {
        NumberAnimation {
            duration: sw.motion
            easing.type: Easing.InOutCubic
        }
    }
    FontMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    readonly property int openPillW: 210
    readonly property int pillH: Theme.barHeight
    readonly property real islandW: OverlayController.islandWidths[outputName] ?? Theme.islandBaseWidth
    readonly property real room: Math.max(0, modelData.width / 2 - islandW / 2 - 24 - 16)
    readonly property real idleMax: Math.min(Theme.windowTitleMaxWidth, room)
    readonly property real panelW: Math.min(640, room)
    readonly property int motion: 360

    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.topMargin
        left: 16
    }
    // Fixed surface; only the content animates.
    implicitWidth: Math.max(1, Math.round(modelData.width / 2))
    implicitHeight: pillH / 2 + lift + adjPitch + 2 * pitch + tileH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "window-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // ---- state ----
    property bool open: false
    property real e: open ? 1 : 0             // 0 = resting pill, 1 = expanded
    Behavior on e {
        NumberAnimation {
            duration: sw.motion
            easing.type: Easing.InOutCubic
        }
    }

    // Vertical mode (workspace switch/move) adds labels and neighbouring rows;
    // horizontal mode (focus change in the same workspace) is just the strip.
    property bool vertical: false
    property real v: vertical ? 1 : 0
    property bool vSnap: false
    Behavior on v {
        enabled: !sw.vSnap
        NumberAnimation {
            duration: sw.motion
            easing.type: Easing.InOutCubic
        }
    }

    readonly property var rows: NiriService.wsOnOutput(outputName)
    readonly property var activeWsObj: rows.find(w => w.is_active) || null
    property int scrubWs: -1
    property int scrubWin: -1
    readonly property int curWs: scrubWs >= 0 ? scrubWs : (activeWsObj ? activeWsObj.id : -1)
    readonly property int curIndex: Math.max(0, rows.findIndex(w => w.id === curWs))
    readonly property var focusedWin: {
        const all = NiriService.windows
        for (const k in all)
            if (all[k].is_focused)
                return all[k]
        return null
    }
    property int lastId: -1
    readonly property int shownId: {
        if (scrubWin >= 0)
            return scrubWin
        const f = focusedWin
        if (f && (!open || f.workspace_id === curWs))
            return f.id
        if (open) {
            const ws = NiriService.workspaces[curWs]
            return ws && ws.active_window_id != null ? ws.active_window_id : -1
        }
        return (OverlayController.launcherOpen || OverlayController.launcherBusy) ? lastId : -1
    }
    onShownIdChanged: {
        if (shownId >= 0 && focusedWin && shownId === focusedWin.id)
            lastId = shownId
        // The HUD opens ~70ms after niri's event; wait briefly so the change
        // slides in the open pill instead of snapping in the resting one.
        if (open)
            face.swap()
        else
            swapLater.restart()
    }
    Timer {
        id: swapLater
        interval: 110
        onTriggered: face.swap()
    }
    readonly property var shownWin: NiriService.windows[shownId] || null
    readonly property string shownTitle: shownWin ? (shownWin.title || shownWin.app_id || "") : (open ? "Empty workspace" : "")

    // ---- camera: row index centred on the pill (continuous while scrubbing) ----
    property bool vScrub: false
    property real scrubRow: 0
    readonly property real camTarget: vScrub ? scrubRow : curIndex
    property real camRow: camTarget
    Behavior on camRow {
        enabled: !sw.vScrub
        NumberAnimation {
            duration: sw.motion
            easing.type: Easing.InOutCubic
        }
    }

    // Pill position: shifts right to make room for labels and left neighbours,
    // and down so up to two rows above fit.
    readonly property real pillW: idleW + (openPillW - idleW) * e
    readonly property real idleW: Math.max(54, Math.min(idleMax, titleMetrics.advanceWidth + 54))
    readonly property real pillCX: idleW / 2 + (labelW * v + leftRoom + openPillW / 2 - idleW / 2) * e
    readonly property real pillCY: pillH / 2 + Math.min(1, camRow) * lift * e * v
    // Vertical offset of a row `d` rows away from the camera (fractional while moving).
    function rowY(d) {
        const a = Math.abs(d)
        return a <= 1 ? d * adjPitch : Math.sign(d) * (adjPitch + (a - 1) * pitch)
    }
    // Neighbouring rows are only shown in vertical mode.
    // A fresh open starts directly in its mode; switching modes while open animates.
    function setVertical(on) {
        vSnap = e < 0.05
        vertical = on
        vSnap = false
    }
    function rowFade(d) {
        const f = Math.max(0, Math.min(1, 1 - 0.36 * d))
        return f * (1 - Math.min(1, d * 2) * (1 - v))
    }

    TextMetrics {
        id: titleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 14
        text: sw.shownTitle
    }

    // ---- scene: every window's slot, relative to the pill centre ----
    function tileWidth(px) {
        return Math.round(tileH * Math.max(1, Math.min(4, px / Math.max(1, modelData.width) * 2.5)))
    }
    readonly property var scene: {
        const wins = NiriService.windows, tiles = {}, rowInfo = []
        let leftNeed = 0
        for (let i = 0; i < rows.length; i++) {
            const ws = rows[i], byCol = {}
            for (const k in wins) {
                const w = wins[k]
                const pos = w.workspace_id === ws.id && w.layout && w.layout.pos_in_scrolling_layout
                if (!pos)
                    continue
                ;(byCol[pos[0]] = byCol[pos[0]] || []).push({
                    id: w.id,
                    app: w.app_id || "",
                    r: pos[1],
                    w: w.layout.tile_size ? w.layout.tile_size[0] : 0
                })
            }
            const cols = Object.keys(byCol).map(Number).sort((a, b) => a - b).map(c => byCol[c].sort((a, b) => a.r - b.r))
            const isCur = ws.id === curWs
            const anchorId = isCur ? shownId : ws.active_window_id
            let fc = cols.findIndex(col => col.some(t => t.id === anchorId))
            if (fc < 0)
                fc = 0
            if (isCur && scrubCol >= 0 && cols.length)
                fc = Math.min(cols.length - 1, scrubCol)
            const widths = cols.map((col, c) => isCur && c === fc ? openPillW : tileWidth(Math.max(...col.map(t => t.w))))
            const gapAfter = c => (isCur && (c === fc || c + 1 === fc)) ? pillGap : tileGap
            const lefts = []
            let x = 0
            for (let c = 0; c < cols.length; c++) {
                lefts.push(x)
                x += widths[c] + gapAfter(c)
            }
            const shift = cols.length ? lefts[fc] + widths[fc] / 2 : 0
            for (let c = 0; c < cols.length; c++) {
                const col = cols[c], n = col.length
                const h = (tileH - 2 * (n - 1)) / n
                for (let r = 0; r < n; r++)
                    tiles[col[r].id] = {
                        ws: ws.id,
                        row: i,
                        cd: c - fc,
                        pill: isCur && c === fc,
                        app: col[r].app,
                        x: lefts[c] - shift,
                        yoff: -tileH / 2 + r * (h + 2),
                        w: widths[c],
                        h: h
                    }
            }
            if (isCur && cols.length > 1)
                leftNeed = cols.slice(0, -1).reduce((sum, col) => sum + tileWidth(Math.max(...col.map(t => t.w))), 0) + tileGap * (cols.length - 2) + pillGap
            rowInfo.push({
                id: ws.id,
                cols: cols.length,
                fc: fc
            })
        }
        return {
            tiles: tiles,
            rows: rowInfo,
            leftNeed: leftNeed
        }
    }

    // Persistent delegates per window, so moved windows fly between rows.
    ListModel {
        id: winIds
    }
    function syncIds() {
        const wanted = new Set(Object.keys(NiriService.windows).map(Number))
        for (let i = winIds.count - 1; i >= 0; i--)
            if (!wanted.has(winIds.get(i).uid))
                winIds.remove(i)
        const have = new Set()
        for (let i = 0; i < winIds.count; i++)
            have.add(winIds.get(i).uid)
        for (const id of wanted)
            if (!have.has(id))
                winIds.append({
                    uid: id
                })
    }
    Connections {
        target: NiriService
        function onWindowsChanged() {
            sw.syncIds()
        }
    }
    Component.onCompleted: syncIds()

    // ---- triggers ----
    Connections {
        target: WorkspaceController
        function onHudSerialChanged() {
            if (WorkspaceController.hudScreen !== sw.outputName || sw.scrubbing)
                return
            sw.clearScrub()
            const k = WorkspaceController.hudKind
            sw.setVertical(k === "switch" || k === "move")
            sw.open = true
            if (swapLater.running) {
                swapLater.stop()
                face.swap()
            }
            linger.interval = WorkspaceController.hudKind === "move" ? 2400 : 1600
            linger.restart()
        }
        function onGestureStarted(axis) {
            if (WorkspaceController.hudScreen === sw.outputName)
                sw.beginScrub(axis)
        }
        function onGestureMoved(amount) {
            sw.scrub(amount)
        }
        function onGestureEnded() {
            sw.endScrub()
        }
    }
    Connections {
        target: OverlayController
        function onDismissHud() {
            linger.stop()
            sw.endScrub()
            sw.open = false
        }
    }
    Timer {
        id: linger
        onTriggered: sw.open = false
    }

    // ---- live 4-finger swipe ----
    property bool scrubbing: false
    property string scrubAxis: ""
    property int scrubCol: -1
    property real scrubRow0: 0
    property int scrubCol0: 0
    property real scrubColW: 1
    readonly property Timer settle: Timer {
        interval: 350
        onTriggered: sw.clearScrub()
    }
    // Drop every gesture override so the view follows niri's state again.
    function clearScrub() {
        settle.stop()
        scrubWs = -1
        scrubWin = -1
        scrubCol = -1
    }
    function beginScrub(axis) {
        linger.stop()
        clearScrub()
        scrubAxis = axis
        scrubbing = true
        scrubWs = curWs
        scrubRow0 = camRow
        const info = scene.rows[curIndex]
        scrubCol0 = info ? info.fc : 0
        const t = scene.tiles[shownId]
        scrubColW = shownWin && shownWin.layout && shownWin.layout.tile_size ? shownWin.layout.tile_size[0] : modelData.width / 2
        setVertical(axis === "v")
        if (axis === "v") {
            scrubRow = camRow
            vScrub = true
        }
        open = true
    }
    function rubber(v, lo, hi) {
        const squash = o => 0.3 * (1 - Math.exp(-o / 0.3))
        return v < lo ? lo - squash(lo - v) : v > hi ? hi + squash(v - hi) : v
    }
    function scrub(amount) {
        if (!scrubbing)
            return
        if (scrubAxis === "v") {
            scrubRow = rubber(scrubRow0 + amount / 300, 0, rows.length - 1)
            const i = Math.max(0, Math.min(rows.length - 1, Math.round(scrubRow)))
            scrubWs = rows[i].id
            scrubWin = -1
            scrubCol = -1
        } else {
            const info = scene.rows[curIndex]
            if (!info || !info.cols)
                return
            const steps = amount / 1200 * modelData.width / Math.max(1, scrubColW)
            scrubCol = Math.max(0, Math.min(info.cols - 1, Math.round(scrubCol0 + steps)))
            const ids = Object.keys(scene.tiles).map(Number).filter(id => scene.tiles[id].ws === curWs && scene.tiles[id].cd === scrubCol - info.fc)
            if (ids.length)
                scrubWin = ids[0]
        }
    }
    function endScrub() {
        if (!scrubbing)
            return
        scrubbing = false
        vScrub = false
        linger.interval = 1600
        linger.restart()
        // Niri applies the real result within a frame or two; hold the scrubbed
        // target briefly so the pill does not flick back to the old focus.
        settle.restart()
    }

    // ---- workspace labels ----
    Repeater {
        model: sw.rows
        delegate: Text {
            required property var modelData
            required property int index
            readonly property real d: Math.abs(index - sw.camRow)
            x: 0
            width: sw.labelW - 6
            horizontalAlignment: Text.AlignRight
            y: sw.pillCY + sw.rowY(index - sw.camRow) - height / 2
            visible: opacity > 0.01
            opacity: sw.e * sw.v * sw.rowFade(d)
            elide: Text.ElideRight
            text: NiriService.wsLabel(modelData.id)
            color: d < 0.5 ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: d < 0.5 ? Font.DemiBold : Font.Normal
        }
    }

    // ---- strip ----
    Item {
        id: strip
        x: sw.labelW * sw.v
        y: 0
        width: Math.max(0, sw.panelW - x - 6)
        height: sw.height
        clip: true
        opacity: sw.e
        visible: opacity > 0

        Item {
            id: world
            x: sw.pillCX - strip.x
            y: sw.pillCY

            // Empty workspaces: a faint placeholder where their tiles would be.
            Repeater {
                model: sw.rows
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var info: sw.scene.rows[index]
                    visible: info !== undefined && info.cols === 0 && modelData.id !== sw.curWs
                    x: -width / 2
                    y: sw.rowY(index - sw.camRow) - height / 2
                    width: sw.tileH
                    height: sw.tileH
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: "#3a4468"
                    opacity: sw.rowFade(Math.abs(index - sw.camRow))
                }
            }

            Repeater {
                model: winIds
                delegate: Rectangle {
                    id: tile
                    required property int uid
                    readonly property var t: sw.scene.tiles[uid] || null
                    property bool placed: false
                    Component.onCompleted: Qt.callLater(() => placed = true)
                    readonly property bool animate: placed
                    x: t ? t.x : 0
                    // Row position animates on its own, so a window moved to another
                    // workspace travels between rows.
                    property real rowPos: t ? t.row : 0
                    property real yoff: t ? t.yoff : 0
                    Behavior on rowPos {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on yoff {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    y: sw.rowY(rowPos - sw.camRow) + yoff
                    width: t ? t.w : 0
                    height: t ? t.h : 0
                    Behavior on x {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on width {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    Behavior on height {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    // Fade by row distance, column distance and the strip edges.
                    readonly property real rowD: Math.abs(rowPos - sw.camRow)
                    property real colFade: t ? Math.max(0.3, 1 - 0.2 * Math.max(0, Math.abs(t.cd) - 1)) : 0
                    Behavior on colFade {
                        NumberAnimation {
                            duration: sw.motion
                        }
                    }
                    property real slotFade: t && t.pill ? 0 : 1
                    Behavior on slotFade {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    readonly property real leftX: world.x + x
                    readonly property real edgeFade: Math.max(0, Math.min(1, leftX / sw.edgePad)) * Math.max(0, Math.min(1, (strip.width - leftX - width) / 28))
                    opacity: t ? sw.rowFade(rowD) * colFade * slotFade * edgeFade : 0
                    visible: t !== null && opacity > 0.01
                    radius: 6
                    color: "#2a3352"
                    border.width: 1
                    border.color: Qt.rgba(0.56, 0.66, 1, 0.75)
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: Math.max(1, Math.min(16, Math.min(tile.width, tile.height) - 6))
                        source: tile.t ? NiriService.iconFor(tile.t.app) : ""
                    }
                }
            }
        }
    }

    // ---- the pill ----
    Rectangle {
        id: pill
        visible: sw.shownTitle.length > 0 || sw.e > 0
        x: sw.pillCX - width / 2
        y: sw.pillCY - height / 2
        width: sw.pillW
        height: sw.pillH
        radius: Theme.closedRadius
        color: "#f0121620"
        border.width: 1
        border.color: Qt.rgba(0.62 + 0.25 * sw.e, 0.68 + 0.2 * sw.e, 0.86 + 0.1 * sw.e, 0.3 + 0.45 * sw.e)
        clip: true

        Item {
            id: face
            anchors.fill: parent
            // Two layers: the outgoing face slides out as the incoming one slides
            // in — horizontally for a focus move, vertically for a workspace change.
            property int front: 0
            property int lastRow: sw.curIndex
            property int lastCol: 0
            function swap() {
                const row = sw.curIndex
                const info = sw.scene.rows[row]
                const col = info ? info.fc : 0
                let dx = 0, dy = 0
                if (row !== lastRow)
                    dy = row > lastRow ? 1 : -1
                else
                    dx = col > lastCol ? 1 : col < lastCol ? -1 : 0
                lastRow = row
                lastCol = col
                const a = front === 0 ? faceA : faceB, b = front === 0 ? faceB : faceA
                b.wid = sw.shownId
                b.emptyText = sw.shownTitle
                if (sw.e < 0.01 || (dx === 0 && dy === 0)) {
                    slide.stop()
                    a.opacity = 0
                    b.opacity = 1
                    b.ox = 0
                    b.oy = 0
                } else {
                    slide.stop()
                    outX.target = a
                    outY.target = a
                    outO.target = a
                    inX.target = b
                    inY.target = b
                    inO.target = b
                    outX.to = -dx * 28
                    outY.to = -dy * 18
                    inX.from = dx * 28
                    inY.from = dy * 18
                    slide.start()
                }
                front = 1 - front
            }
            ParallelAnimation {
                id: slide
                NumberAnimation {
                    id: outX
                    property: "ox"
                    from: 0
                    duration: sw.motion
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    id: outY
                    property: "oy"
                    from: 0
                    duration: sw.motion
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    id: outO
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: sw.motion * 0.6
                }
                NumberAnimation {
                    id: inX
                    property: "ox"
                    to: 0
                    duration: sw.motion
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    id: inY
                    property: "oy"
                    to: 0
                    duration: sw.motion
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    id: inO
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: sw.motion
                }
            }
            Component.onCompleted: {
                faceA.wid = sw.shownId
                faceA.emptyText = sw.shownTitle
                faceA.opacity = 1
                faceB.opacity = 0
            }
            Face {
                id: faceA
            }
            Face {
                id: faceB
            }
        }
    }

    component Face: Item {
        id: f
        property int wid: -1
        property string emptyText: ""
        property real ox: 0
        property real oy: 0
        readonly property var win: NiriService.windows[wid] || null
        width: pill.width
        height: pill.height
        transform: Translate {
            x: f.ox
            y: f.oy
        }
        Rectangle {
            id: chip
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 6
            visible: f.win !== null
            color: "#2a3352"
            border.width: 1
            border.color: Qt.rgba(0.56, 0.66, 1, 0.75)
            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: f.win ? NiriService.iconFor(f.win.app_id) : ""
            }
        }
        Text {
            id: label
            x: f.win ? 42 : 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, f.width - x - 12)
            text: f.win ? (f.win.title || f.win.app_id || "") : (f.wid === sw.shownId ? sw.shownTitle : f.emptyText)
            color: f.win ? "#c7d2ff" : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }
}
