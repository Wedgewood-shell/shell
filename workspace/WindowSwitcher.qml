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
    }
    readonly property var shownWin: NiriService.windows[shownId] || null
    readonly property string shownTitle: shownWin ? (shownWin.title || shownWin.app_id || "") : (open ? "Empty workspace" : "")

    // ---- camera: row index centred on the pill (continuous while scrubbing) ----
    property real scrubRow: 0
    readonly property real camTarget: live && scrubAxis === "v" ? scrubRow : curIndex
    property real camRow: camTarget
    Behavior on camRow {
        enabled: !sw.scrubbing
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
    function clamp01(x) {
        return Math.max(0, Math.min(1, x))
    }
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
            const isCur = ws.id === curWs, n = cols.length
            const anchorId = isCur ? shownId : ws.active_window_id
            let fc = cols.findIndex(col => col.some(t => t.id === anchorId))
            if (fc < 0)
                fc = 0
            if (isCur && scrubCol >= 0 && n)
                fc = Math.min(n - 1, scrubCol)
            // How much of a pill this row has: the current row has one; during a
            // vertical swipe it passes continuously from row to row.
            const rowW = live && scrubAxis === "v" ? clamp01(1 - Math.abs(i - scrubRow)) : (isCur ? 1 : 0)
            // Focus position along the row; fractional while a horizontal swipe is live.
            const f = live && scrubAxis === "h" && isCur && n ? Math.max(0, Math.min(n - 1, scrubF)) : fc
            const colW = c => c >= 0 && c < n ? clamp01(1 - Math.abs(c - f)) * rowW : 0
            const base = cols.map(col => tileWidth(Math.max(...col.map(t => t.w))))
            const widths = base.map((b, c) => b + (openPillW - b) * colW(c))
            const lefts = []
            let x = 0
            for (let c = 0; c < n; c++) {
                lefts.push(x)
                x += widths[c] + tileGap + (pillGap - tileGap) * Math.max(colW(c), colW(c + 1))
            }
            const centre = c => lefts[c] + widths[c] / 2
            const f0 = Math.floor(f), f1 = Math.min(n - 1, f0 + 1)
            const shift = n ? centre(f0) + (centre(f1) - centre(f0)) * (f - f0) : 0
            for (let c = 0; c < n; c++) {
                const col = cols[c], k = col.length, wgt = colW(c)
                const h0 = (tileH - 2 * (k - 1)) / k
                const pillId = wgt > 0 ? (col.some(t => t.id === anchorId) ? anchorId : col[0].id) : -1
                for (let r = 0; r < k; r++) {
                    const isPill = col[r].id === pillId, pp = isPill ? wgt : 0
                    const y0 = -tileH / 2 + r * (h0 + 2)
                    tiles[col[r].id] = {
                        ws: ws.id,
                        row: i,
                        cd: c - f,
                        pp: pp,
                        hide: pillId >= 0 && !isPill ? wgt : 0,
                        app: col[r].app,
                        x: lefts[c] - shift,
                        yoff: y0 + (-pillH / 2 - y0) * pp,
                        w: widths[c],
                        h: h0 + (pillH - h0) * pp
                    }
                }
            }
            if (isCur && cols.length > 1)
                leftNeed = cols.slice(0, -1).reduce((sum, col) => sum + tileWidth(Math.max(...col.map(t => t.w))), 0) + tileGap * (cols.length - 2) + pillGap
            rowInfo.push({
                id: ws.id,
                cols: n,
                fc: fc,
                colIds: cols.map(col => col[0].id)
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
    // `scrubbing` disables easing; `live` makes the scene follow the fingers. On
    // release, easing comes back first and the scene settles one tick later, so
    // the snap to the final column/row animates.
    property bool scrubbing: false
    property bool live: false
    property real scrubF: 0
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
        live = true
        scrubWs = curWs
        scrubRow0 = camRow
        const info = scene.rows[curIndex]
        scrubCol0 = info ? info.fc : 0
        scrubF = scrubCol0
        const t = scene.tiles[shownId]
        scrubColW = shownWin && shownWin.layout && shownWin.layout.tile_size ? shownWin.layout.tile_size[0] : modelData.width / 2
        setVertical(axis === "v")
        scrubRow = camRow
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
            scrubF = rubber(scrubCol0 + steps, 0, info.cols - 1)
            const c = Math.max(0, Math.min(info.cols - 1, Math.round(scrubF)))
            if (c !== scrubCol) {
                scrubCol = c
                scrubWin = info.colIds[c]
            }
        }
    }
    function endScrub() {
        if (!scrubbing)
            return
        scrubbing = false
        Qt.callLater(() => sw.live = false)
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
                    readonly property bool animate: placed && !sw.scrubbing
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
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                        }
                    }
                    // 0 = small box, 1 = expanded into the pill (icon slides left, title appears).
                    property real pp: t ? t.pp : 0
                    Behavior on pp {
                        enabled: tile.animate
                        NumberAnimation {
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    property real slotFade: t ? 1 - t.hide : 1
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
                    radius: 6 + (Theme.closedRadius - 6) * pp
                    color: sw.mix(sw.tileFill, sw.pillFill, pp)
                    border.width: 1
                    border.color: sw.mix(sw.tileBorder, sw.pillBorder, pp)
                    IconImage {
                        readonly property real small: Math.max(1, Math.min(16, Math.min(tile.width, tile.height) - 6))
                        implicitSize: small + (sw.pillIcon - small) * tile.pp
                        x: (tile.width - implicitSize) / 2 * (1 - tile.pp) + sw.pillPad * tile.pp
                        anchors.verticalCenter: parent.verticalCenter
                        source: tile.t ? NiriService.iconFor(tile.t.app) : ""
                    }
                    Text {
                        visible: tile.pp > 0.01
                        x: sw.pillTextX
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, tile.width - x - 12)
                        opacity: tile.pp * tile.pp * tile.pp
                        readonly property var win: NiriService.windows[tile.uid] || null
                        text: win ? (win.title || win.app_id || "") : ""
                        color: "#c7d2ff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ---- resting pill ----
    // At rest this is the module. While expanded, the focused tile in the strip
    // *is* the pill (same geometry and content), so this one fades out; it stays
    // when the current workspace is empty.
    property real holdOverlay: open && !shownWin ? 1 : 0
    Behavior on holdOverlay {
        NumberAnimation {
            duration: 200
        }
    }
    Rectangle {
        id: pill
        opacity: Math.max(sw.holdOverlay, Math.min(1, (1 - sw.e) / 0.2))
        visible: (sw.shownTitle.length > 0 || sw.e > 0) && opacity > 0.01
        x: sw.pillCX - width / 2
        y: sw.pillCY - height / 2
        width: sw.pillW
        height: sw.pillH
        radius: Theme.closedRadius
        color: sw.pillFill
        border.width: 1
        border.color: sw.mix(sw.restBorder, sw.pillBorder, sw.e)
        clip: true
        IconImage {
            visible: sw.shownWin !== null
            x: sw.pillPad
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: sw.pillIcon
            source: sw.shownWin ? NiriService.iconFor(sw.shownWin.app_id) : ""
        }
        Text {
            x: sw.shownWin ? sw.pillTextX : sw.pillPad
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, pill.width - x - 12)
            text: sw.shownTitle
            color: sw.shownWin ? "#c7d2ff" : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }

    // ---- shared pill/tile styling ----
    readonly property int pillPad: 14
    readonly property int pillIcon: 18
    readonly property int pillTextX: pillPad + pillIcon + 10
    readonly property color tileFill: Qt.rgba(0x2a / 255, 0x33 / 255, 0x52 / 255, 1)
    readonly property color tileBorder: Qt.rgba(0.56, 0.66, 1, 0.75)
    readonly property color pillFill: Qt.rgba(0x12 / 255, 0x16 / 255, 0x20 / 255, 0xf0 / 255)
    readonly property color pillBorder: Qt.rgba(0.87, 0.88, 0.96, 0.75)
    readonly property color restBorder: Qt.rgba(0.62, 0.68, 0.86, 0.3)
    function mix(a, b, p) {
        return Qt.rgba(a.r + (b.r - a.r) * p, a.g + (b.g - a.g) * p, a.b + (b.b - a.b) * p, a.a + (b.a - a.a) * p)
    }
}
