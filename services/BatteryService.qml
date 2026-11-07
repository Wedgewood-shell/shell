pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // plug / unplug events
    property bool onBat: false
    property bool acKnown: false
    FileView {
        id: acFile
        path: Settings.acOnlinePath
        blockLoading: true
    }
    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            acFile.reload()
            const online = acFile.text().trim()
            if (online !== "0" && online !== "1")
                return
            const isBat = online === "0"
            if (root.acKnown && isBat !== root.onBat)
                root.changed()
            root.onBat = isBat
            root.acKnown = true
        }
    }

    property int battery: 0
    property string batteryStatus: ""
    readonly property bool plugged: acKnown ? !onBat : ["Charging", "Not charging", "Full"].includes(batteryStatus)
    readonly property bool charging: plugged && batteryStatus === "Charging"
    signal changed
    Process {
        id: poll
        command: ["sh", "-c", 'cat "$1/capacity" "$1/status"', "sh", Settings.batteryPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 2)
                    return
                root.battery = Number(lines[0])
                root.batteryStatus = lines[1].trim()
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
    function batteryGlyph(frac) {
        const icons = ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
        return icons[Math.max(0, Math.min(4, Math.round(frac * 4)))]
    }

    function batteryIcon() {
        const icons = ["", "", "", "", ""]
        return icons[Math.min(4, Math.floor(battery / 20))]
    }
}
