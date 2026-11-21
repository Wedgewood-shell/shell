import QtQuick
import Quickshell
import ".."

Pill {
    id: pill
    // Page-load progress traced around the island's perimeter.
    property bool showProgress: true
    accent: Theme.border
    color: Theme.surface
    clip: true
    // The hosting window's devicePixelRatio; geometry is snapped to whole pixels.
    property real dpr: 1
    implicitHeight: Theme.px(Theme.barHeight, dpr)
    implicitWidth: Theme.pxEven(baseWidth, dpr)
    readonly property real baseWidth: {
        switch (IslandController.islandMode) {
        case "helium":
        case "voice":
            return Theme.islandHeliumWidth
        case "volume":
            return volume.implicitWidth + 36
        case "battery":
            return battery.implicitWidth + 36
        case "bluetooth":
            return bluetooth.implicitWidth + 36
        case "brightness":
            return brightness.implicitWidth + 36
        case "network":
            return network.implicitWidth + 36
        default:
            return Theme.islandBaseWidth
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    ClockView {
        id: clock
        anchors.fill: parent
    }
    HeliumView {
        id: helium
        anchors.fill: parent
    }
    VoiceView {
        id: voice
        anchors.fill: parent
    }
    Canvas {
        id: progressRing
        readonly property real lw: 2
        // Follows load progress; on completion it runs to 1 and the ring then fades
        // out in place (it never rewinds). A new load restarts from its own value.
        property bool animate: true
        property real drawn: 0
        Behavior on drawn {
            enabled: progressRing.animate
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Connections {
            target: HeliumService
            function onProgressChanged() {
                if (HeliumService.loading)
                    progressRing.drawn = HeliumService.progress
            }
            function onLoadingChanged() {
                if (HeliumService.loading) {
                    progressRing.animate = false
                    progressRing.drawn = HeliumService.progress
                    progressRing.animate = true
                } else {
                    progressRing.drawn = 1
                }
            }
        }
        anchors.fill: parent
        visible: pill.showProgress && opacity > 0
        opacity: HeliumService.active && HeliumService.loading ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
        onDrawnChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (drawn <= 0)
                return
            const o = lw / 2, w = width - lw, h = height - lw
            const r = Math.max(1, Math.min(Theme.closedRadius - o, w / 2, h / 2))
            const q = Math.PI * r / 2
            // clockwise from top centre
            const segs = [{
                    "len": w / 2 - r,
                    "pt": t => [o + w / 2 + t, o]
                }, {
                    "len": q,
                    "arc": [o + w - r, o + r, -Math.PI / 2]
                }, {
                    "len": h - 2 * r,
                    "pt": t => [o + w, o + r + t]
                }, {
                    "len": q,
                    "arc": [o + w - r, o + h - r, 0]
                }, {
                    "len": w - 2 * r,
                    "pt": t => [o + w - r - t, o + h]
                }, {
                    "len": q,
                    "arc": [o + r, o + h - r, Math.PI / 2]
                }, {
                    "len": h - 2 * r,
                    "pt": t => [o, o + h - r - t]
                }, {
                    "len": q,
                    "arc": [o + r, o + r, Math.PI]
                }, {
                    "len": w / 2 - r,
                    "pt": t => [o + r + t, o]
                }]
            let total = 0
            for (const s of segs)
                total += s.len
            let left = Math.min(1, drawn) * total
            ctx.strokeStyle = Theme.highlight
            ctx.lineWidth = lw
            ctx.lineCap = "butt"
            ctx.beginPath()
            ctx.moveTo(o + w / 2, o)
            for (const s of segs) {
                if (left <= 0)
                    break
                const d = Math.min(left, s.len)
                if (s.pt) {
                    const p = s.pt(d)
                    ctx.lineTo(p[0], p[1])
                } else {
                    const a0 = s.arc[2]
                    ctx.arc(s.arc[0], s.arc[1], r, a0, a0 + d / r, false)
                }
                left -= d
            }
            ctx.stroke()
        }
    }
    VolumeAlert {
        id: volume
        anchors.centerIn: parent
    }
    BatteryAlert {
        id: battery
        anchors.centerIn: parent
    }
    BluetoothAlert {
        id: bluetooth
        anchors.centerIn: parent
    }
    BrightnessAlert {
        id: brightness
        anchors.centerIn: parent
    }
    NetworkAlert {
        id: network
        anchors.centerIn: parent
    }
}
