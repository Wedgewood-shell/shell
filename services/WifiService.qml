pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- wifi menu ----
    property var wifiData: ({
                                current: {
                                    kind: "none"
                                },
                                networks: []
                            })
    property string wifiStage: "list"          // "list" | "password" | "connecting"
    property var wifiTarget: null
    property string wifiError: ""
    property string wifiPw: ""
    property string wifiResult: ""
    property bool wifiOpen: false
    Process {
        id: wifiScanProc
        command: ["sh", "-c", "exec \"$HOME/.local/bin/wifi-scan\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wifiData = JSON.parse(text)
                } catch (e) {}
            }
        }
    }
    Process {
        id: wifiRescan
        command: ["nmcli", "device", "wifi", "rescan"]
    }
    Timer {
        interval: 3000
        running: root.wifiOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!wifiScanProc.running && root.wifiStage !== "connecting")
                         wifiScanProc.running = true
    }
    onWifiOpenChanged: if (wifiOpen) {
                           wifiStage = "list"
                           wifiError = ""
                           wifiPw = ""
                           wifiResult = ""
                           wifiCloseTimer.stop()
                           wifiRescan.running = true
                       }
    Process {
        id: wifiConn
        command: ["sh", "-c", "exec \"$HOME/.local/bin/wifi-connect\" \"$1\"", "sh", root.wifiTarget
            ? root.wifiTarget.ssid : ""]
        environment: ({
                          "WIFI_PW": root.wifiPw
                      })
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim()
                root.wifiPw = ""
                if (r === "OK") {
                    root.wifiResult = "ok"
                    root.wifiStage = "list"
                    wifiScanProc.running = true
                    wifiCloseTimer.restart()
                } else {
                    root.wifiError = r.startsWith("ERR:") ? r.substring(4) : "Couldn't connect"
                    // secured network -> back to the password prompt; otherwise just show the error on the list
                    root.wifiStage = (root.wifiTarget && root.wifiTarget.secure && !root.wifiTarget.saved) ? "password" :
                                                                                                             "list"
                }
            }
        }
    }
    Timer {
        id: wifiCloseTimer
        interval: 1200
        onTriggered: {
            if (root.wifiOpen)
                root.closeRequested()
        }
    }
    Timer {
        id: wifiRefresh
        interval: 900
        onTriggered: wifiScanProc.running = true
    }
    property bool wifiScanning: false
    Timer {
        id: wifiScanDone
        interval: 2800
        onTriggered: {
            root.wifiScanning = false
            wifiScanProc.running = true
        }
    }
    function wifiRefreshNow() {
        wifiScanning = true
        wifiRescan.running = true
        wifiScanDone.restart()
    }
    function wifiDisconnect() {
        const dev = wifiData.wifi && wifiData.wifi.dev
        if (dev)
            Quickshell.execDetached(["nmcli", "device", "disconnect", dev])
        wifiRefresh.restart()
    }
    function wifiRadio(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        wifiRefresh.restart()
        if (on)
            Quickshell.execDetached(["sh", "-c", "sleep 1.5; nmcli device wifi rescan"])
    }
    function wifiConnect(net, pw) {
        wifiTarget = net
        wifiPw = pw || ""
        wifiError = ""
        wifiResult = ""
        wifiStage = "connecting"
        wifiConn.running = true
    }

    signal closeRequested
}
