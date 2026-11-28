pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property var data: null
    property string readError: ""
    property string actionError: ""

    onOpenChanged: {
        actionError = ""
        events.running = open
        if (open) {
            data = null
            readError = ""
            refresh.restart()
        }
    }

    // Both the current routes and stream moves use the server's PulseAudio IDs.
    // On pipewire-pulse, WirePlumber handles saving the target for future streams.
    Process {
        id: events
        command: ["pactl", "subscribe"]
        onStarted: refresh.restart()
        onExited: if (root.open) reconnect.start()
        stdout: SplitParser {
            onRead: line => {
                // Ignore client events from our own queries.
                if (/ on (sink|source|sink-input|source-output|server|card) #/.test(line))
                    refresh.start()
            }
        }
        environment: ({ LC_ALL: "C" })
    }
    Timer {
        id: reconnect
        interval: 1500
        onTriggered: {
            if (!root.open)
                return
            events.running = true
            refresh.start()
        }
    }
    Timer {
        id: refresh
        interval: 100
        onTriggered: {
            if (!root.open)
                return
            if (snapshot.running)
                restart()
            else
                snapshot.running = true
        }
    }
    Process {
        id: snapshot
        command: ["sh", "-c", "printf '[' && pactl -f json info && printf ',' && pactl -f json list && printf ']'"]
        stdout: StdioCollector { id: response }
        onExited: code => {
            if (!root.open)
                return
            if (code === 0) {
                try {
                    const [info, lists] = JSON.parse(response.text)
                    root.data = Object.assign({ info }, lists)
                    root.readError = ""
                    return
                } catch (e) {}
            }
            root.data = null
            root.readError = "Audio server unavailable. Check that pipewire-pulse and pactl are installed."
        }
    }

    function run(args) {
        if (!open || action.running || !data)
            return
        actionError = ""
        action.command = ["pactl", ...args]
        action.running = true
    }
    Process {
        id: action
        stderr: StdioCollector { id: actionStderr }
        onExited: code => {
            if (code !== 0)
                root.actionError = actionStderr.text.trim() || "Could not change the audio setting."
            if (root.open)
                refresh.restart()
        }
    }
}
