pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- launcher ----
    property bool launcherOpen: false
    property bool launcherBusy: false   // true while the launcher pill is open or still shrinking back
    property bool launcherMapped: false // the menu surface is still on screen (it unmaps after the hand-off)
    property string launcherScreen: ""
    property var islandWidths: ({})          // per-screen, keyed by output name
    function setIslandWidth(name, w) {
        islandWidths = Object.assign({}, islandWidths, {
                                         [name]: w
                                     })
    }
    readonly property real islandWidth: islandWidths[launcherScreen] !== undefined ? islandWidths[launcherScreen] : 300
    property string launcherMode: "apps"      // "apps" | "windows" | "capture"
    property string pendingMode: "apps"
    Process {
        id: focusedOut
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.launcherScreen = JSON.parse(text).name
                } catch (e) {}
                root.launcherMode = root.pendingMode
                root.resetStages()
                if (root.pendingMode === "windows")
                    NiriService.refreshTabs()
                root.launcherOpen = true
            }
        }
    }
    signal dismissHud
    function openLauncher(mode) {
        if (launcherOpen && launcherMode === mode) {
            launcherOpen = false
            return
        }
        dismissHud()
        if (launcherOpen) {            // switch mode in place
            launcherMode = mode
            resetStages()
            if (mode === "windows")
                NiriService.refreshTabs()
            return
        }
        pendingMode = mode
        focusedOut.running = true
    }
    function toggleLauncher() {
        openLauncher("apps")
    }

    function resetStages() {
        CaptureService.captureStage = "scope"
        DisplayService.displayStage = "main"
        SessionService.sessionStage = "main"
        WifiService.wifiStage = "list"
    }
    function syncMenus() {
        WifiService.wifiOpen = launcherOpen && launcherMode === "wifi"
        if (!launcherOpen)
            DisplayService.newDisplayName = ""
    }
    onLauncherOpenChanged: syncMenus()
    onLauncherModeChanged: syncMenus()
}
