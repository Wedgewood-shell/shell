import QtQuick
import Quickshell
import QtQuick.Effects
import ".."

// Single-level capture menu. The top row picks the mode (Snap / Record, toggled
// with Tab); the tiles below pick what to capture. "Window" in photo mode opens
// a searchable window list with a live preview.
MenuPage {
    id: page
    readonly property bool inWindowList: CaptureService.captureStage === "window"
    readonly property bool videoMode: CaptureService.captureKind === "video"
    readonly property bool stopping: videoMode && CaptureService.recording

    tiles: !inWindowList
    showHeader: inWindowList
    title: "Select a window"
    glyph: "\uf2d0"
    maxRows: 4
    tileY: 70
    contentWidth: tiles ? 380 : 620
    contentHeight: {
        if (tiles)
            return tileY + 104 + 14
        if (page.results.length === 0)
            return 110
        return 56 + Math.min(page.results.length, maxRows) * 46 + 6
    }

    // Top row. Fixed width so both buttons line up with the three tiles below.
    readonly property var modes: [
        {
            kind: "screenshot",
            label: "Snap",
            glyph: "\uf030",
            tint: Theme.highlight
        },
        {
            kind: "video",
            label: "Record",
            glyph: "\uf03d",
            tint: Theme.danger
        }
    ]
    Row {
        id: modeRow
        y: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        visible: !page.inWindowList
        Repeater {
            model: page.modes
            delegate: Rectangle {
                id: modeButton
                required property var modelData
                readonly property bool selected: CaptureService.captureKind === modelData.kind
                readonly property bool isStop: modelData.kind === "video" && CaptureService.recording
                readonly property color tint: isStop ? Theme.danger : modelData.tint
                width: 162
                height: 46
                radius: 14
                color: Qt.rgba(tint.r, tint.g, tint.b, selected ? 0.30 : 0.10)
                border.width: selected ? 2 : 1
                border.color: Qt.rgba(tint.r, tint.g, tint.b, selected ? 0.95 : 0.35)
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modeButton.isStop ? "\uf04d" : modeButton.modelData.glyph
                        color: modeButton.tint
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modeButton.isStop ? "Stop" : modeButton.modelData.label
                        color: modeButton.selected ? Theme.text : "#cdd5ee"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CaptureService.captureKind = modelData.kind
                }
            }
        }
    }

    // Live preview below the pill, sized to the window's aspect ratio.
    readonly property bool showPreview: inWindowList && page.results.length > 0
    readonly property size previewMax: Qt.size(620, 360)
    detailHeight: previewMax.height
    // Kept through the window list and briefly after leaving it, so the preview
    // fades out instead of popping (also keeps the surface size steady meanwhile).
    property bool keepPreview: inWindowList
    detail: keepPreview ? previewComponent : null
    Timer {
        id: previewLinger
        interval: 250
        onTriggered: page.keepPreview = page.inWindowList
    }

    readonly property var currentWin: (page.results && page.results.length > 0 && page.currentIndex >= 0 && page.currentIndex < page.results.length)
                                      ? page.results[page.currentIndex] : null
    readonly property int currentWindowId: currentWin && currentWin.id !== undefined ? currentWin.id : -1

    Connections {
        target: CaptureService
        function onCaptureStageChanged() {
            if (page.inWindowList) {
                previewLinger.stop()
                page.keepPreview = true
            } else {
                previewLinger.restart()
            }
            page.clearQuery()
            page.refresh()
        }
        function onCaptureKindChanged() {
            page.refresh()
        }
        function onRecordingChanged() {
            page.refresh()
        }
    }

    Connections {
        target: NiriService
        function onWindowDataChanged() {
            if (page.inWindowList)
                page.refresh()
        }
    }

    Connections {
        target: OverlayController
        function onLauncherOpenChanged() {
            if (OverlayController.launcherOpen) {
                resetAfterClose.stop()
                if (!page.inWindowList)
                    page.resetMode()
            } else {
                resetAfterClose.restart()
            }
        }
    }

    // Back to the tiles once the collapse has finished, so neither the list nor
    // the preview changes while they are fading out.
    Timer {
        id: resetAfterClose
        interval: 450
        onTriggered: if (!OverlayController.launcherOpen) {
            CaptureService.captureStage = "scope"
            page.resetMode()
        }
    }

    // Start in Record while a recording is running, so its Stop tile is ready.
    function resetMode() {
        CaptureService.captureKind = CaptureService.recording ? "video" : "screenshot"
    }

    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return e && e.icon ? e.icon : (appId || "")
    }

    function filter(q) {
        if (!inWindowList) {
            if (stopping)
                return [
                            {
                                name: "Stop recording",
                                label: "Stop",
                                glyph: "\uf04d",
                                tint: Theme.danger,
                                act: "stop"
                            }
                        ]
            return [
                        {
                            name: "Entire screen",
                            label: "Screen",
                            glyph: "\uf108",
                            scope: "screen"
                        },
                        {
                            name: "Select an area",
                            label: "Area",
                            glyph: "\uf125",
                            scope: "area"
                        },
                        {
                            name: "Select a window",
                            label: "Window",
                            glyph: "\uf2d0",
                            scope: "window"
                        }
                    ]
        }

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
            const entry = w.app_id ? DesktopEntries.heuristicLookup(w.app_id) : null
            const appRank = q ? Math.max(rank(w.app_id), rank(entry ? entry.name : "")) : 0
            const titleRank = q ? rank(w.title) : 0
            return {
                name: w.title,
                sub: w.app_id + "  ·  workspace " + w.ws + (w.focused ? "  ·  current" : ""),
                icon: page.iconFor(w.app_id),
                id: w.id,
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
        if (item.act === "stop") {
            OverlayController.launcherOpen = false
            CaptureService.runCapture("stop", "")
            return
        }
        if (item.scope === "window" && CaptureService.captureKind === "screenshot") {
            CaptureService.captureStage = "window"
            return
        }
        if (item.scope) {
            OverlayController.launcherOpen = false
            CaptureService.runCapture(CaptureService.captureKind, item.scope)
            return
        }
        if (item.id !== undefined) {
            OverlayController.launcherOpen = false
            CaptureService.runCapture("screenshot", "window", item.id)
        }
    }

    function handleKey(key) {
        if (inWindowList) {
            if (key === Qt.Key_Escape || (key === Qt.Key_Backspace && query.length === 0)) {
                CaptureService.captureStage = "scope"
                return true
            }
            return false
        }
        if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            CaptureService.captureKind = videoMode ? "screenshot" : "video"
            return true
        }
        return false
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 68
        visible: page.inWindowList && page.results.length === 0
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
