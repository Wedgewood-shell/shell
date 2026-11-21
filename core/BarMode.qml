pragma Singleton
import QtQuick
import Quickshell
import ".."

// How compact the bar is on an output, as a continuous value that follows niri's
// camera. A full-width column (window as wide as the output) blends to the screen
// edges as it scrolls into alignment (full-width-to-edges in the sortedcord niri
// fork); this mirrors that blend, so the bar shrinks and grows with the windows
// during swipes and niri's own view animations.
//
// state() returns { plain, smart, driven }:
//   plain   0..1, compactness from full-width windows of ordinary apps (solid tint)
//   smart   0..1, the same for windows reaching the very top (tint gradient)
//   (they split one value: plain + smart is the compactness, at most 1)
//   driven  niri's camera is moving: follow the values directly, don't animate
// At rest the active window decides (whole values, same rule as the exclusive zone).
Singleton {
    id: root

    // niri: SMART_EDGES_BLEND_FRACTION (src/layout/scrolling.rs) and layout gaps.
    readonly property real blendFraction: 0.25
    readonly property int gaps: NiriService.layoutGap

    function state(output, outputWidth, outputHeight) {
        const rows = NiriService.wsOnOutput(output)
        if (!rows.length)
            return { plain: 0, smart: 0, driven: false }
        const view = NiriViewService.workspaceViews[output]
        const moving = NiriViewService.moving(view)
        const pos = moving ? clamp(view.position, 0, rows.length - 1) : Math.max(0, rows.findIndex(w => w.is_active))
        const i = Math.floor(pos), f = pos - i
        const a = workspaceState(rows[i], outputWidth, outputHeight)
        if (f < 1e-6 || i + 1 >= rows.length)
            return { plain: a.plain, smart: a.smart, driven: moving || a.driven }
        // Between two workspaces: crossfade by the vertical camera position.
        const b = workspaceState(rows[i + 1], outputWidth, outputHeight)
        return {
            plain: a.plain + (b.plain - a.plain) * f,
            smart: a.smart + (b.smart - a.smart) * f,
            driven: true
        }
    }

    function workspaceState(ws, outputWidth, outputHeight) {
        const wins = NiriService.windows
        const view = NiriViewService.columnViews[ws.id]
        if (!NiriViewService.moving(view) || view.viewPos === undefined) {
            const w = ws.active_window_id != null ? wins[ws.active_window_id] : null
            const kind = spanKind(w, outputWidth, outputHeight)
            return { plain: kind === "plain" ? 1 : 0, smart: kind === "smart" ? 1 : 0, driven: false }
        }
        // Columns left to right: width (widest tile) and whether a window spans.
        const cols = {}
        for (const k in wins) {
            const w = wins[k]
            const p = w.workspace_id === ws.id && w.layout ? w.layout.pos_in_scrolling_layout : null
            if (!p)
                continue
            const col = cols[p[0]] || (cols[p[0]] = { width: 0, kind: "" })
            col.width = Math.max(col.width, w.layout.tile_size ? w.layout.tile_size[0] : 0)
            col.kind = spanKind(w, outputWidth, outputHeight) || col.kind
        }
        // Each column's aligned camera position (col_x minus the working area's left gap).
        const list = []
        let x = 0
        for (const k of Object.keys(cols).map(Number).sort((a, b) => a - b)) {
            list.push({ at: x - gaps, kind: cols[k].kind })
            x += cols[k].width + gaps
        }
        // niri: adjacent full-width columns form a run that blends as one,
        // progress = smoothstep(1 - (camera distance to the run) / blend). So swiping
        // between two of them stays compact the whole way.
        const v = view.viewPos
        const blend = Math.max(1, outputWidth * blendFraction)
        let plain = 0, smart = 0
        for (let i = 0; i < list.length; i++) {
            if (!list[i].kind)
                continue
            let end = i
            while (end + 1 < list.length && list[end + 1].kind)
                end++
            const from = list[i].at, to = list[end].at
            const distance = v < from ? from - v : v > to ? v - to : 0
            const near = 1 - Math.min(1, distance / blend)
            const p = near * near * (3 - 2 * near)
            // Solid vs gradient tint: interpolated between the run's columns by the camera.
            const share = smartShare(list, i, end, clamp(v, from, to))
            plain = Math.max(plain, p * (1 - share))
            smart = Math.max(smart, p * share)
            i = end
        }
        return { plain: plain, smart: smart, driven: true }
    }

    // From the window's own geometry (niri decides it via full-width-to-edges-top):
    //   "plain"  as wide as the output and reaching under the bar's exclusive zone
    //   "smart"  the same, all the way to the top of the output
    //   ""       anything else (including maximize-to-edges, which stops at the bar)
    function spanKind(w, outputWidth, outputHeight) {
        const size = w && w.layout ? w.layout.window_size : null
        if (!size || outputWidth <= 0 || size[0] < outputWidth - 1)
            return ""
        if (size[1] >= outputHeight - 1)
            return "smart"
        return size[1] > outputHeight - Theme.barZone + 0.5 ? "plain" : ""
    }

    // 0..1: how much of the run at camera position v is a smart-fullscreen app.
    function smartShare(list, start, end, v) {
        const isSmart = i => list[i].kind === "smart" ? 1 : 0
        for (let i = start; i < end; i++) {
            const a = list[i].at, b = list[i + 1].at
            if (v <= b) {
                const t = b - a < 1 ? 1 : (v - a) / (b - a)
                return isSmart(i) + (isSmart(i + 1) - isSmart(i)) * t
            }
        }
        return isSmart(end)
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }
}
