import QtQuick
import ".."

// Progress traced clockwise around a rounded rectangle's border, from top centre.
// Fill the pill with it (anchors.fill) above its Frame; `radius` should match the pill.
Canvas {
    id: ring
    property real value: 0       // 0..1
    property real radius: Theme.closedRadius
    property real lineWidth: 2
    property color color: Theme.highlight

    onValueChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (value <= 0)
            return
        const o = lineWidth / 2, w = width - lineWidth, h = height - lineWidth
        const r = Math.max(1, Math.min(radius - o, w / 2, h / 2))
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
        let left = Math.min(1, value) * total
        ctx.strokeStyle = color
        ctx.lineWidth = lineWidth
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
