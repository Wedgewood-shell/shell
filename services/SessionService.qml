pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- session / power menu ----
    property string sessionStage: "main"       // "main" | "reboot"
    function runSession(act) {
        const cmds = {
            exit: "niri msg action quit",
            sleep: "systemctl suspend",
            lock: "swaylock",
            shutdown: "systemctl poweroff",
            restart: "systemctl reboot",
            firmware: "systemctl reboot --firmware-setup"
        }
        if (!cmds[act])
            return
        Quickshell.execDetached(["sh", "-c", "sleep 0.45; exec " + cmds[act]])
    }
}
