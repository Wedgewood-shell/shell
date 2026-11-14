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
    implicitWidth: (kind === "headphones" ? 16 : 21) * s
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
    onWidthChanged: requestPaint()
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
    function capsule(ctx, cx, cy, w, h, deg) {
        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(deg * Math.PI / 180)
        ctx.beginPath()
        rrect(ctx, -w / 2, -h / 2, w, h, w / 2)
        ctx.restore()
    }
    // Draws the shape at alpha `a`; secondary details (pads, inner band) at half strength.
    function shape(ctx, a) {
        ctx.fillStyle = rgba(a)
        ctx.strokeStyle = rgba(a)
        if (kind === "earbuds") {
            ctx.beginPath()
            for (const m of [0, 1]) {
                const cx = m === 0 ? 5.2 : 15.8
                ctx.moveTo(cx + 4.2, 5)
                ctx.arc(cx, 5, 4.2, 0, Math.PI * 2, false)
                rrect(ctx, cx + (m === 0 ? 1.4 : -3.4), 8, 2, 7.5, 1)
            }
            ctx.fill()
            return
        }
        // Headphones are traced in the reference image's pixel space
        // (bbox ~74..182 x 74..191) and mapped onto the 16-unit icon height.
        ctx.save()
        const k = 16 / 117
        ctx.translate((icon.implicitWidth / icon.s - 108 * k) / 2, 0)
        ctx.scale(k, k)
        ctx.translate(-74, -74)
        // headband: thick arc, slimming into a neck above each cup
        ctx.lineCap = "butt"
        ctx.lineWidth = 12
        ctx.beginPath()
        ctx.arc(128, 127, 46.5, Math.PI + 0.22, 2 * Math.PI - 0.22, false)
        ctx.stroke()
        ctx.lineWidth = 7
        ctx.beginPath()
        ctx.arc(128, 128, 49, Math.PI - 0.17, 2 * Math.PI + 0.17, false)
        ctx.stroke()
        // ear cups, bottoms tilted inward
        capsule(ctx, 93, 166, 22, 52, -24)
        ctx.fill()
        capsule(ctx, 163, 166, 22, 52, 24)
        ctx.fill()
        // softer details: cushions + inner headband pad
        ctx.fillStyle = rgba(a * 0.55)
        capsule(ctx, 108.5, 158, 10, 49, -25)
        ctx.fill()
        capsule(ctx, 147.5, 158, 10, 49, 25)
        ctx.fill()
        ctx.beginPath()
        ctx.moveTo(101, 101)
        ctx.quadraticCurveTo(128, 82, 155, 101)
        ctx.quadraticCurveTo(128, 95, 101, 101)
        ctx.closePath()
        ctx.fill()
        ctx.restore()
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
            shape(ctx, 0.28)
            if (v > 0) {
                ctx.save()
                ctx.beginPath()
                ctx.rect(0, 16 * (1 - v), 21, 16 * v + 1)
                ctx.clip()
                shape(ctx, 1)
                ctx.restore()
            }
        }
    }
}
