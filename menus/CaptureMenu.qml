import QtQuick
import Quickshell
import Quickshell.Widgets
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
        return 280 + Math.min(page.results.length, maxRows) * 46
    }

    readonly property var currentWin: (page.results && page.results.length > 0 && page.currentIndex >= 0 && page.currentIndex < page.results.length)
                                      ? page.results[page.currentIndex] : null
    readonly property int currentWindowId: currentWin && currentWin.id !== undefined ? currentWin.id : -1

    Connections {
        target: CaptureService
        function onCaptureStageChanged() {
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
            if (!OverlayController.launcherOpen) {
                CaptureService.captureStage = "kind"
                CaptureService.captureKind = ""
            }
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
            CaptureService.captureStage = "kind"
            return
        }
        if (item.id !== undefined) {
            OverlayController.launcherOpen = false
            CaptureService.runCapture("screenshot", "window", item.id)
            CaptureService.captureStage = "kind"
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

    Item {
        id: previewCard
        visible: CaptureService.captureStage === "window" && page.results.length > 0
        x: 14
        y: page.listY + Math.min(page.results.length, page.maxRows) * 46 + 10
        width: page.contentWidth - 28
        height: 200

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#181d2e"
            border.width: 1
            border.color: previewMouse.containsMouse ? Theme.highlight : "#28334f"
            clip: true

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !live.ready
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 36
                    source: page.currentWin ? Quickshell.iconPath(page.iconFor(page.currentWin.app_id), "application-x-executable") : ""
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.currentWin ? page.currentWin.name : ""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: previewCard.width - 40
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: live.status === Loader.Error ? "Live preview unavailable (build native/)" : live.item && live.item.error ? live.item.error : "Connecting to window…"
                    color: "#5a6585"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // One live PipeWire stream for the highlighted window only. It is
            // retargeted on selection change and stopped when the picker closes.
            Loader {
                id: live
                anchors.fill: parent
                anchors.margins: 8
                active: previewCard.visible
                source: Quickshell.shellDir + "/native/build/LiveWindow.qml"
                onLoaded: item.active = Qt.binding(() => OverlayController.launcherOpen && previewCard.visible)
                Binding {
                    target: live.item
                    property: "windowId"
                    value: page.currentWindowId
                    when: live.item !== null
                }
                readonly property bool ready: item !== null && item.ready
                opacity: ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                height: 22
                width: hintText.implicitWidth + 16
                radius: 11
                color: previewMouse.containsMouse ? "#2f3d66" : "#20283f"
                border.width: 1
                border.color: previewMouse.containsMouse ? Theme.highlight : "#354266"
                visible: live.ready

                Row {
                    id: hintText
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf030"
                        color: Theme.highlight
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Click or Enter to capture"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (page.currentWin)
                    page.activate(page.currentWin)
            }
        }
    }
}
