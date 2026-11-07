import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    tiles: true
    title: CaptureService.captureStage === "kind" ? "Capture" : (CaptureService.captureKind === "video" ? "Record — what to include?" :
                                                                                                          "Screenshot — what to include?")

    glyph: "\uf030"
    Connections {
        target: CaptureService
        function onCaptureStageChanged() {
            page.refresh()
        }
        function onRecordingChanged() {
            page.refresh()
        }
    }
    function filter(q) {
        if (CaptureService.captureStage === "kind") {
            const items = []
            if (CaptureService.recording)
                items.push({
                               name: "Stop recording",
                               label: "Stop",
                               sub: "recording in progress",
                               glyph: "\uf04d",
                               tint: Theme.danger,
                               cap: "stop"
                           })
            items.push({
                           name: "Take a screenshot",
                           label: "Screenshot",
                           sub: "annotate with satty",
                           glyph: "\uf030",
                           cap: "screenshot"
                       })
            if (!CaptureService.recording)
                items.push({
                               name: "Record a video",
                               label: "Record",
                               sub: "mp4 · wf-recorder",
                               glyph: "\uf03d",
                               tint: Theme.danger,
                               cap: "video"
                           })
            return items
        }
        return [
                    {
                        name: "Entire screen",
                        label: "Screen",
                        sub: "",
                        glyph: "\uf108",
                        scope: "screen"
                    },
                    {
                        name: "Select an area",
                        label: "Area",
                        sub: "drag a region",
                        glyph: "\uf125",
                        scope: "area"
                    },
                    {
                        name: "Select a window",
                        label: "Window",
                        sub: "drag around it",
                        glyph: "\uf2d0",
                        scope: "window"
                    }
                ]
    }
    function initialIndex() {
        return 0
    }
    function activate(item) {
        if (!item)
            return
        if (item.cap) {
            if (item.cap === "stop") {
                OverlayController.launcherOpen = false
                CaptureService.runCapture("stop", "")
                return
            }
            CaptureService.captureKind = item.cap
            CaptureService.captureStage = "scope"
            page.refresh()
        } else {
            OverlayController.launcherOpen = false
            CaptureService.runCapture(CaptureService.captureKind, item.scope)
        }
        return
    }
    function handleKey(key) {
        if ((key === Qt.Key_Escape || key === Qt.Key_Backspace) && CaptureService.captureStage !== "kind") {
            CaptureService.captureStage = "kind"
            return true
        }
        return false
    }
}
