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
        blockAllReads: true
    }
    function refreshAc() {
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

    property int battery: 0
    property string batteryStatus: ""
    readonly property bool plugged: acKnown ? !onBat : ["Charging", "Not charging", "Full"].includes(batteryStatus)
    readonly property bool charging: plugged && batteryStatus === "Charging"
    signal changed
    FileView {
        id: capFile
        path: Settings.batteryPath + "/capacity"
        blockAllReads: true
    }
    FileView {
        id: statusFile
        path: Settings.batteryPath + "/status"
        blockAllReads: true
    }
    function refreshBattery() {
        capFile.reload()
        statusFile.reload()
        const capacity = capFile.text().trim()
        const status = statusFile.text().trim()
        if (capacity === "" || status === "")
            return
        root.battery = Number(capacity)
        root.batteryStatus = status
    }
    function refresh() {
        refreshAc()
        refreshBattery()
    }
    Component.onCompleted: refresh()
    // Plug/unplug and charge-state changes arrive as power_supply uevents.
    Connections {
        target: UeventService
        function onPowerSupply() {
            root.refresh()
        }
    }
    // Capacity creeps between uevents; a slow in-process read keeps it current.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
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
