import QtQuick
import Quickshell
import ".."

// Keep the front surface until its morph finishes and the bar has had time to
// render underneath it. Coverage changes follow presented frames, not a guessed
// timer measured from the keypress.
Scope {
    id: handoff
    required property var surface
    property bool expanded: false
    property real collapsedHeight: Theme.barHeight
    property real currentHeight: collapsedHeight
    property real expandedHeight: collapsedHeight
    readonly property real collapseProgress: expanded ? 0 : Math.max(0, Math.min(1, 1 - (currentHeight - collapsedHeight) / Math.max(1, expandedHeight - collapsedHeight)))
    readonly property real contentOpacity: expanded ? 1 : 1 - fade(0, 0.8, collapseProgress)
    readonly property real islandOpacity: expanded ? 0 : fade(0.65, 1, collapseProgress)

    function fade(from, to, value) {
        const t = Math.max(0, Math.min(1, (value - from) / (to - from)))
        return t * t * (3 - 2 * t)
    }
    property bool morphing: false
    property bool retained: false
    property bool covered: false
    property bool releasing: false
    property bool hasPresented: false
    property int releaseFrames: 0
    readonly property var renderWindow: surface.contentItem.Window.window

    onExpandedChanged: {
        if (expanded) {
            returnDelay.stop()
            releaseFrames = 0
            releasing = false
            retained = true
        } else
            Qt.callLater(maybeRelease)
    }
    onMorphingChanged: {
        if (!expanded && morphing && retained) {
            returnDelay.stop()
            releasing = false
            releaseFrames = 0
            if (hasPresented)
                covered = true
        } else if (!morphing)
            Qt.callLater(maybeRelease)
    }
    onRetainedChanged: if (!retained)
        hasPresented = false

    function maybeRelease() {
        if (expanded || morphing || !retained || releasing)
            return
        releasing = true
        covered = false
        returnDelay.restart()
    }
    Timer {
        id: returnDelay
        interval: Theme.islandFadeDuration
        onTriggered: {
            if (handoff.expanded || handoff.morphing)
                return
            if (!handoff.renderWindow) {
                handoff.retained = false
                return
            }
            handoff.releaseFrames = 2
            handoff.renderWindow.update()
        }
    }
    Connections {
        target: handoff.renderWindow
        function onFrameSwapped() {
            if (!handoff.retained)
                return
            handoff.hasPresented = true
            if (!handoff.releasing) {
                handoff.covered = true
            } else if (handoff.releaseFrames > 0) {
                handoff.releaseFrames--
                if (handoff.releaseFrames === 0) {
                    handoff.retained = false
                    handoff.releasing = false
                } else
                    Qt.callLater(() => {
                        if (handoff.renderWindow)
                            handoff.renderWindow.update()
                    })
            }
        }
    }
}
