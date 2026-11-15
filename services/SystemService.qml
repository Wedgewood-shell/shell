pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."

Singleton {
    id: root
    // ---- polled system stats ----
    property int cpuUsage: 0
    property real tempC: 0
    // power-profiles-daemon over D-Bus: updates on change, no polling.
    property string profile: profileName(PowerProfiles.profile)
    property var lastCpu: null
    property string tempPath: ""

    function profileName(p) {
        return p === PowerProfile.Performance ? "performance" : p === PowerProfile.PowerSaver ? "power-saver" : "balanced"
    }
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            root.profile = root.profileName(PowerProfiles.profile)
        }
    }

    readonly property string profileIcon: profile === "performance" ? "" : profile === "power-saver" ? "" : ""

    // Resolve the hwmon glob once; the stats are then read in-process.
    Process {
        running: true
        command: ["sh", "-c", "for f in " + Settings.cpuTemperatureGlob + "; do echo \"$f\"; break; done"]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = text.trim()
        }
    }
    FileView {
        id: statFile
        path: "/proc/stat"
        blockAllReads: true
    }
    FileView {
        id: tempFile
        path: root.tempPath
        blockAllReads: true
    }
    function sample() {
        statFile.reload()
        const v = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        if (v.length >= 5) {
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
        }
        if (root.tempPath !== "") {
            tempFile.reload()
            const t = Number(tempFile.text().trim())
            if (t > 0)
                root.tempC = Math.round(t / 1000)
        }
    }
    // Each changed value redraws the bar (ending panel self-refresh), so sample
    // less often on battery.
    Timer {
        interval: BatteryService.onBat ? 5000 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    function setProfile(p) {
        profile = p
        // optimistic; PowerProfiles.onProfileChanged confirms it
        Quickshell.execDetached(["powerprofilesctl", "set", p])
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property string clockText: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
}
