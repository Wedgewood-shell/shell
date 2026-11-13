pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- HUD request (read by WorkspaceHud) ----
    property string hudKind: ""           // "switch" | "move" | "shift" | "focus"
    property int hudSerial: 0
    property int hudWs: -1                // workspace to show (destination for a move)
    property int hudFrom: -1              // source workspace of a move
    property int hudFromWinId: -1        // previous focused window for a horizontal pan
    property int hudWinId: -1             // moving window
    property var hudSnap: ({})            // windows before the change (so moves/shifts can animate from it)
    property int hudDir: 0                // +1 = went down to a higher-numbered workspace, -1 = went up
    property string hudScreen: ""
    property bool hudBusy: false          // the HUD pill is open or still shrinking back

    property real structuralAt: 0

    // ---- live 4-finger swipe (uses niri's gesture scaling) ----
    // The axis locks once the swipe has moved 16 units, like niri. `amount` is
    // the signed travel along that axis after natural-scroll inversion:
    // 300 units per workspace ("v"), 1200 units per screen width ("h").
    signal gestureStarted(string axis)
    signal gestureMoved(real amount)
    signal gestureEnded
    property bool gestureActive: false
    property string gestureAxis: ""
    property bool gestureArmed: false
    property real gestureX: 0
    property real gestureY: 0
    property real gestureAmount: 0

    Connections {
        target: GestureService
        function onBegan(fingers) {
            root.gestureBegin(fingers)
        }
        function onMoved(dx, dy) {
            root.gestureMove(dx, dy)
        }
        function onEnded(cancelled) {
            root.gestureEnd()
        }
    }
    function gestureBegin(fingers) {
        gestureEnd()
        gestureX = 0
        gestureY = 0
        gestureAmount = 0
        gestureArmed = fingers === 4 && NiriService.syncedAt > 0 && !NiriService.overviewOpen && !OverlayController.launcherOpen && !OverlayController.launcherBusy
    }
    function gestureMove(rawX, rawY) {
        if (!gestureArmed)
            return
        const flip = Settings.touchpadNaturalScroll ? -1 : 1
        const dx = rawX * flip, dy = rawY * flip
        if (!gestureActive) {
            gestureX += dx
            gestureY += dy
            if (gestureX * gestureX + gestureY * gestureY < 256)
                return
            const ws = NiriService.workspaces[NiriService.focusedWs]
            if (!ws) {
                gestureArmed = false
                return
            }
            gestureAxis = Math.abs(gestureX) > Math.abs(gestureY) ? "h" : "v"
            hudScreen = ws.output
            hudWs = ws.id
            gestureActive = true
            gestureStarted(gestureAxis)
        }
        gestureAmount += gestureAxis === "h" ? dx : dy
        gestureMoved(gestureAmount)
    }
    function gestureEnd() {
        gestureArmed = false
        if (!gestureActive)
            return
        gestureActive = false
        gestureEnded()
    }
    function sign(n) {
        return n > 0 ? 1 : n < 0 ? -1 : 0
    }

    Connections {
        target: NiriService
        function onEventReceived(ev, before, previousWs) {
            root.handle(ev, before, previousWs)
        }
    }
    function handle(ev, before, previousWs) {
        if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id, target = NiriService.workspaces[id]
            if (!target)
                return
            for (const k in previousWs) {
                const w = previousWs[k]
                if (w.output === target.output && w.is_active && w.idx !== target.idx)
                    queue("switch", {
                        ws: id,
                        from: w.id,
                        dir: sign(target.idx - w.idx)
                    })
            }
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window, old = before[w.id]
            if (!old || old.workspace_id !== w.workspace_id)
                structuralAt = Date.now()
            if (old && old.workspace_id !== w.workspace_id && old.workspace_id != null && w.workspace_id != null)
                queue("move", {
                    id: w.id,
                    from: old.workspace_id,
                    ws: w.workspace_id,
                    snap: before
                })
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id, next = NiriService.windows[id]
            const previous = Object.values(before).find(w => w.is_focused)
            if (next && previous && next.id !== previous.id && next.workspace_id != null && next.workspace_id === previous.workspace_id)
                queue("focus", {
                    ws: next.workspace_id,
                    id: next.id,
                    fromId: previous.id,
                    snap: before
                })
        } else if (ev.WindowClosed) {
            structuralAt = Date.now()
        } else if (ev.WindowLayoutsChanged && Date.now() - structuralAt > 450) {
            for (const ch of ev.WindowLayoutsChanged.changes) {
                const old = before[ch[0]], current = NiriService.windows[ch[0]]
                const a = old && old.layout && old.layout.pos_in_scrolling_layout
                const b = current && current.layout && current.layout.pos_in_scrolling_layout
                if (a && b && current.workspace_id != null && (a[0] !== b[0] || a[1] !== b[1])) {
                    queue("shift", {
                        ws: current.workspace_id,
                        snap: before
                    })
                    break
                }
            }
        }
    }
    // ---- turn a burst of events into one HUD request (a move also activates a workspace, etc.) ----
    property var pending: ({})
    function queue(kind, info) {
        const p = Object.assign({}, pending)
        p[kind] = info
        pending = p
        flush.restart()
    }
    Timer {
        id: flush
        interval: 70
        onTriggered: {
            const p = root.pending
            root.pending = ({})
            if (NiriService.syncedAt === 0 || Date.now() - NiriService.syncedAt < 1500 || NiriService.overviewOpen)
                return
            if (p.move)
                root.fire("move", p.move)
            else if (p.shift)
                root.fire("shift", p.shift)
            else if (p.switch)
                root.fire("switch", p.switch)
            else if (p.focus)
                root.fire("focus", p.focus)
        }
    }

    function fire(kind, info) {
        if (OverlayController.launcherOpen || OverlayController.launcherBusy)
            return
        const ws = NiriService.workspaces[info.ws]
        hudKind = kind
        hudWs = info.ws != null ? info.ws : -1
        hudFrom = info.from != null ? info.from : -1
        hudFromWinId = info.fromId != null ? info.fromId : -1
        hudWinId = info.id !== undefined ? info.id : -1
        hudSnap = info.snap || ({})
        hudDir = info.dir || 0
        hudScreen = ws ? ws.output : ""
        hudSerial += 1
    }
}
