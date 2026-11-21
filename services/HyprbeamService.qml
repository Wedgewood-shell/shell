pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Client for the hyprbeam launcher daemon (~/Projects/hyprbeam). QML can't speak
// its MessagePack frames, so this keeps one `hyprbeam pipe` process (a JSON-lines
// bridge holding a single daemon connection) running once it has been used. A new
// query cancels the previous one daemon-side; frames for older ids are dropped here.
Singleton {
    id: root

    readonly property string binary: Quickshell.env("HOME") + "/.local/bin/hyprbeam"
    // Latest result list for `queryId`. Each frame replaces it; `done` marks the last.
    property var items: []
    property bool done: true
    property int queryId: 0
    property string queryText: ""
    // Last daemon/bridge error, cleared by the next results frame.
    property string error: ""

    property bool ready: false
    property var queue: []
    property real lastExit: 0

    // Starts the bridge early (the launcher opening) so the first query doesn't wait on it.
    // Restarts are spaced a second apart, so a missing daemon can't spin it.
    function warm() {
        if (pipe.running || restart.running)
            return
        const wait = lastExit + 1000 - Date.now()
        if (wait > 0) {
            restart.interval = wait
            restart.start()
        } else
            pipe.running = true
    }
    function query(text) {
        queryId++
        queryText = text
        done = false
        send({
                 "type": "query",
                 "id": queryId,
                 "text": text,
                 "limit": 50
             })
    }
    function activate(item, action) {
        const req = {
            "type": "activate",
            "item": item
        }
        if (action)
            req.action = action
        send(req)
    }
    function send(req) {
        const line = JSON.stringify(req) + "\n"
        if (ready && pipe.running) {
            pipe.write(line)
            return
        }
        // A newer query supersedes any queued one; activations are kept.
        if (req.type === "query")
            queue = queue.filter(l => !l.startsWith("{\"type\":\"query\""))
        queue = queue.concat([line])
        warm()
    }
    function handle(msg) {
        if (msg.type === "results") {
            if (msg.id !== queryId)
                return
            error = ""
            items = msg.items || []
            done = !!msg.done
        } else if (msg.type === "error") {
            console.warn("hyprbeam: " + msg.message)
            error = msg.message || "error"
            done = true
        }
    }

    Process {
        id: pipe
        command: [root.binary, "pipe"]
        stdinEnabled: true
        onStarted: {
            root.ready = true
            const q = root.queue
            root.queue = []
            for (const l of q)
                pipe.write(l)
        }
        onExited: (code, status) => {
            root.ready = false
            root.done = true
            root.lastExit = Date.now()
            if (code !== 0 && root.error === "")
                root.error = "hyprbeam pipe exited (" + code + ")"
            // Restart only when something is waiting; otherwise the next query does it.
            if (root.queue.length)
                root.warm()
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.handle(JSON.parse(data))
                } catch (e) {
                    console.warn("hyprbeam: bad line: " + data)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("hyprbeam pipe: " + data)
        }
    }
    Timer {
        id: restart
        interval: 1000
        onTriggered: {
            interval = 1000
            pipe.running = true
        }
    }
}
