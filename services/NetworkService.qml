pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import Quickshell.Networking

Singleton {
    id: root
    // ---- network ----
    readonly property string netKind: {
        const devs = Networking.devices.values
        for (const d of devs)
            if (d.connected && d.type === DeviceType.Wifi)
                return "wifi"
        for (const d of devs)
            if (d.connected && d.type === DeviceType.Wired)
                return "eth"
        return "none"
    }
    // Live state for the bar icon (updated by the poll below).
    property int netSignal: 0
    property bool netHotspot: false
    // NetworkManager connectivity: full | limited | portal | none | unknown
    property string connectivity: "unknown"
    readonly property bool noInternet: netKind !== "none" && (connectivity === "limited" || connectivity === "portal")
    readonly property string iconKind: netKind === "none" ? "none" : netHotspot ? "hotspot" : netKind
    readonly property int signalLevel: netSignal < 35 ? 1 : netSignal < 65 ? 2 : 3
    Process {
        id: connPoll
        command: ["nmcli", "-g", "CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: root.connectivity = text.trim() || "unknown"
        }
    }
    // Refresh on NetworkManager activity instead of polling: `nmcli monitor`
    // prints a line for connectivity, device and connection changes.
    Process {
        id: nmMonitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: refreshSoon.restart()
        }
        onExited: nmRestart.start()
    }
    Timer {
        id: nmRestart
        interval: 5000
        onTriggered: {
            nmMonitor.running = true
            refreshSoon.restart()
        }
    }
    // Coalesce bursts of monitor output into one refresh.
    Timer {
        id: refreshSoon
        interval: 400
        onTriggered: root.refresh()
    }
    function refresh() {
        if (!connPoll.running)
            connPoll.running = true
        if (!netPoll.running)
            netPoll.running = true
        else
            refreshSoon.restart()
    }
    // Signal strength changes are not reported by `nmcli monitor`.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    readonly property string netIcon: netKind === "wifi" ? Theme.cp(0xF0928) : netKind === "eth" ? Theme.cp(0xF0200) : Theme.cp(0xF092D)

    // ---- network events (wifi / ethernet connect + disconnect) ----
    property string netEvKind: "none"          // "wifi" | "eth" | "none"
    property string netEvName: ""
    property int netEvSignal: 0
    property string netEvPrev: ""
    property bool netEvHotspot: false
    property string netKey: ""
    property string netPrevLabel: ""
    property bool netKnown: false
    Process {
        id: netPoll
        command: [Quickshell.shellDir + "/scripts/netinfo.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n---\n")
                const extra = (parts[2] || "").trim().split("\n")
                const metered = (extra[0] || "").trim(), gateway = (extra[1] || "").trim()
                const conns = (parts[0] || "").split("\n")
                const eth = conns.some(l => l.startsWith("802-3-ethernet:"))
                let ssid = "", sig = 0
                for (const l of (parts[1] || "").split("\n")) {
                    const m = l.match(/^yes:(\d+):(.*)$/)
                    if (m) {
                        sig = parseInt(m[1])
                        ssid = m[2].replace(/\\:/g, ":")
                        break
                    }
                }
                const wifi = ssid !== ""
                const tether = conns.some(l => l.startsWith("bluetooth:"))
                const hotspot = tether || (wifi && !eth && (metered.startsWith("yes") || gateway.startsWith("172.20.10.") || /iphone|ipad|galaxy|pixel|android|oneplus|xiaomi|redmi|poco|oppo|vivo|realme|huawei|honor|hotspot|\bphone\b/i.test(ssid)))
                root.netSignal = sig
                root.netHotspot = hotspot
                const kind = eth ? "eth" : wifi ? "wifi" : "none"
                const name = eth ? "Ethernet" : ssid
                const key = kind + ":" + name
                const label = kind === "none" ? "" : name
                if (root.netKnown && key !== root.netKey) {
                    root.netEvKind = kind
                    root.netEvName = name
                    root.netEvSignal = sig
                    root.netEvPrev = root.netPrevLabel
                    root.netEvHotspot = hotspot
                    root.changed()
                }
                root.netKey = key
                root.netPrevLabel = label
                root.netKnown = true
            }
        }
    }
    function netGlyph(kind, signal) {
        if (kind === "hotspot")
            return "\uf10b"
        if (kind === "eth")
            return Theme.cp(0xF0200)
        if (kind === "none")
            return Theme.cp(0xF092D)
        return signal < 30 ? Theme.cp(0xF091F) : signal < 55 ? Theme.cp(0xF0922) : signal < 80 ? Theme.cp(0xF0925) : Theme.cp(0xF0928)
    }

    signal changed
}
