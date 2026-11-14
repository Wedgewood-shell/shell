pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property string captureStage: "kind"      // "kind" | "scope" | "window"
    property string captureKind: ""
    property int recSecs: -1                   // -1 = not recording
    readonly property bool recording: recSecs >= 0

    Process {
        id: recPoll
        command: ["sh", "-c",
            "f=\"${XDG_RUNTIME_DIR:-/tmp}/capture-menu/recording.pid\"; if [ -f \"$f\" ] && kill -0 \"$(cat \"$f\")\" 2>/dev/null; then echo $(( $(date +%s) - $(stat -c %Y \"$f\") )); else echo -1; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.recSecs = parseInt(text.trim())
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!recPoll.running)
                         recPoll.running = true
    }
    function runCapture(kind, scope, target) {
        const delay = (scope === "window" && target) ? "0.2" : "0.5"
        const targetStr = (target !== undefined && target !== null) ? String(target) : ""
        Quickshell.execDetached(["sh", "-c", "sleep " + delay + "; exec \"$HOME/.local/bin/capture-run\" \"$1\" \"$2\" \"$3\"", "sh",
                                 kind, scope, targetStr])
        // optimistic: poll soon so the island picks up a new recording quickly
        recFast.restart()
    }
    Timer {
        id: recFast
        interval: 1200
        onTriggered: recPoll.running = true
    }
}
