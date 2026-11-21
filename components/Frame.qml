import QtQuick
import ".."

// A pill's border, drawn above its content instead of by the pill itself. Whatever
// a view draws inside (edge fades, marquee masks, backgrounds) then can never cover
// or fade the border. Put it inside the pill and give the pill border.width: 0.
Rectangle {
    anchors.fill: parent
    // Above any content; overlays that belong on the border itself (the island's
    // page-load ring) go higher.
    z: 100
    color: "transparent"
    radius: parent ? parent.radius : 0
    border.width: 1
    border.color: Theme.border
}
