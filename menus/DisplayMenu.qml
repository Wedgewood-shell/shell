import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    tiles: true
    title: DisplayService.displayStage === "extend" ? "Extend — which side?" : (DisplayService.newDisplayName
                                                                                ? "New display · "
                                                                                  + DisplayService.newDisplayName :
                                                                                  DisplayService.noExternal
                                                                                  ? "No external display detected" :
                                                                                    "Display layout")
    glyph: "\uf108"
    Connections {
        target: DisplayService
        function onDisplayStageChanged() {
            page.refresh()
        }
        function onNoExternalChanged() {
            page.refresh()
        }
    }
    function filter(q) {
        if (DisplayService.displayStage === "extend")
            return [
                        {
                            name: "Extend left",
                            label: "Left",
                            glyph: "\uf060",
                            dir: "left"
                        },
                        {
                            name: "Extend right",
                            label: "Right",
                            glyph: "\uf061",
                            dir: "right"
                        },
                        {
                            name: "Extend up",
                            label: "Up",
                            glyph: "\uf062",
                            dir: "up"
                        },
                        {
                            name: "Extend down",
                            label: "Down",
                            glyph: "\uf063",
                            dir: "down"
                        }
                    ]
        if (DisplayService.noExternal)
            return [
                        {
                            name: "Internal only",
                            label: "Internal",
                            glyph: "\uf109",
                            tint: Theme.warning,
                            act: "internal",
                            none: true
                        }
                    ]
        return [
                    {
                        name: "Previous layout",
                        label: "Previous",
                        glyph: "\uf0e2",
                        tint: Theme.muted,
                        act: "previous"
                    },
                    {
                        name: "Duplicate",
                        label: "Duplicate",
                        glyph: "\uf24d",
                        act: "duplicate"
                    },
                    {
                        name: "Extend",
                        label: "Extend",
                        glyph: "\uf07e",
                        act: "extend"
                    },
                    {
                        name: "External only",
                        label: "External",
                        glyph: "\uf108",
                        tint: Theme.success,
                        act: "external"
                    },
                    {
                        name: "Internal only",
                        label: "Internal",
                        glyph: "\uf109",
                        tint: Theme.warning,
                        act: "internal"
                    }
                ]
    }
    function initialIndex() {
        return DisplayService.displayStage === "main" ? (DisplayService.noExternal ? 0 : 2) : 1
    }
    function activate(item) {
        if (!item)
            return
        if (item.act === "extend") {
            DisplayService.displayStage = "extend"
            page.refresh()
            return
        }
        OverlayController.launcherOpen = false
        if (item.none)
            // already internal-only, nothing to change
            return
        DisplayService.runDisplayLayout(item.dir ? ["extend", item.dir] : [item.act])
        return
    }
    function handleKey(key) {
        if ((key === Qt.Key_Escape || key === Qt.Key_Backspace) && DisplayService.displayStage !== "main") {
            DisplayService.displayStage = "main"
            return true
        }
        return false
    }
}
