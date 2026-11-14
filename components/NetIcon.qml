import QtQuick
import ".."

// Custom network glyph drawn on a canvas.
//   kind: "wifi" | "eth" | "hotspot" | "none"
//   level: 0..3 lit wifi sectors (signal strength)
Canvas {
    id: icon
    property string kind: "wifi"
    property int level: 3
    property color color: Theme.foreground
    implicitWidth: 21
    implicitHeight: 16
    width: implicitWidth
    height: implicitHeight
    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    function rgba(a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }
    function ring(ctx, cx, cy, r0, r1) {
        const a0 = -135 * Math.PI / 180, a1 = -45 * Math.PI / 180
        ctx.beginPath()
        ctx.arc(cx, cy, r1, a0, a1, false)
        ctx.arc(cx, cy, r0, a1, a0, true)
        ctx.closePath()
        ctx.fill()
    }
    function roundRect(ctx, x, y, w, h, r) {
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.arcTo(x + w, y, x + w, y + h, r)
        ctx.arcTo(x + w, y + h, x, y + h, r)
        ctx.arcTo(x, y + h, x, y, r)
        ctx.arcTo(x, y, x + w, y, r)
        ctx.closePath()
    }
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (kind === "eth") {
            ctx.strokeStyle = rgba(1)
            ctx.fillStyle = rgba(1)
            ctx.lineWidth = 2.2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(5.5, 2.5)
            ctx.lineTo(1.5, 8)
            ctx.lineTo(5.5, 13.5)
            ctx.moveTo(15.5, 2.5)
            ctx.lineTo(19.5, 8)
            ctx.lineTo(15.5, 13.5)
            ctx.stroke()
            for (const x of [7.5, 10.5, 13.5]) {
                ctx.beginPath()
                ctx.arc(x, 8, 1.2, 0, Math.PI * 2)
                ctx.fill()
            }
        } else if (kind === "hotspot") {
            ctx.strokeStyle = rgba(1)
            ctx.lineWidth = 2
            roundRect(ctx, 1, 1.5, 12.5, 8, 4)
            ctx.stroke()
            roundRect(ctx, 7.5, 6.5, 12.5, 8, 4)
            ctx.stroke()
        } else {
            const cx = width / 2, cy = height - 0.5
            const rr = [0, 3.9, 6.8, 9.5, 12.3, 15]
            const lit = kind === "none" ? 0 : level
            for (let i = 0; i < 3; i++) {
                ctx.fillStyle = rgba(i < lit ? 1 : 0.28)
                if (i === 0) {
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, rr[1], -135 * Math.PI / 180, -45 * Math.PI / 180, false)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    ring(ctx, cx, cy, rr[2 * i], rr[2 * i + 1])
                }
            }
            if (kind === "none") {
                ctx.strokeStyle = rgba(1)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(3, 2)
                ctx.lineTo(18, 15)
                ctx.stroke()
            }
        }
    }
}
