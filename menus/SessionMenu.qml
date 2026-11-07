import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    tiles: true
    title: SessionService.sessionStage === "reboot" ? "Reboot — which kind?" : "Power"
    glyph: "\uf011"
    Connections {
        target: SessionService
        function onSessionStageChanged() {
            page.refresh()
        }
    }
    function filter(q) {
        if (SessionService.sessionStage === "reboot")
            return [
                        {
                            name: "Restart",
                            label: "Restart",
                            glyph: "\uf021",
                            tint: Theme.warning,
                            act: "restart"
                        },
                        {
                            name: "Firmware restart",
                            label: "Firmware",
                            glyph: "\uf2db",
                            tint: "#c7a0ff",
                            act: "firmware"
                        }
                    ]
        return [
                    {
                        name: "Exit",
                        label: "Exit",
                        glyph: "\uf08b",
                        tint: "#9aa6c8",
                        act: "exit"
                    },
                    {
                        name: "Sleep",
                        label: "Sleep",
                        glyph: "\uf186",
                        tint: Theme.highlight,
                        act: "sleep"
                    },
                    {
                        name: "Lock",
                        label: "Lock",
                        glyph: "\uf023",
                        tint: "#c7d2ff",
                        act: "lock"
                    },
                    {
                        name: "Shutdown",
                        label: "Shutdown",
                        glyph: "\uf011",
                        tint: Theme.danger,
                        act: "shutdown"
                    },
                    {
                        name: "Reboot",
                        label: "Reboot",
                        glyph: "\uf2f1",
                        tint: Theme.warning,
                        act: "reboot"
                    }
                ]
    }
    function initialIndex() {
        return SessionService.sessionStage === "main" ? 1 : 0
    }
    function activate(item) {
        if (!item)
            return
        if (item.act === "reboot") {
            SessionService.sessionStage = "reboot"
            page.refresh()
            return
        }
        OverlayController.launcherOpen = false
        SessionService.runSession(item.act)
        return
    }
    function handleKey(key) {
        if ((key === Qt.Key_Escape || key === Qt.Key_Backspace) && SessionService.sessionStage !== "main") {
            SessionService.sessionStage = "main"
            return true
        }
        return false
    }
}
