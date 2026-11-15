pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- displays ----
    property string displayStage: "main"       // "main" | "extend"
    property string newDisplayName: ""
    property var knownOutputs: null
    property int externalCount: 0                // currently connected external outputs
    readonly property bool noExternal: externalCount === 0 && newDisplayName === ""
    property real displayQuietUntil: 0
    Process {
        id: outPoll
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let o
                try {
                    o = JSON.parse(text)
                } catch (e) {
                    return
                }
                const names = Object.keys(o)
                root.externalCount = names.filter(n => !/^(eDP|LVDS|DSI)/.test(n)).length
                const prev = root.knownOutputs
                root.knownOutputs = names
                if (prev === null)
                    return
                if (Date.now() < root.displayQuietUntil)
                    // we caused this change ourselves
                    return
                for (const n of names) {
                    if (prev.indexOf(n) >= 0 || /^(eDP|LVDS|DSI)/.test(n))
                        continue
                    const m = ((o[n].make || "") + " " + (o[n].model || "")).trim()
                    root.newDisplayName = m ? m + " (" + n + ")" : n
                    root.displayConnected()
                    return
                }
            }
        }
    }
    // Query niri when the Wayland output list changes; the slow poll catches
    // outputs niri leaves disabled (no wl_output is advertised for them).
    Connections {
        target: Quickshell
        function onScreensChanged() {
            outSoon.restart()
        }
    }
    Timer {
        id: outSoon
        interval: 300
        onTriggered: if (!outPoll.running)
                         outPoll.running = true
                     else
                         outSoon.restart()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: outSoon.restart()
    }
    function runDisplayLayout(args) {
        displayQuietUntil = Date.now() + 10000
        Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec \"$HOME/.local/bin/display-layout\" \"$@\"", "sh"].concat(
                                    args))
    }
    signal displayConnected
}
