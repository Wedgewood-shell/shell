pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Client for Helium's address-bar socket (see helium docs/address-bar-ipc.md).
// Follows every window's page state and runs address-bar completions. It also
// stands in for the browser's own (auto-hidden) address bar: Helium asks it to
// open on Ctrl+L or a new tab, and it says when its editor is open so Helium
// keeps its native address bar hidden meanwhile.
Singleton {
    id: root

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/helide-address-bar.sock"
    property var windows: ({})                  // window id -> latest state event
    property int lastFocusedId: 0               // last window that reported focus
    readonly property bool connected: sock.connected
    readonly property var focusedWindow: {
        for (const id in windows)
            if (windows[id].focused)
                return windows[id]
        return null
    }
    // A Helium window has focus (the address-bar editor keeps the base state alive meanwhile).
    readonly property bool active: focusedWindow !== null
    readonly property var current: focusedWindow || windows[lastFocusedId] || null
    readonly property string url: current ? current.url || "" : ""
    readonly property string title: current ? current.title || "" : ""
    readonly property bool loading: focusedWindow ? !!focusedWindow.loading : false
    readonly property real progress: focusedWindow ? focusedWindow.progress || 0 : 0

    // The island's address editor is open (it has the keyboard, so the
    // browser window lost focus to it).
    readonly property bool editorOpen: OverlayController.launcherOpen && OverlayController.launcherMode === "address"
    onEditorOpenChanged: sendEditorOpen()
    function sendEditorOpen() {
        send(Object.assign({
                               "cmd": "address_bar_open",
                               "open": editorOpen
                           }, target()))
    }

    // The editor should start over for the window's current tab (a new tab
    // opened while it was open).
    signal editorRestart

    // Another tab became the window's current one while the editor was open
    // (a three-finger scrub, a shortcut in the browser): the editor shows the
    // old tab's address, so close it, which gives the keyboard back to the page.
    // Waits briefly in case the change is a new tab asking for the editor.
    Timer {
        id: tabChanged
        interval: 150
        onTriggered: if (root.editorOpen)
            OverlayController.launcherOpen = false
    }

    // Completion results for the editor.
    property var suggestions: []
    property int completeId: 0
    readonly property string completeInput: ""

    function send(obj) {
        if (!sock.connected)
            return
        sock.write(JSON.stringify(obj) + "\n")
        sock.flush()
    }
    function target() {
        return lastFocusedId ? {
            "window": lastFocusedId
        } : ({})
    }
    function navigate(text) {
        send(Object.assign({
                               "cmd": "navigate",
                               "text": text
                           }, target()))
    }
    // Shortcuts the editor passes on to the browser.
    function newTab() {
        send(Object.assign({
                               "cmd": "new_tab"
                           }, target()))
    }
    function closeTab() {
        send(Object.assign({
                               "cmd": "close_tab"
                           }, target()))
    }
    function complete(text) {
        completeId++
        if (text.trim() === "") {
            suggestions = []
            return
        }
        send(Object.assign({
                               "id": "c" + completeId,
                               "cmd": "complete",
                               "text": text
                           }, target()))
    }

    function handle(msg) {
        if (msg.event === "focus_address_bar") {
            // Helium would have focused its hidden address bar ("shortcut" for
            // Ctrl+L, "new_tab"): open ours for that window instead.
            const next = Object.assign({}, windows)
            next[msg.window] = Object.assign({}, msg, {
                                                 "event": "state"
                                             })
            windows = next
            lastFocusedId = msg.window
            tabChanged.stop()
            if (!editorOpen)
                OverlayController.openLauncher("address")
            else
                editorRestart()
        } else if (msg.event === "state") {
            const before = windows[msg.window]
            const next = Object.assign({}, windows)
            next[msg.window] = msg
            windows = next
            if (editorOpen && msg.window === lastFocusedId && before && msg.tab !== undefined && before.tab !== msg.tab)
                tabChanged.restart()
            if (msg.focused)
                lastFocusedId = msg.window
        } else if (msg.event === "closed") {
            const next = Object.assign({}, windows)
            delete next[msg.window]
            windows = next
            if (lastFocusedId === msg.window)
                lastFocusedId = 0
        } else if (msg.event === "suggestions" && msg.source === "query") {
            if (msg.id === "c" + completeId)
                suggestions = msg.suggestions || []
        } else if (msg.ok && msg.windows) {
            const next = {}
            for (const w of msg.windows)
                next[w.window] = w
            windows = next
        }
    }

    Socket {
        id: sock
        path: root.socketPath
        connected: true
        onConnectedChanged: {
            if (connected) {
                root.send({
                              "cmd": "subscribe"
                          })
                root.send({
                              "cmd": "register_address_bar"
                          })
                if (root.editorOpen)
                    root.sendEditorOpen()
            } else {
                root.windows = ({})
                root.suggestions = []
            }
        }
        parser: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line))
                } catch (e) {}
            }
        }
    }
    // The socket appears and disappears with Helium's Synergy mode; keep retrying.
    Timer {
        interval: 3000
        running: !sock.connected
        repeat: true
        onTriggered: {
            sock.connected = false
            sock.connected = true
        }
    }
}
