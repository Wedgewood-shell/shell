import QtQuick
import ".."

// Hover area for list rows: `moved` fires only when the pointer itself moved,
// never because a row appeared or scrolled beneath a stationary pointer.
MouseArea {
    id: area
    signal moved
    hoverEnabled: true
    Component.onCompleted: PointerGate.valid = false
    onPositionChanged: mouse => {
        const p = area.mapToItem(null, mouse.x, mouse.y)
        const same = Math.abs(p.x - PointerGate.x) < 0.5 && Math.abs(p.y - PointerGate.y) < 0.5
        const known = PointerGate.valid
        PointerGate.x = p.x
        PointerGate.y = p.y
        PointerGate.valid = true
        if (known && !same)
            area.moved()
    }
}
