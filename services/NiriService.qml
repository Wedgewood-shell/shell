pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- mirrored niri state (objects are replaced, never mutated, so old ones work as snapshots) ----
    property bool live: true
    property var windows: ({})            // id -> window (with .layout)
    property var workspaces: ({})         // id -> workspace
    property bool overviewOpen: false
    property bool gotWs: false
    property bool gotWin: false
    property real syncedAt: 0

    readonly property int focusedWs: {
        for (const k in workspaces)
            if (workspaces[k].is_focused)
                return workspaces[k].id
        return -1
    }

    Process {
        id: eventStream
        running: root.live
        command: ["niri", "msg", "--json", "event-stream"]
        onExited: if (root.live)
            reconnect.restart()
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
        interval: 1500
        onTriggered: {
            if (!root.live)
                return
            root.gotWs = false
            root.gotWin = false
            root.syncedAt = 0
            eventStream.running = true
        }
    }
    function handle(ev) {
        const oldWindows = windows, oldWorkspaces = workspaces
        if (ev.WorkspacesChanged) {
            const m = {}
            for (const w of ev.WorkspacesChanged.workspaces)
                m[w.id] = w
            workspaces = m
            gotWs = true
            checkSynced()
        } else if (ev.WindowsChanged) {
            const m = {}
            for (const w of ev.WindowsChanged.windows)
                m[w.id] = w
            windows = m
            gotWin = true
            checkSynced()
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id, focused = ev.WorkspaceActivated.focused
            const target = workspaces[id]
            if (!target)
                return
            const next = {}
            for (const k in workspaces) {
                const w = Object.assign({}, workspaces[k])
                if (w.output === target.output) {
                    w.is_active = (w.id === id)
                }
                if (focused)
                    w.is_focused = (w.id === id)
                next[k] = w
            }
            workspaces = next
        } else if (ev.WorkspaceActiveWindowChanged) {
            const c = ev.WorkspaceActiveWindowChanged
            const w = workspaces[c.workspace_id]
            if (w)
                workspaces = Object.assign({}, workspaces, {
                    [c.workspace_id]: Object.assign({}, w, {
                        active_window_id: c.active_window_id
                    })
                })
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window
            const next = Object.assign({}, windows, {
                [w.id]: w
            })
            if (w.is_focused)                       // niri: a focused window in this event means every other one lost focus
                for (const k in next)
                    if (next[k].id !== w.id && next[k].is_focused)
                        next[k] = Object.assign({}, next[k], {
                            is_focused: false
                        })
            windows = next
        } else if (ev.WindowClosed) {
            const next = Object.assign({}, windows)
            delete next[ev.WindowClosed.id]
            windows = next
        } else if (ev.WindowFocusChanged) {
            const fid = ev.WindowFocusChanged.id
            const next = {}
            for (const k in windows)
                next[k] = Object.assign({}, windows[k], {
                    is_focused: windows[k].id === fid
                })
            windows = next
        } else if (ev.WindowLayoutsChanged) {
            const next = Object.assign({}, windows)
            for (const ch of ev.WindowLayoutsChanged.changes) {
                const w = next[ch[0]]
                if (!w)
                    continue
                next[ch[0]] = Object.assign({}, w, {
                    layout: ch[1]
                })
            }
            windows = next
        } else if (ev.OverviewOpenedOrClosed) {
            overviewOpen = ev.OverviewOpenedOrClosed.is_open
        }
        eventReceived(ev, oldWindows, oldWorkspaces)
    }

    function checkSynced() {
        if (gotWs && gotWin && syncedAt === 0)
            syncedAt = Date.now()
    }

    // ---- helpers ----
    function wsLabel(id) {
        const w = workspaces[id]
        if (!w)
            return ""
        return w.name ? w.name : "Workspace " + w.idx
    }
    // "Workspace 7 → 6" (keeps the header short enough to leave room for the dots)
    function moveLabel(from, to) {
        const a = workspaces[from], b = workspaces[to]
        if (!a || !b)
            return ""
        if (a.name || b.name)
            return wsLabel(from) + " → " + wsLabel(to)
        return "Workspace " + a.idx + " → " + b.idx
    }
    function wsIdx(id) {
        const w = workspaces[id]
        return w ? w.idx : 0
    }
    function wsOnOutput(output) {
        const out = []
        for (const k in workspaces)
            if (workspaces[k].output === output)
                out.push(workspaces[k])
        out.sort((a, b) => a.idx - b.idx)
        return out
    }

    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return Quickshell.iconPath((e && e.icon) ? e.icon : (appId || ""), "application-x-executable")
    }

    // Terminal apps get their own icon, recognised by the title they set
    // (only for terminal windows, so a browser tab named "Zellij …" stays a browser).
    readonly property var terminalIds: ["kitty", "foot", "footclient", "alacritty", "Alacritty", "com.mitchellh.ghostty", "org.wezfurlong.wezterm"]
    readonly property var terminalApps: [
        { re: /^π(\s|$)/, icon: Qt.resolvedUrl("../assets/icons/pi.svg") },
        { re: /^Yazi\b/, icon: "yazi" },
        { re: /^Zellij\b/, icon: "zellij" },
        { re: /(^n?vim\b|\bN?VIM$)/, icon: "nvim" }
    ]
    function windowIcon(win) {
        if (!win)
            return ""
        if (terminalIds.indexOf(win.app_id) >= 0) {
            const t = win.title || ""
            for (const a of terminalApps)
                if (a.re.test(t))
                    return a.icon.toString().indexOf("/") >= 0 ? a.icon : Quickshell.iconPath(a.icon, true) || iconFor(win.app_id)
        }
        return iconFor(win.app_id)
    }

    // Scaled-down picture of a workspace's scrolling layout: columns left to right, tiles stacked inside.
    // Coordinates are in niri logical pixels; the caller scales them to fit.
    readonly property int layoutGap: 16
    function computeLayout(wsId, wins) {
        const gap = layoutGap
        const byCol = {}
        for (const k in wins) {
            const w = wins[k]
            if (w.workspace_id !== wsId)
                continue
            const lay = w.layout
            if (!lay || !lay.pos_in_scrolling_layout)
                // floating windows aren't drawn
                continue
            const c = lay.pos_in_scrolling_layout[0], r = lay.pos_in_scrolling_layout[1]
            if (!byCol[c])
                byCol[c] = []
            byCol[c].push({
                id: w.id,
                app_id: w.app_id || "",
                title: w.title || "",
                focused: !!w.is_focused,
                r: r,
                w: lay.tile_size[0],
                h: lay.tile_size[1]
            })
        }
        const cols = Object.keys(byCol).map(Number).sort((a, b) => a - b)
        const tiles = []
        let x = 0, H = 0
        for (const c of cols) {
            const col = byCol[c].sort((a, b) => a.r - b.r)
            let colW = 0, y = 0
            for (const t of col) {
                tiles.push({
                    id: t.id,
                    app_id: t.app_id,
                    title: t.title,
                    focused: t.focused,
                    x: x,
                    y: y,
                    w: t.w,
                    h: t.h
                })
                y += t.h + gap
                colW = Math.max(colW, t.w)
            }
            H = Math.max(H, y - gap)
            x += colW + gap
        }
        return {
            tiles: tiles,
            W: tiles.length ? x - gap : 0,
            H: H
        }
    }

    signal eventReceived(var event, var previousWindows, var previousWorkspaces)
    readonly property string windowTitle: {
        for (const k in windows)
            if (windows[k].is_focused)
                return windows[k].title || windows[k].app_id || ""
        return ""
    }
    readonly property var windowData: Object.values(windows).map(w => ({
                id: w.id,
                title: w.title || "(untitled)",
                app_id: w.app_id || "",
                focused: w.is_focused,
                urgent: w.is_urgent,
                ts: w.focus_timestamp ? w.focus_timestamp.secs + w.focus_timestamp.nanos / 1e9 : 0,
                ws: workspaces[w.workspace_id] ? workspaces[w.workspace_id].idx : "?",
                output: workspaces[w.workspace_id] ? workspaces[w.workspace_id].output : ""
            }))
    property var tabData: []
    function refreshTabs() {
        if (!tabFetch.running)
            tabFetch.running = true
    }
    Process {
        id: tabFetch
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/island-tabs.json\" 2>/dev/null || echo []"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tabData = JSON.parse(text)
                } catch (e) {
                    root.tabData = []
                }
            }
        }
    }
}
