import QtQuick
import ".."

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
    property real bodyHeight: 23

    readonly property int level: Math.max(0, Math.min(100, percentage))
    readonly property bool performance: profile === "performance"
    readonly property color frame: Theme.foreground
    readonly property color fillColor: performance ? "#c4a7ff" : profile === "power-saver" ? Theme.warning : level < 20 ? Theme.danger : frame
    readonly property real s: bodyHeight / 84
    spacing: Math.round(bodyHeight * 0.18)

    FontLoader {
        id: digits
        source: Qt.resolvedUrl("../assets/fonts/BatteryDigits.ttf")
    }
    // Same figures with their counters filled: the halo is drawn with it so the
    // enclosed loops of 0, 4, 6, 8 and 9 are filled in the outline colour.
    FontLoader {
        id: solidDigits
        source: Qt.resolvedUrl("../assets/fonts/BatteryDigitsSolid.ttf")
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
        property bool fontReady: digits.status === FontLoader.Ready && solidDigits.status === FontLoader.Ready
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

        // Ink extent of each figure per row: rows every `rowStep` font units from
        // the baseline up, [left, right] in font units (null where the row is empty).
        readonly property real rowStep: 20
        readonly property var rows: {"0": [[223, 377], [172, 428], [141, 459], [119, 481], [101, 498], [87, 512], [75, 523], [66, 532], [58, 540], [52, 547], [47, 552], [43, 556], [39, 559], [37, 562], [35, 564], [34, 565], [33, 566], [33, 566], [33, 566], [34, 565], [35, 564], [37, 562], [40, 559], [44, 555], [48, 551], [54, 546], [60, 539], [69, 530], [79, 520], [91, 508], [106, 493], [125, 474], [151, 449], [189, 411], [281, 318]], "1": [[213, 281], [192, 301], [185, 308], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [183, 310], [31, 310], [21, 310], [22, 310], [32, 310], [51, 310], [72, 310], [94, 310], [115, 310], [136, 310], [157, 310], [179, 308], [201, 299], null], "2": [null, [72, 536], [64, 544], [62, 545], [66, 540], [77, 522], [93, 242], [112, 261], [130, 280], [149, 299], [168, 318], [187, 338], [205, 357], [224, 376], [243, 395], [262, 414], [281, 431], [299, 448], [319, 463], [338, 477], [357, 488], [373, 498], [384, 504], [389, 508], [390, 510], [387, 509], [63, 507], [52, 503], [49, 496], [53, 486], [68, 473], [92, 455], [125, 430], [170, 393], [262, 296]], "3": [[171, 355], [106, 412], [71, 445], [48, 468], [37, 485], [34, 498], [39, 507], [56, 513], [389, 518], [395, 520], [397, 520], [395, 518], [388, 513], [370, 505], [326, 494], [160, 478], [148, 455], [145, 420], [148, 418], [161, 451], [328, 471], [362, 484], [373, 492], [378, 497], [379, 499], [377, 499], [371, 497], [60, 494], [49, 488], [47, 480], [53, 467], [71, 450], [100, 425], [142, 387], [249, 288]], "4": [[360, 429], [339, 450], [332, 457], [331, 458], [331, 458], [331, 458], [331, 458], [49, 538], [23, 559], [16, 565], [17, 564], [23, 556], [33, 517], [46, 458], [60, 458], [74, 458], [88, 458], [102, 458], [116, 458], [130, 458], [144, 458], [158, 458], [172, 458], [186, 458], [200, 458], [215, 458], [229, 458], [243, 458], [257, 458], [271, 458], [285, 458], [299, 458], [313, 454], [332, 439], null], "5": [[218, 388], [151, 441], [110, 474], [82, 497], [70, 515], [67, 529], [72, 539], [87, 548], [424, 554], [433, 558], [437, 560], [438, 561], [436, 560], [114, 558], [91, 554], [86, 548], [86, 539], [86, 527], [86, 512], [86, 491], [86, 463], [86, 419], [86, 210], [86, 210], [86, 210], [86, 210], [86, 210], [86, 210], [86, 210], [86, 512], [86, 524], [86, 526], [90, 522], [105, 506], null], "6": [[244, 397], [191, 445], [160, 474], [137, 496], [119, 513], [104, 526], [93, 536], [83, 544], [76, 550], [69, 554], [64, 557], [60, 558], [57, 558], [55, 556], [53, 552], [52, 545], [52, 537], [52, 526], [53, 511], [54, 493], [56, 468], [59, 431], [62, 183], [67, 189], [72, 197], [79, 208], [87, 222], [97, 508], [108, 525], [122, 530], [139, 525], [160, 509], [187, 483], [227, 445], [322, 356]], "7": [[113, 184], [93, 208], [88, 220], [92, 230], [101, 241], [112, 251], [122, 262], [133, 272], [143, 282], [154, 293], [165, 303], [175, 314], [186, 324], [197, 335], [207, 345], [218, 355], [229, 366], [239, 376], [250, 387], [260, 397], [271, 408], [282, 418], [292, 429], [303, 439], [314, 449], [324, 460], [335, 470], [346, 481], [356, 491], [32, 499], [22, 503], [20, 504], [24, 500], [39, 482], null], "8": [[205, 394], [146, 453], [112, 487], [88, 511], [71, 528], [59, 540], [50, 549], [44, 555], [40, 559], [38, 561], [38, 561], [41, 558], [46, 553], [55, 544], [67, 532], [84, 515], [107, 492], [143, 458], [122, 481], [94, 507], [78, 523], [67, 533], [61, 539], [58, 542], [56, 544], [56, 544], [58, 542], [62, 538], [68, 532], [78, 522], [91, 509], [110, 490], [136, 464], [176, 424], [279, 320]], "9": [[167, 326], [108, 381], [77, 415], [57, 440], [50, 460], [50, 476], [57, 489], [78, 500], [381, 510], [393, 518], [403, 525], [410, 530], [415, 535], [192, 539], [140, 542], [110, 544], [90, 546], [74, 547], [63, 547], [54, 547], [48, 546], [44, 545], [42, 543], [41, 540], [41, 536], [43, 532], [47, 526], [52, 518], [60, 509], [71, 497], [84, 481], [103, 461], [128, 434], [165, 394], [256, 294]]}

        // A figure's halo edge per row (in font units, rows may extend past the ink):
        // the ink extent dilated by a disc of radius r. side: -1 left edge, +1 right.
        function haloEdge(ch, side, r) {
            const ink = rows[ch]
            const n = ink.length
            const ext = Math.ceil(r / rowStep)
            const edge = {}
            for (let k = -ext; k < n + ext; k++) {
                let best = null
                for (let j = Math.max(0, k - ext); j <= Math.min(n - 1, k + ext); j++) {
                    if (!ink[j])
                        continue
                    const dy = (k - j) * rowStep
                    if (Math.abs(dy) > r)
                        continue
                    const v = side > 0 ? ink[j][1] + Math.sqrt(r * r - dy * dy) : ink[j][0] - Math.sqrt(r * r - dy * dy)
                    if (best === null || (side > 0 ? v > best : v < best))
                        best = v
                }
                edge[k] = best
            }
            return edge
        }

        function fillTrapped(ctx, a, penA, b, penB, base, em, halo) {
            const r = halo / em
            const ra = haloEdge(a, 1, r), lb = haloEdge(b, -1, r)
            const xa = k => penA + ra[k] * em, xb = k => penB + lb[k] * em
            const ks = Object.keys(ra).map(Number).filter(k => ra[k] !== null && lb[k] !== null && lb[k] !== undefined)
            const touching = ks.filter(k => xa(k) >= xb(k))
            if (!touching.length)
                return
            const lo = Math.min(...touching), hi = Math.max(...touching)
            const y = k => base - k * rowStep * em
            // Reach a little into both halos so the stepped edges leave no seam.
            const tuck = halo * 0.5
            ctx.beginPath()
            ctx.moveTo(xa(lo) - tuck, y(lo))
            for (let k = lo + 1; k <= hi; k++)
                ctx.lineTo(xa(k) - tuck, y(k))
            for (let k = hi; k >= lo; k--)
                ctx.lineTo(Math.max(xa(k), xb(k)) + tuck, y(k))
            ctx.closePath()
            ctx.fill()
        }

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
            ctx.font = size + "px 'Battery Digits Solid'"
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
            // Where neighbouring halos touch, fill the void they trap between the
            // first and last touching rows (open notches above/below stay open).
            for (let i = 0; i + 1 < label.length; i++)
                fillTrapped(ctx, label[i], pen[i], label[i + 1], pen[i + 1], base, em, halo)
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
