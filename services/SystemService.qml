pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- polled system stats ----
    property int cpuUsage: 0
    property real tempC: 0
    property string profile: "balanced"
    property var lastCpu: null

    readonly property string profileIcon: profile === "performance" ? "" : profile === "power-saver" ? "" : ""

    Process {
        id: poll
        command: ["sh", "-c", "head -1 /proc/stat; cat " + Settings.cpuTemperatureGlob + " | head -1; " + "powerprofilesctl get 2>/dev/null || echo balanced"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                if (l.length < 3)
                    return
                const v = l[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = v[3] + v[4]
                const total = v.reduce((a, b) => a + b, 0)
                if (root.lastCpu) {
                    const dt = total - root.lastCpu.total, di = idle - root.lastCpu.idle
                    if (dt > 0)
                        root.cpuUsage = Math.round(100 * (dt - di) / dt)
                }
                root.lastCpu = {
                    total: total,
                    idle: idle
                }
                root.tempC = Math.round(Number(l[1]) / 1000)
                root.profile = l[2].trim()
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running)
            poll.running = true
    }

    function setProfile(p) {
        profile = p
        // optimistic; the poll confirms it
        Quickshell.execDetached(["powerprofilesctl", "set", p])
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property string clockText: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
}
