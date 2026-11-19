pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property string captureStage: "scope"   // "scope" (mode row + tiles) | "window" | "screen" (lists)
    property string captureKind: "screenshot" // "screenshot" | "video", toggled with Tab
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
    // Recordings start through runCapture (which polls soon via recFast), so
    // only the elapsed-time display needs fast polling.
    Timer {
        interval: root.recording ? 1000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!recPoll.running)
                         recPoll.running = true
    }
    // A capture waits until the menu has fully shrunk back and its surface has
    // unmapped (launcherMapped goes false), then a couple of frames for the compositor to
    // present the frame without it, so the menu never shows up in the shot.
    property var pending: null
    function runCapture(kind, scope, target) {
        pending = {
            kind: kind,
            scope: scope,
            target: (target !== undefined && target !== null) ? String(target) : ""
        }
        settle.stop()
        if (menuGone())
            settle.start()
        giveUp.restart()
    }
    function menuGone() {
        return !OverlayController.launcherOpen && !OverlayController.launcherBusy && !OverlayController.launcherMapped
    }
    function fire() {
        giveUp.stop()
        settle.stop()
        const p = pending
        pending = null
        if (!p)
            return
        Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/capture-run\" \"$1\" \"$2\" \"$3\"", "sh", p.kind, p.scope, p.target])
        // optimistic: poll soon so the island picks up a new recording quickly
        recFast.restart()
    }
    Connections {
        target: OverlayController
        function onLauncherMappedChanged() {
            if (root.pending && root.menuGone())
                settle.restart()
        }
        function onLauncherBusyChanged() {
            if (root.pending && root.menuGone())
                settle.restart()
        }
    }
    Timer {
        id: settle
        interval: 120
        onTriggered: root.fire()
    }
    // Never hang a capture on a menu that doesn't report back.
    Timer {
        id: giveUp
        interval: 2000
        onTriggered: root.fire()
    }
    Timer {
        id: recFast
        interval: 1200
        onTriggered: recPoll.running = true
    }
}
