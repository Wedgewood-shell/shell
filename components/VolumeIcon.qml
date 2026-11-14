import QtQuick
import ".."

// Output-aware volume glyph.
//   kind: "speaker" (waves grow with level) | "earbuds" | "headphones" (fill rises with level)
//   volume: 0..1.5 ; above 1.0 the colour shifts from base to red.
Canvas {
    id: icon
    property string kind: "speaker"
    property real volume: 0
    property bool muted: false
    property color base: "#ffffff"
    property real s: 1
    readonly property real over: Math.max(0, Math.min(1, (volume - 1) / 0.5))
    readonly property color color: muted ? Qt.rgba(0.57, 0.6, 0.67, 1) : Qt.tint(base, Qt.rgba(1, 0.25, 0.25, over))
    implicitWidth: 21 * s
    implicitHeight: 16 * s
    width: implicitWidth
    height: implicitHeight
    Behavior on volume {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    onKindChanged: requestPaint()
    onVolumeChanged: requestPaint()
    onMutedChanged: requestPaint()
    onColorChanged: requestPaint()
    onSChanged: requestPaint()

    function rgba(a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }
    function rrect(ctx, x, y, w, h, r) {
        ctx.moveTo(x + r, y)
        ctx.arcTo(x + w, y, x + w, y + h, r)
        ctx.arcTo(x + w, y + h, x, y + h, r)
        ctx.arcTo(x, y + h, x, y, r)
        ctx.arcTo(x, y, x + w, y, r)
        ctx.closePath()
    }
    // Shape path; filled parts via fill, band via stroke.
    function shape(ctx) {
        ctx.beginPath()
        if (kind === "earbuds") {
            for (const m of [0, 1]) {
                const cx = m === 0 ? 5.2 : 15.8
                ctx.moveTo(cx + 4.2, 5)
                ctx.arc(cx, 5, 4.2, 0, Math.PI * 2, false)
                rrect(ctx, cx + (m === 0 ? 1.4 : -3.4), 8, 2, 7.5, 1)
            }
        } else {
            rrect(ctx, 1, 8.5, 4.2, 6.5, 1.8)
            rrect(ctx, 15.8, 8.5, 4.2, 6.5, 1.8)
        }
        ctx.fill()
        if (kind === "headphones") {
            ctx.lineWidth = 1.8
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(10.5, 9.5, 7.6, Math.PI, 2 * Math.PI, false)
            ctx.stroke()
        }
    }
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.scale(s, s)
        const v = muted ? 0 : Math.max(0, Math.min(1, volume))
        if (kind === "speaker") {
            const lit = muted ? 0 : volume <= 0 ? 0 : volume < 0.34 ? 1 : volume < 0.67 ? 2 : 3
            ctx.fillStyle = rgba(1)
            ctx.beginPath()
            ctx.moveTo(1, 5.5)
            ctx.lineTo(4.5, 5.5)
            ctx.lineTo(9, 1.5)
            ctx.lineTo(9, 14.5)
            ctx.lineTo(4.5, 10.5)
            ctx.lineTo(1, 10.5)
            ctx.closePath()
            ctx.fill()
            ctx.lineWidth = 1.7
            ctx.lineCap = "round"
            const a = 40 * Math.PI / 180
            for (let i = 0; i < 3; i++) {
                ctx.strokeStyle = rgba(i < lit ? 1 : 0.28)
                ctx.beginPath()
                ctx.arc(8, 8, 4 + 3.4 * i, -a, a, false)
                ctx.stroke()
            }
            if (muted) {
                ctx.strokeStyle = rgba(1)
                ctx.beginPath()
                ctx.moveTo(12, 5)
                ctx.lineTo(19, 11)
                ctx.moveTo(19, 5)
                ctx.lineTo(12, 11)
                ctx.stroke()
            }
        } else {
            ctx.fillStyle = rgba(0.28)
            ctx.strokeStyle = rgba(0.28)
            shape(ctx)
            if (v > 0) {
                ctx.save()
                ctx.beginPath()
                ctx.rect(0, 16 * (1 - v), 21, 16 * v + 1)
                ctx.clip()
                ctx.fillStyle = rgba(1)
                ctx.strokeStyle = rgba(1)
                shape(ctx)
                ctx.restore()
            }
        }
    }
}
