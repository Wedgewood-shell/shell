pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // ---- brightness ----
    property real brightness: 0
    property real maxBrightness: 1
    property bool briKnown: false
    FileView {
        id: briFile
        path: Settings.backlightPath + "/brightness"
        blockAllReads: true
    }
    FileView {
        id: briMax
        path: Settings.backlightPath + "/max_brightness"
        blockAllReads: true
    }
    // Event-driven: re-read only when the kernel reports a backlight change.
    function refresh() {
        briFile.reload()
        const v = Number(briFile.text().trim())
        if (root.maxBrightness <= 1) {
            briMax.reload()
            root.maxBrightness = Number(briMax.text().trim()) || 1
        }
        if (root.briKnown && v !== root.brightness)
            root.changed()
        root.brightness = v
        root.briKnown = true
    }
    Component.onCompleted: refresh()
    Connections {
        target: UeventService
        function onBacklight() {
            root.refresh()
        }
    }
    readonly property real briFrac: Math.min(1, brightness / maxBrightness)

    signal changed
}
