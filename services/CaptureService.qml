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

    property string previewPath: ""
    property int previewWindowId: -1
    property int previewTargetId: -1
    property int previewVersion: 0

    Process {
        id: previewProc
        command: ["python3", Quickshell.shellDir + "/scripts/window-preview.py", String(root.previewTargetId)]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p.length > 0 && root.previewTargetId > 0) {
                    root.previewPath = p
                    root.previewWindowId = root.previewTargetId
                    root.previewVersion++
                }
            }
        }
        onExited: {
            if (root.previewTargetId > 0 && root.previewTargetId !== root.previewWindowId) {
                previewProc.command = ["python3", Quickshell.shellDir + "/scripts/window-preview.py", String(root.previewTargetId)]
                previewProc.running = true
            }
        }
    }

    function requestPreview(windowId) {
        if (!windowId || windowId <= 0) {
            previewTargetId = -1
            previewWindowId = -1
            previewPath = ""
            return
        }
        if (windowId === previewWindowId && previewPath !== "")
            return
        previewTargetId = windowId
        if (!previewProc.running) {
            previewProc.command = ["python3", Quickshell.shellDir + "/scripts/window-preview.py", String(windowId)]
            previewProc.running = true
        }
    }

    function prewarmPreviews(ids) {
        if (!ids || ids.length === 0)
            return
        const args = ["python3", Quickshell.shellDir + "/scripts/window-preview.py", "--all"]
        for (let i = 0; i < ids.length; i++)
            args.push(String(ids[i]))
        Quickshell.execDetached(args)
    }

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
