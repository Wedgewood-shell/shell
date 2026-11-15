import QtQuick
import ".."

// Battery glyph: a thick rounded body with a D-shaped terminal, filled from the left,
// and the percentage cut out of it with a halo in the icon colour (readable over
// both the fill and the empty part). Drawn at reference proportions (84 units tall)
// and vector-scaled to `bodyHeight`.
//
// Colour follows the power profile: yellow in power-saver, red when balanced and
// under 20 %, purple with a sweeping colour pulse in performance. A bolt (charging) or plug
// (plugged in, not charging) sits to the right.
Row {
    id: indicator
    property int percentage: BatteryService.battery
    property bool plugged: BatteryService.plugged
    property bool charging: BatteryService.charging
    property string profile: SystemService.profile
    property real bodyHeight: 23

    readonly property int level: Math.max(0, Math.min(100, percentage))
    readonly property bool performance: profile === "performance"
    readonly property color purple: "#c4a7ff"
    readonly property color ink: performance ? purple : profile === "power-saver" ? Theme.warning : level < 20 ? Theme.danger : Theme.foreground
    readonly property real s: bodyHeight / 84
    spacing: 3

    // Pulse phase, advanced only while the performance animation is visible.
    property real phase: 0
    NumberAnimation on phase {
        running: indicator.performance && indicator.visible
        from: 0
        to: Math.PI * 2
        duration: 2200
        loops: Animation.Infinite
    }

    Canvas {
        id: battery
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(172 * indicator.s)
        height: Math.ceil(84 * indicator.s)
        antialiasing: true
        property real level: indicator.level
        property color ink: indicator.ink
        property real phase: indicator.phase
        property bool wave: indicator.performance
        onLevelChanged: requestPaint()
        onInkChanged: requestPaint()
        onPhaseChanged: if (wave)
            requestPaint()
        onWaveChanged: requestPaint()
        onWidthChanged: requestPaint()
        onAvailableChanged: if (available)
            requestPaint()

        function roundRect(ctx, x, y, w, h, r) {
            r = Math.min(r, w / 2, h / 2)
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.arcTo(x + w, y, x + w, y + r, r)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x, y + h, x, y + h - r, r)
            ctx.lineTo(x, y + r)
            ctx.arcTo(x, y, x + r, y, r)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const s = indicator.s
            ctx.scale(s, s)
            // Keep the outline at least 1.4 px wide on screen.
            const stroke = Math.max(5, 1.4 / s)
            // Performance: a lighter band of purple sweeps across the whole icon.
            let paint = ink
            if (wave) {
                const t = phase / (Math.PI * 2)
                paint = ctx.createLinearGradient(-172 + 344 * t, 0, 344 * t, 0)
                paint.addColorStop(0, Qt.darker(ink, 1.3))
                paint.addColorStop(0.5, Qt.lighter(ink, 1.2))
                paint.addColorStop(1, Qt.darker(ink, 1.3))
            }
            ctx.fillStyle = paint
            ctx.strokeStyle = paint

            // Body outline.
            ctx.lineWidth = stroke
            ctx.beginPath()
            roundRect(ctx, stroke / 2, stroke / 2, 157 - stroke, 84 - stroke, 20 - stroke / 2)
            ctx.stroke()

            // Terminal: flat against the body, rounded outward.
            ctx.beginPath()
            ctx.moveTo(164, 30)
            ctx.lineTo(166, 30)
            ctx.arcTo(172, 30, 172, 37, 6)
            ctx.lineTo(172, 47)
            ctx.arcTo(172, 54, 166, 54, 6)
            ctx.lineTo(164, 54)
            ctx.closePath()
            ctx.fill()

            // Fill, clipped to the body's inner shape.
            const ix = stroke + 3, iw = 157 - 2 * ix, ih = 84 - 2 * ix
            const fw = iw * level / 100
            ctx.save()
            ctx.beginPath()
            roundRect(ctx, ix, ix, iw, ih, 20 - ix + 3)
            ctx.clip()
            if (fw > 0) {
                ctx.beginPath()
                ctx.rect(ix, ix, fw, ih)
                ctx.fill()
            }
            ctx.restore()

            // Percentage: halo in the icon colour, glyphs cut out of everything.
            const label = String(Math.round(level))
            ctx.font = "bold 54px 'Noto Sans'"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            const cx = 157 / 2, cy = 84 / 2 + 2
            ctx.lineJoin = "round"
            ctx.lineWidth = 8
            ctx.strokeStyle = paint
            ctx.strokeText(label, cx, cy)
            ctx.globalCompositeOperation = "destination-out"
            ctx.fillStyle = "black"
            ctx.fillText(label, cx, cy)
            ctx.globalCompositeOperation = "source-over"
        }
    }

    // Bolt while charging, plug while plugged in but not charging.
    Canvas {
        id: symbol
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool shown: indicator.charging || indicator.plugged
        visible: shown
        width: shown ? Math.ceil(22 * indicator.s * 3) : 0
        height: Math.ceil(84 * indicator.s)
        antialiasing: true
        property bool bolt: indicator.charging
        property color ink: indicator.ink
        onBoltChanged: requestPaint()
        onInkChanged: requestPaint()
        onVisibleChanged: if (visible)
            requestPaint()
        onAvailableChanged: if (available)
            requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            // Path drawn in a 22x28 box, fitted to the battery height.
            const k = height / 28
            ctx.scale(k, k)
            ctx.fillStyle = ink
            ctx.beginPath()
            if (bolt) {
                ctx.moveTo(14, 1)
                ctx.lineTo(3, 16)
                ctx.lineTo(10, 16)
                ctx.lineTo(8, 27)
                ctx.lineTo(20, 11)
                ctx.lineTo(12, 11)
                ctx.closePath()
            } else {
                ctx.moveTo(4, 1)
                ctx.lineTo(8, 1)
                ctx.lineTo(8, 9)
                ctx.lineTo(13, 9)
                ctx.lineTo(13, 1)
                ctx.lineTo(17, 1)
                ctx.lineTo(17, 9)
                ctx.lineTo(20, 9)
                ctx.lineTo(20, 14)
                ctx.bezierCurveTo(20, 19, 16, 22, 13, 23)
                ctx.lineTo(13, 28)
                ctx.lineTo(8, 28)
                ctx.lineTo(8, 23)
                ctx.bezierCurveTo(5, 22, 1, 19, 1, 14)
                ctx.lineTo(1, 9)
                ctx.lineTo(4, 9)
                ctx.closePath()
            }
            ctx.fill()
        }
    }
}
