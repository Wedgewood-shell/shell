import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    tiles: true
    title: "Power profile"
    glyph: "\uf0e7"

    function filter(q) {
        return [
                    {
                        name: "Performance",
                        label: "Performance",
                        sub: "",
                        glyph: "\uf0e7",
                        tint: Theme.warning,
                        profile: "performance"
                    },
                    {
                        name: "Balanced",
                        label: "Balanced",
                        sub: "",
                        glyph: "\uf24e",
                        tint: Theme.success,
                        profile: "balanced"
                    },
                    {
                        name: "Power saver",
                        label: "Power saver",
                        sub: "",
                        glyph: "\uf06c",
                        tint: "#a6da95",
                        profile: "power-saver"
                    }
                ]
    }
    function initialIndex() {
        return Math.max(0, results.findIndex(r => r.profile === SystemService.profile))
    }
    function activate(item) {
        if (!item)
            return
        OverlayController.launcherOpen = false
        SystemService.setProfile(item.profile)
        return
    }
    function handleKey(key) {
        return false
    }
}
