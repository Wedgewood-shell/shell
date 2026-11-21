import QtQuick
import Quickshell
import ".."

// BarMode.state() for one output, eased only when niri's camera isn't driving it:
// swipes and view animations are followed frame by frame, other changes (e.g.
// maximizing in place) animate over Theme.compactDuration.
Scope {
    id: follower
    required property string output
    required property real outputWidth

    readonly property var state: BarMode.state(output, outputWidth)
    property real plain: state.plain
    property real smart: state.smart
    // 0 = normal, 1 = compact. plain and smart split it (a swipe between a smart and an
    // ordinary full-width window crossfades the tint), so it is their sum.
    readonly property real c: Math.min(1, plain + smart)

    Behavior on plain {
        enabled: !follower.state.driven
        NumberAnimation {
            duration: Theme.compactDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on smart {
        enabled: !follower.state.driven
        NumberAnimation {
            duration: Theme.compactDuration
            easing.type: Easing.InOutCubic
        }
    }
}
