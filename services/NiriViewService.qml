pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Live view (camera) positions from niri's view stream (`niri msg view-stream`,
// sortedcord fork). While a view moves — touchpad swipe, drag, or the settling
// animation — niri sends one event per rendered frame, so presentation can follow
// the compositor exactly instead of guessing from raw input.
//
// Positions are fractional and 0-based: a workspace position counts workspaces on
// the output in idx order; a column position counts the workspace's columns. Both
// are whole numbers at rest. `driver` is "Idle", "Gesture" or "Animation".
Singleton {
    id: root

    property bool live: true
    // False on a niri without the view stream; the shell then falls back to
    // discrete events from NiriService.
    property bool available: false

    // output name -> { position, target (workspace id), driver }
    property var workspaceViews: ({})
    // workspace id -> { position, target (column index or -1), driver }
    property var columnViews: ({})

    // Emitted whenever a view changes while it is moving (driver != "Idle").
    signal workspaceViewMoved(string output)
    signal columnViewMoved(int workspaceId)

    function moving(view) {
        return view !== undefined && view !== null && view.driver !== "Idle"
    }

    Process {
        id: stream
        running: root.live
        command: ["niri", "msg", "--json", "view-stream"]
        onExited: {
            root.available = false
            root.workspaceViews = ({})
            root.columnViews = ({})
            // An older niri rejects the request immediately: retry rarely.
            if (root.live)
                reconnect.restart()
        }
        stdout: SplitParser {
            onRead: line => {
                let ev
                try {
                    ev = JSON.parse(line)
                } catch (e) {
                    return
                }
                root.handle(ev)
            }
        }
    }
    Timer {
        id: reconnect
        interval: root.available ? 1500 : 30000
        onTriggered: stream.running = root.live
    }

    function handle(ev) {
        if (ev.WorkspaceViewChanged) {
            const v = ev.WorkspaceViewChanged
            const next = Object.assign({}, workspaceViews)
            next[v.output] = {
                position: v.position,
                target: v.target_workspace_id,
                driver: v.driver
            }
            workspaceViews = next
            available = true
            if (v.driver !== "Idle")
                workspaceViewMoved(v.output)
        } else if (ev.ColumnViewChanged) {
            const v = ev.ColumnViewChanged
            const next = Object.assign({}, columnViews)
            next[v.workspace_id] = {
                position: v.position,
                target: v.target_column == null ? -1 : v.target_column,
                driver: v.driver
            }
            columnViews = next
            available = true
            if (v.driver !== "Idle")
                columnViewMoved(v.workspace_id)
        }
    }
}
