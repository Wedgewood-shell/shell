import QtQuick
import Quickshell
import QtQuick.Effects
import ".."

MenuPage {
    id: page
    tiles: CaptureService.captureStage !== "window"
    title: {
        if (CaptureService.captureStage === "kind")
            return "Capture"
        if (CaptureService.captureStage === "scope")
            return CaptureService.captureKind === "video" ? "Record — what to include?" : "Screenshot — what to include?"
        return "Screenshot — select a window"
    }

    glyph: CaptureService.captureStage === "window" ? "\uf2d0" : "\uf030"
    maxRows: CaptureService.captureStage === "window" ? 4 : 7
    contentWidth: tiles ? Math.max(340, tilesWidth + 44) : 620
    contentHeight: {
        if (tiles)
            return 172
        if (page.results.length === 0)
            return 110
        return 56 + Math.min(page.results.length, maxRows) * 46 + 6
    }

    // Live preview below the pill, sized to the window's aspect ratio.
    readonly property bool showPreview: CaptureService.captureStage === "window" && page.results.length > 0
    readonly property size previewMax: Qt.size(620, 360)
    detailHeight: previewMax.height
    // Kept through the window stage and briefly after leaving it, so the preview
    // fades out instead of popping (also keeps the surface size steady meanwhile).
    property bool keepPreview: CaptureService.captureStage === "window"
    detail: keepPreview ? previewComponent : null
    Timer {
        id: previewLinger
        interval: 250
        onTriggered: page.keepPreview = CaptureService.captureStage === "window"
    }

    readonly property var currentWin: (page.results && page.results.length > 0 && page.currentIndex >= 0 && page.currentIndex < page.results.length)
                                      ? page.results[page.currentIndex] : null
    readonly property int currentWindowId: currentWin && currentWin.id !== undefined ? currentWin.id : -1

    Connections {
        target: CaptureService
        function onCaptureStageChanged() {
            if (CaptureService.captureStage === "window") {
                previewLinger.stop()
                page.keepPreview = true
            } else {
                previewLinger.restart()
            }
            page.clearQuery()
            page.refresh()
        }
        function onRecordingChanged() {
            page.refresh()
        }
    }

    Connections {
        target: NiriService
        function onWindowDataChanged() {
            if (CaptureService.captureStage === "window")
                page.refresh()
        }
    }

    Connections {
        target: OverlayController
        function onLauncherOpenChanged() {
            if (!OverlayController.launcherOpen)
                resetAfterClose.restart()
            else
                resetAfterClose.stop()
        }
    }

    // Reset once the collapse has finished, so neither the list nor the preview
    // changes while they are fading out.
    Timer {
        id: resetAfterClose
        interval: 450
        onTriggered: if (!OverlayController.launcherOpen) {
            CaptureService.captureStage = "kind"
            CaptureService.captureKind = ""
        }
    }

    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return e && e.icon ? e.icon : (appId || "")
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
        if (CaptureService.captureStage === "scope") {
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
                    sub: CaptureService.captureKind === "video" ? "drag around it" : "choose from list",
                    glyph: "\uf2d0",
                    scope: "window"
                }
            ]
        }

        // CaptureService.captureStage === "window"
        q = (q || "").trim().toLowerCase()
        const rank = text => {
            if (!text)
                return 0
            text = text.toLowerCase()
            if (text === q)
                return 4
            if (text.startsWith(q))
                return 3
            if (text.split(/[\s\-_.|:]+/).some(w => w.startsWith(q)))
                return 2
            return text.includes(q) ? 1 : 0
        }
        let items = NiriService.windowData.map(w => {
            const id = (w.app_id || "").toLowerCase()
            const entry = id ? DesktopEntries.heuristicLookup(w.app_id) : null
            const appRank = q ? Math.max(rank(w.app_id), rank(entry ? entry.name : "")) : 0
            const titleRank = q ? rank(w.title) : 0
            return {
                name: w.title,
                sub: w.app_id + "  ·  workspace " + w.ws + (w.focused ? "  ·  current" : ""),
                icon: page.iconFor(w.app_id),
                id: w.id,
                app_id: w.app_id,
                ws: w.ws,
                ts: w.ts,
                total: appRank > 0 ? 10 + appRank : titleRank
            }
        })
        if (q) {
            items = items.filter(i => i.total > 0)
            items.sort((a, b) => (b.total - a.total) || (b.ts - a.ts))
        } else {
            items.sort((a, b) => b.ts - a.ts)
        }
        return items
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
            return
        }
        if (item.scope) {
            if (item.scope === "window" && CaptureService.captureKind === "screenshot") {
                CaptureService.captureStage = "window"
                page.refresh()
                return
            }
            OverlayController.launcherOpen = false
            CaptureService.runCapture(CaptureService.captureKind, item.scope)
            return
        }
        if (item.id !== undefined) {
            OverlayController.launcherOpen = false
            CaptureService.runCapture("screenshot", "window", item.id)
            return
        }
    }

    function handleKey(key) {
        if (key === Qt.Key_Escape || key === Qt.Key_Backspace) {
            if (CaptureService.captureStage === "window") {
                if (key === Qt.Key_Backspace && query.length > 0)
                    return false
                CaptureService.captureStage = "scope"
                page.clearQuery()
                return true
            }
            if (CaptureService.captureStage === "scope") {
                CaptureService.captureStage = "kind"
                page.clearQuery()
                return true
            }
        }
        return false
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 68
        visible: CaptureService.captureStage === "window" && page.results.length === 0
        text: "No open windows match"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Component {
        id: previewComponent
        // Rounded clip for the stream. Fades with the stream and with the menu.
        Item {
            id: preview
            readonly property var stream: live.item
            readonly property bool shown: stream !== null && stream.ready && OverlayController.launcherOpen && page.showPreview
            readonly property size source: stream && stream.sourceSize.width > 0 ? stream.sourceSize : Qt.size(16, 9)
            readonly property real fit: Math.min(page.previewMax.width / source.width, page.previewMax.height / source.height)
            width: Math.round(source.width * fit)
            height: Math.round(source.height * fit)
            opacity: shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Item {
                id: frame
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    maskSource: roundMask
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#0b0d14"
                }
                // One PipeWire stream for the highlighted window; retargeted on
                // selection change, stopped when the picker closes.
                Loader {
                    id: live
                    anchors.fill: parent
                    source: Quickshell.shellDir + "/native/build/LiveWindow.qml"
                    onLoaded: item.active = Qt.binding(() => OverlayController.launcherOpen && page.showPreview)
                    Binding {
                        target: live.item
                        property: "windowId"
                        value: page.currentWindowId
                        when: live.item !== null
                    }
                }
            }
            Rectangle {
                id: roundMask
                anchors.fill: parent
                radius: Theme.openRadius
                visible: false
                layer.enabled: true
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.openRadius
                color: "transparent"
                border.width: 1
                border.color: Theme.border
            }
            MouseArea {
                anchors.fill: parent
                enabled: preview.shown
                cursorShape: Qt.PointingHandCursor
                onClicked: if (page.currentWin)
                    page.activate(page.currentWin)
            }
        }
    }
}
