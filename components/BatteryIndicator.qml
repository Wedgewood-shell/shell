import QtQuick
import ".."
import "BatteryHoles.js" as BatteryHoles

// Battery glyph: a thick rounded outline with a D-shaped terminal, filled from the
// left right up to the outline, and the percentage cut out of it with a halo in the
// outline colour (readable over both the fill and the empty part). Drawn in
// reference units (84 tall) and vector-scaled to `bodyHeight`.
//
// The outline stays in the foreground colour; only the fill follows the power
// profile: yellow in power-saver, red when balanced and under 20 %, purple with a
// sweeping colour pulse in performance. A bolt (charging) or plug (plugged in, not
// charging) sits to the right.
Row {
    id: indicator
    property int percentage: BatteryService.battery
    property bool plugged: BatteryService.plugged
    property bool charging: BatteryService.charging
    property string profile: SystemService.profile
    property real bodyHeight: 16.5

    readonly property int level: Math.max(0, Math.min(100, percentage))
    readonly property bool performance: profile === "performance"
    readonly property color frame: Theme.foreground
    readonly property color fillColor: performance ? Theme.purple : profile === "power-saver" ? Theme.warning : level < 20 ? Theme.danger : frame
    readonly property real s: bodyHeight / 84
    spacing: Math.round(bodyHeight * 0.18)

    FontLoader {
        id: digits
        source: Qt.resolvedUrl("../assets/fonts/BatteryDigits.ttf")
    }
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
        width: Math.ceil(173 * indicator.s)
        height: Math.ceil(84 * indicator.s)
        antialiasing: true
        property real level: indicator.level
        property color frame: indicator.frame
        property color fillColor: indicator.fillColor
        property real phase: indicator.phase
        property bool pulse: indicator.performance
        property bool fontReady: digits.status === FontLoader.Ready
        onLevelChanged: requestPaint()
        onFrameChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onPhaseChanged: if (pulse)
            requestPaint()
        onPulseChanged: requestPaint()
        onFontReadyChanged: requestPaint()
        onWidthChanged: requestPaint()
        onAvailableChanged: if (available)
            requestPaint()

        // BatteryDigits metrics in font units (1000/em): [advance, ink xMin, ink xMax].
        readonly property var ink: ({
                "0": [600, 33, 567],
                "1": [391, 18, 311],
                "2": [576, 47, 546],
                "3": [580, 31, 521],
                "4": [582, 16, 566],
                "5": [600, 65, 562],
                "6": [600, 52, 559],
                "7": [535, 20, 505],
                "8": [600, 38, 562],
                "9": [590, 41, 548]
            })
        readonly property real figureHeight: 680

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
            // Outline width, kept at least 1.4 px on screen.
            const stroke = Math.max(5, 1.4 / s)
            const bw = 157, bh = 84, r = 20

            // Fill, flush with the outline (drawn under it so no seam shows).
            const iw = bw - 2 * stroke
            const fw = iw * level / 100
            if (fw > 0) {
                let paint = fillColor
                if (pulse) {
                    const t = phase / (Math.PI * 2)
                    paint = ctx.createLinearGradient(-bw + 2 * bw * t, 0, 2 * bw * t, 0)
                    paint.addColorStop(0, Qt.darker(fillColor, 1.3))
                    paint.addColorStop(0.5, Qt.lighter(fillColor, 1.2))
                    paint.addColorStop(1, Qt.darker(fillColor, 1.3))
                }
                ctx.save()
                ctx.beginPath()
                roundRect(ctx, stroke / 2, stroke / 2, bw - stroke, bh - stroke, r - stroke / 2)
                ctx.clip()
                ctx.fillStyle = paint
                ctx.fillRect(0, 0, stroke + fw, bh)
                ctx.restore()
            }

            // Outline.
            ctx.strokeStyle = frame
            ctx.lineWidth = stroke
            ctx.beginPath()
            roundRect(ctx, stroke / 2, stroke / 2, bw - stroke, bh - stroke, r - stroke / 2)
            ctx.stroke()

            // Terminal: flat against the body, a half ellipse outward.
            ctx.fillStyle = frame
            ctx.beginPath()
            ctx.moveTo(164, 30)
            ctx.bezierCurveTo(176, 30, 176, 54, 164, 54)
            ctx.closePath()
            ctx.fill()

            // Percentage. Figures use their own advances; the gaps between neighbours are bridged
            // in the outline colour so the number reads as one haloed shape. Then the
            // glyphs are cut out of everything.
            const label = String(Math.round(level))
            const halo = 5
            const size = 62
            const em = size / 1000
            const top = bh / 2 - figureHeight * em / 2
            const base = top + figureHeight * em
            // Lay out by advances pulled together (font units), so neighbouring
            // halos meet and close the gap between them; then centre the ink.
            const tracking = -45
            const pen = [], left = [], right = []
            let x = 0
            for (const ch of label) {
                pen.push(x)
                left.push(x + ink[ch][1] * em)
                right.push(x + ink[ch][2] * em)
                x += (ink[ch][0] + tracking) * em
            }
            const shift = (bw - (right[right.length - 1] - left[0])) / 2 - left[0]
            for (let i = 0; i < label.length; i++) {
                pen[i] += shift
                left[i] += shift
                right[i] += shift
            }
            ctx.font = size + "px 'Battery Digits'"
            ctx.textBaseline = "alphabetic"
            ctx.textAlign = "left"
            ctx.lineJoin = "round"
            ctx.lineWidth = halo * 2
            ctx.strokeStyle = frame
            ctx.fillStyle = frame
            for (let i = 0; i < label.length; i++) {
                ctx.strokeText(label[i], pen[i], base)
                ctx.fillText(label[i], pen[i], base)
            }
            // Fill everything the halo encloses: the figures' loops and pockets sealed
            // off where neighbouring halos touch (precomputed per number, in font
            // units relative to the first pen position, y up).
            const regions = BatteryHoles.holes[label] || []
            if (regions.length) {
                ctx.save()
                ctx.translate(pen[0], base)
                ctx.scale(em, -em)
                ctx.beginPath()
                for (const poly of regions) {
                    ctx.moveTo(poly[0], poly[1])
                    for (let j = 2; j < poly.length; j += 2)
                        ctx.lineTo(poly[j], poly[j + 1])
                    ctx.closePath()
                }
                ctx.fill()
                ctx.restore()
            }
            ctx.globalCompositeOperation = "destination-out"
            ctx.font = size + "px 'Battery Digits'"
            ctx.fillStyle = "black"
            for (let i = 0; i < label.length; i++)
                ctx.fillText(label[i], pen[i], base)
            ctx.globalCompositeOperation = "source-over"
        }
    }

    // Bolt while charging, plug while plugged in but not charging.
    Canvas {
        id: symbol
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool shown: indicator.charging || indicator.plugged
        visible: shown
        // Shapes are drawn in a 120x200 box (a 104x184 path plus its rounding stroke).
        height: Math.ceil(84 * indicator.s * 0.92)
        width: shown ? Math.ceil(height * 120 / 200) : 0
        antialiasing: true
        property bool bolt: indicator.charging
        property color ink: indicator.frame
        onBoltChanged: requestPaint()
        onInkChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible)
            requestPaint()
        onAvailableChanged: if (available)
            requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const k = height / 200
            ctx.scale(k, k)
            ctx.translate(8, 8)
            ctx.fillStyle = ink
            ctx.strokeStyle = ink
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.lineWidth = 16
            ctx.beginPath()
            if (bolt) {
                // Slanted bolt, 104x184.
                ctx.moveTo(84, 0)
                ctx.lineTo(62, 78)
                ctx.lineTo(104, 80)
                ctx.lineTo(28, 184)
                ctx.lineTo(48, 106)
                ctx.lineTo(0, 104)
                ctx.closePath()
                ctx.fill()
                ctx.stroke()
            } else {
                // Plug, 104x184: two prongs, a bowl, a stem.
                for (const px of [22, 64]) {
                    ctx.moveTo(px, 9)
                    ctx.arcTo(px, 0, px + 9, 0, 9)
                    ctx.arcTo(px + 18, 0, px + 18, 9, 9)
                    ctx.lineTo(px + 18, 46)
                    ctx.lineTo(px, 46)
                    ctx.closePath()
                }
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(6, 40)
                ctx.lineTo(98, 40)
                ctx.arcTo(104, 40, 104, 46, 6)
                ctx.lineTo(104, 80)
                ctx.bezierCurveTo(104, 108, 84, 128, 66, 132)
                ctx.lineTo(66, 180)
                ctx.arcTo(66, 184, 62, 184, 4)
                ctx.lineTo(42, 184)
                ctx.arcTo(38, 184, 38, 180, 4)
                ctx.lineTo(38, 132)
                ctx.bezierCurveTo(20, 128, 0, 108, 0, 80)
                ctx.lineTo(0, 46)
                ctx.arcTo(0, 40, 6, 40, 6)
                ctx.closePath()
                ctx.fill()
                ctx.stroke()
            }
        }
    }
}
