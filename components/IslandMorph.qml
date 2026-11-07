import QtQuick
import Quickshell
import ".."

// One progress value interpolates every dimension. Target changes in one QML
// event turn are coalesced, including menu resizes and interrupted transitions.
Scope {
    id: morph
    property bool expanded: false
    property real collapsedWidth: Theme.islandBaseWidth
    property real expandedWidth: 620
    property real expandedHeight: Theme.barHeight
    property int duration: Theme.morphDuration
    property int openingEasing: Easing.OutBack
    property int closingEasing: Easing.InOutCubic
    property bool initialized: false
    property real progress: 1
    property real fromWidth: 0
    property real fromHeight: Theme.barHeight
    property real fromRadius: Theme.closedRadius
    property real toWidth: 0
    property real toHeight: Theme.barHeight
    property real toRadius: Theme.closedRadius
    readonly property real targetWidth: expanded ? expandedWidth : collapsedWidth
    readonly property real targetHeight: expanded ? expandedHeight : Theme.barHeight
    readonly property real targetRadius: expanded ? Theme.openRadius : Theme.closedRadius
    readonly property real width: fromWidth + (toWidth - fromWidth) * progress
    readonly property real height: fromHeight + (toHeight - fromHeight) * progress
    readonly property real radius: fromRadius + (toRadius - fromRadius) * progress
    readonly property bool running: animation.running

    function schedule() {
        if (initialized)
            Qt.callLater(retarget)
    }
    function retarget() {
        const w = width, h = height, r = radius
        animation.stop()
        if (Math.abs(w - targetWidth) < 0.001 && Math.abs(h - targetHeight) < 0.001 && Math.abs(r - targetRadius) < 0.001)
            return
        fromWidth = w
        fromHeight = h
        fromRadius = r
        toWidth = targetWidth
        toHeight = targetHeight
        toRadius = targetRadius
        progress = 0
        animation.start()
    }
    onTargetWidthChanged: schedule()
    onTargetHeightChanged: schedule()
    onTargetRadiusChanged: schedule()
    Component.onCompleted: {
        fromWidth = toWidth = targetWidth
        fromHeight = toHeight = targetHeight
        fromRadius = toRadius = targetRadius
        initialized = true
    }
    NumberAnimation {
        id: animation
        target: morph
        property: "progress"
        from: 0
        to: 1
        duration: morph.duration
        easing.type: morph.expanded ? morph.openingEasing : morph.closingEasing
        easing.overshoot: 0.9
    }
}
