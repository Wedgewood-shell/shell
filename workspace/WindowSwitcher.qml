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
    property string outputName: modelData.name

    // ---- geometry ----
    readonly property int adjPitch: 40         // pill centre <-> adjacent row centre
    readonly property int pitch: 30            // between further rows
    readonly property int lift: 30             // pill drop in vertical mode (one row peeks above)
    readonly property int tileH: 22
    readonly property int tileGap: 6
    readonly property int pillGap: 8           // pill slot <-> neighbouring tiles
    readonly property int sideRoom: 116        // max strip visible left of the pill
    readonly property int edgePad: 12          // tiles fade over this much past the strip's left edge
    // Label column fits the widest label; labels are right-aligned against the tiles.
    readonly property real labelW: Math.ceil(Math.max(0, ...rows.map(w => labelMetrics.advanceWidth(NiriService.wsLabel(w.id))))) + 15
    // Room left of the pill: only as much as the columns left of the focus take,
    // so the first column sits at the edge with no empty gap. It follows the
    // (animated) focus position, so it only eases on layout changes.
    property real leftRoom: Math.min(sideRoom, scene.leftNeed)
    Behavior on leftRoom {
        enabled: !sw.focusDriven
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
        // Opening keeps pace with niri's camera, which starts fast.
        NumberAnimation {
            duration: sw.motion
            easing.type: sw.open ? Easing.OutCubic : Easing.InOutCubic
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
    readonly property int curWs: activeWsObj ? activeWsObj.id : -1
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
        Qt.callLater(syncFocus)
    }
    readonly property var shownWin: NiriService.windows[shownId] || null
    readonly property string shownTitle: shownWin ? (shownWin.title || shownWin.app_id || "") : ""

    // ---- camera: fractional row index centred on the pill ----
    // With niri's view stream the rows follow niri's own rendered workspace position
    // every frame (swipes, and its settle/switch animations). Without it, an eased
    // fallback follows the active workspace.
    readonly property var wsView: NiriViewService.workspaceViews[outputName] || null
    readonly property bool viewLive: NiriViewService.moving(wsView)
    property real camFallback: curIndex
    Behavior on camFallback {
        NumberAnimation {
            duration: sw.motion
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real camRow: wsView ? wsView.position : camFallback

    // Pill position: its left edge is the module's at rest; open, it shifts right to
    // make room for labels and left neighbours, and down so up to two rows above fit.
    // At rest a pill fits its title; open, every pill is openPillW wide.
    function pillWidthFor(title) {
        const rest = Math.max(54, Math.min(idleMax, titleFont.advanceWidth(title) + 54))
        return rest + (openPillW - rest) * e
    }
    function titleOf(win) {
        return win ? (win.title || win.app_id || "") : ""
    }
    readonly property real pillW: pillWidthFor(shownTitle)
    // The left room counts from where the strip was when it started opening or
    // closing (restLeft), so columns at the module's left edge stay there and only
    // the focus travels, even when focus moves while the switcher opens.
    // The rest offset settles faster than the opening itself, so a column that has
    // to enter from the left is in place before it has faded in.
    readonly property real pillLeft: Math.max(0, labelW * v * e + leftRoom - Math.pow(1 - e, 3) * restLeft)
    property real restSnap: 0
    property bool restFrozen: false
    readonly property real restLeft: restFrozen ? restSnap : leftRoom
    onOpenChanged: {
        // Opening: keep where the strip is now (at rest: the current left room).
        // Closing: settle so that at rest the pill is back at the module's edge.
        restSnap = open ? restLeft : leftRoom
        restFrozen = true
    }
    onEChanged: {
        if (!open && e <= 0)
            restFrozen = false
    }
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

    FontMetrics {
        id: titleFont
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    // ---- scene: every window's slot, relative to the pill centre ----
    function clamp01(x) {
        return Math.max(0, Math.min(1, x))
    }
    function tileWidth(px) {
        return Math.round(tileH * Math.max(1, Math.min(4, px / Math.max(1, modelData.width) * 2.5)))
    }
    // Tiled windows of a workspace as columns (left to right) of tiles (top to bottom).
    function columnsOf(wsId) {
        const wins = NiriService.windows, byCol = {}
        for (const k in wins) {
            const w = wins[k]
            const pos = w.workspace_id === wsId && w.layout && w.layout.pos_in_scrolling_layout
            if (!pos)
                continue
            ;(byCol[pos[0]] = byCol[pos[0]] || []).push({
                id: w.id,
                app: w.app_id || "",
                r: pos[1],
                w: w.layout.tile_size ? w.layout.tile_size[0] : 0
            })
        }
        return Object.keys(byCol).map(Number).sort((a, b) => a - b).map(c => byCol[c].sort((a, b) => a.r - b.r))
    }
    function columnOf(cols, id) {
        return Math.max(0, cols.findIndex(col => col.some(t => t.id === id)))
    }
    readonly property var curCols: columnsOf(curWs)
    readonly property int curFc: columnOf(curCols, shownId)

    // ---- focus: one fractional column position drives the whole current row ----
    // Widths, the tile<->pill morph, the slide and the left room all follow it, so a
    // focus change eases exactly like a swipe. niri's own column position drives it
    // while niri's camera moves; otherwise it eases to the focused column itself.
    property real focusF: 0
    property int focusWs: -1
    property int focusWin: -1
    readonly property var curView: NiriViewService.columnViews[curWs]
    readonly property bool niriDrives: NiriViewService.moving(curView)
    readonly property bool focusDriven: focusAnim.running || niriDrives || viewLive
    NumberAnimation {
        id: focusAnim
        target: sw
        property: "focusF"
        duration: sw.motion
        easing.type: Easing.InOutCubic
    }
    function syncFocus() {
        const n = curCols.length
        if (niriDrives && n) {
            focusAnim.stop()
            focusF = Math.max(0, Math.min(n - 1, curView.position))
        } else if (curWs !== focusWs || shownId === focusWin) {
            // Another workspace, or the same window moved: no focus travel.
            focusAnim.stop()
            focusF = curFc
        } else if (Math.abs(curFc - focusF) > 1e-3 && !(focusAnim.running && focusAnim.to === curFc)) {
            focusAnim.stop()
            focusAnim.to = curFc
            focusAnim.start()
        }
        // Focus travelling within the workspace: open right away (the HUD event
        // arrives a little later) so the strip and the focus move together.
        if (focusWs === curWs && shownId !== focusWin && shownId >= 0 && focusWin >= 0 && canShow()) {
            if (!open)
                setVertical(false)
            keepOpen()
        }
        focusWs = curWs
        focusWin = shownId
    }
    onCurFcChanged: Qt.callLater(syncFocus)
    onCurWsChanged: Qt.callLater(syncFocus)
    onCurColsChanged: Qt.callLater(syncFocus)
    Connections {
        target: NiriViewService
        function onColumnViewsChanged() {
            sw.syncFocus()
        }
    }

    // ---- scene: every window's slot; x is relative to the pill's left edge ----
    readonly property var scene: {
        const wins = NiriService.windows, tiles = {}, rowInfo = []
        let leftNeed = 0
        for (let i = 0; i < rows.length; i++) {
            const ws = rows[i]
            const cols = ws.id === curWs ? curCols : columnsOf(ws.id)
            const isCur = ws.id === curWs, n = cols.length
            const anchorId = isCur ? shownId : ws.active_window_id
            const fc = columnOf(cols, anchorId)
            // How much of a pill this row has: the current row has one; while niri moves
            // between workspaces it passes continuously from row to row.
            const rowW = viewLive ? clamp01(1 - Math.abs(i - camRow)) : (isCur ? 1 : 0)
            // Focus position along the row (fractional while it moves).
            const cv = NiriViewService.columnViews[ws.id]
            const clampF = x => Math.max(0, Math.min(n - 1, x))
            const f = !n ? 0 : isCur && focusWs === curWs ? clampF(focusF) : NiriViewService.moving(cv) ? clampF(cv.position) : fc
            const colW = c => c >= 0 && c < n ? clamp01(1 - Math.abs(c - f)) * rowW : 0
            const pillIdOf = (c, wgt) => wgt > 0 ? (cols[c].some(t => t.id === anchorId) ? anchorId : cols[c][0].id) : -1
            const widths = cols.map((col, c) => {
                const b = tileWidth(Math.max(...col.map(t => t.w)))
                const wgt = colW(c)
                return wgt > 0 ? b + (pillWidthFor(titleOf(wins[pillIdOf(c, wgt)])) - b) * wgt : b
            })
            const lefts = []
            let x = 0
            for (let c = 0; c < n; c++) {
                lefts.push(x)
                x += widths[c] + tileGap + (pillGap - tileGap) * Math.max(colW(c), colW(c + 1))
            }
            const f0 = Math.floor(f), f1 = Math.min(n - 1, f0 + 1)
            const shift = n ? lefts[f0] + (lefts[f1] - lefts[f0]) * (f - f0) : 0
            for (let c = 0; c < n; c++) {
                const col = cols[c], k = col.length, wgt = colW(c)
                const h0 = (tileH - 2 * (k - 1)) / k
                const pillId = pillIdOf(c, wgt)
                for (let r = 0; r < k; r++) {
                    const isPill = col[r].id === pillId, pp = isPill ? wgt : 0
                    const y0 = -tileH / 2 + r * (h0 + 2)
                    tiles[col[r].id] = {
                        ws: ws.id,
                        row: i,
                        col: c,
                        r: r,
                        k: k,
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
            if (isCur)
                leftNeed = shift
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
    // The pill is the focused tile itself (at rest too); a separate resting pill is
    // only drawn when there is no such tile (empty workspace, floating window).
    readonly property bool pillIsTile: {
        const t = scene.tiles[shownId]
        return shownId >= 0 && t !== undefined && t.ws === curWs
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
    Component.onCompleted: {
        syncIds()
        syncFocus()
    }

    // ---- triggers ----
    Connections {
        target: WorkspaceController
        function onHudSerialChanged() {
            if (WorkspaceController.hudScreen !== sw.outputName)
                return
            const k = WorkspaceController.hudKind
            sw.setVertical(k === "switch" || k === "move")
            sw.open = true
            linger.interval = WorkspaceController.hudKind === "move" ? 2400 : 1600
            linger.restart()
        }
    }
    // Swipes: niri reports its camera live, so open as soon as it moves.
    Connections {
        target: NiriViewService
        function onWorkspaceViewMoved(output) {
            const view = sw.wsView
            if (output !== sw.outputName || !view || view.driver !== "Gesture")
                return
            // Unlocked swipes start a workspace gesture even when moving sideways;
            // only show the stack once the workspace position actually moves.
            if (Math.abs(view.position - sw.curIndex) > 0.03)
                sw.setVertical(true)
            else if (!sw.open)
                return
            sw.keepOpen()
        }
        function onColumnViewMoved(workspaceId) {
            const ws = NiriService.workspaces[workspaceId]
            const view = NiriViewService.columnViews[workspaceId]
            if (!ws || ws.output !== sw.outputName || !view || view.driver !== "Gesture")
                return
            if (!sw.open)
                sw.setVertical(false)
            sw.keepOpen()
        }
    }
    function canShow() {
        return NiriService.syncedAt !== 0 && Date.now() - NiriService.syncedAt >= 1500 && !NiriService.overviewOpen && !OverlayController.launcherOpen && !OverlayController.launcherBusy
    }
    function keepOpen() {
        open = true
        linger.interval = 1600
        linger.restart()
    }
    Connections {
        target: OverlayController
        function onDismissHud() {
            linger.stop()
            sw.open = false
        }
    }
    Timer {
        id: linger
        onTriggered: sw.open = false
    }

    // ---- workspace labels ----
    Repeater {
        model: sw.rows
        delegate: Text {
            required property var modelData
            required property int index
            readonly property real d: Math.abs(index - sw.camRow)
            // Slides in from the left with the strip instead of appearing under the pill.
            x: sw.labelW * sw.v * sw.e - sw.labelW * sw.v
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
        x: sw.labelW * sw.v * sw.e
        y: 0
        width: Math.max(0, sw.panelW - x - 6)
        height: sw.height
        clip: true

        Item {
            id: world
            x: sw.pillLeft - strip.x
            y: sw.pillCY

            Repeater {
                model: winIds
                delegate: Rectangle {
                    id: tile
                    required property int uid
                    readonly property var t: sw.scene.tiles[uid] || null
                    // Driven values (focus, open, niri's camera) are followed directly. Only
                    // layout changes (a window moving to another column/row/workspace,
                    // neighbours opening or closing) animate, by easing out the jump.
                    property real dx: 0
                    property real dyo: 0
                    property real dw: 0
                    property real dh: 0
                    property real drow: 0
                    property string slot: ""
                    property var last: null
                    onTChanged: {
                        if (!t) {
                            last = null
                            return
                        }
                        const key = t.ws + ":" + t.col + ":" + t.r + ":" + t.k
                        if (last && key !== slot) {
                            dx += last.x - t.x
                            dyo += last.yoff - t.yoff
                            dw += last.w - t.w
                            dh += last.h - t.h
                            drow += last.row - t.row
                            flip.restart()
                        }
                        slot = key
                        last = t
                    }
                    ParallelAnimation {
                        id: flip
                        NumberAnimation {
                            target: tile
                            property: "dx"
                            to: 0
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: tile
                            property: "dyo"
                            to: 0
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: tile
                            property: "dw"
                            to: 0
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: tile
                            property: "dh"
                            to: 0
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: tile
                            property: "drow"
                            to: 0
                            duration: sw.motion
                            easing.type: Easing.InOutCubic
                        }
                    }
                    x: t ? t.x + dx : 0
                    readonly property real rowPos: t ? t.row + drow : 0
                    y: sw.rowY(rowPos - sw.camRow) + (t ? t.yoff : 0) + dyo
                    width: t ? Math.max(0, t.w + dw) : 0
                    height: t ? Math.max(0, t.h + dh) : 0
                    // Fade by row distance, column distance and the strip edges.
                    readonly property real rowD: Math.abs(rowPos - sw.camRow)
                    readonly property real colFade: t ? Math.max(0.3, 1 - 0.2 * Math.max(0, Math.abs(t.cd) - 1)) : 0
                    // 0 = small box, 1 = expanded into the pill (icon slides left, title appears).
                    readonly property real pp: t ? t.pp : 0
                    readonly property real slotFade: t ? 1 - t.hide : 1
                    // At rest only the pill shows (unless the resting pill stands in for it).
                    readonly property real restFade: sw.e + (1 - sw.e) * pp * (1 - sw.overlayOn)
                    readonly property real leftX: world.x + x
                    // Tiles fade as they scroll off the strip's edges; the focused pill never
                    // does (with no columns to its left it sits right at the left edge).
                    readonly property real edgeFade: {
                        const f = Math.max(0, Math.min(1, 1 + leftX / sw.edgePad)) * Math.max(0, Math.min(1, (strip.width - leftX - width) / 28))
                        return f + (1 - f) * pp
                    }
                    opacity: t ? sw.rowFade(rowD) * colFade * slotFade * edgeFade * restFade : 0
                    visible: t !== null && opacity > 0.01
                    radius: 6 + (Theme.closedRadius - 6) * pp
                    color: sw.mix(sw.tileFill, sw.pillFill, pp)
                    border.width: 1
                    border.color: sw.mix(sw.tileBorder, sw.mix(sw.restBorder, sw.pillBorder, sw.e), pp)
                    IconImage {
                        readonly property real small: Math.max(1, Math.min(16, Math.min(tile.width, tile.height) - 6))
                        implicitSize: small + (sw.pillIcon - small) * tile.pp
                        x: (tile.width - implicitSize) / 2 * (1 - tile.pp) + sw.pillPad * tile.pp
                        anchors.verticalCenter: parent.verticalCenter
                        source: tile.t ? NiriService.windowIcon(NiriService.windows[tile.uid]) : ""
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

    // ---- stand-in pill ----
    // The focused tile is the pill, at rest and open. This one only stands in when
    // there is no such tile: an empty workspace, or a floating/off-workspace window.
    property real overlayOn: pillIsTile ? 0 : 1
    Behavior on overlayOn {
        NumberAnimation {
            duration: 150
        }
    }
    Rectangle {
        id: pill
        opacity: sw.overlayOn
        visible: sw.shownWin !== null && opacity > 0.01
        x: sw.pillLeft
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
            source: NiriService.windowIcon(sw.shownWin)
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

