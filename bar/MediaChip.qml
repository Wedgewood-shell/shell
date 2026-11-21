import QtQuick
import Quickshell
import ".."

// The media pill in the bar. With media as the island's base state it lies exactly
// over the island and is the island's media view (the island itself draws none).
// When a higher base state (Helium's address bar) takes the island, it detaches and
// collapses to the right into a square chip beside it: the album art grows to fill
// it edge to edge while the title fades out. Its border is the track's progress,
// filling clockwise (dimmed while paused), expanded or collapsed.
//
// Lives in the island's coordinate space: x = 0 is the island's left edge.
Item {
    id: chip
    property real dpr: 1
    // The island's current (animating) width, so the pill follows it exactly.
    property real islandWidth: Theme.islandMediaWidth
    // 0 = over the island, 1 = collapsed beside it.
    property real collapse: IslandController.mediaChip ? 1 : 0
    Behavior on collapse {
        NumberAnimation {
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }
    // Shown as the island's media view, or as the chip; hidden while an alert or
    // the voice view has the island (they would be covered otherwise).
    readonly property bool shown: MediaService.active && (IslandController.mediaChip || IslandController.islandMode === "media")

    readonly property real chipSize: Theme.px(Theme.barHeight, dpr)
    x: (islandWidth + Theme.chipGap) * collapse
    width: islandWidth + (chipSize - islandWidth) * collapse
    height: chipSize
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fadeDuration
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.closedRadius
        color: Theme.surface
        clip: true
        MediaView {
            anchors.fill: parent
            active: true
            collapse: chip.collapse
        }
        Frame {}
        PerimeterProgress {
            anchors.fill: parent
            z: 101    // on the border, above the Frame
            radius: Theme.closedRadius
            value: MediaService.progress
            color: MediaService.playing ? Theme.highlight : Theme.alpha(Theme.highlight, 0.4)
        }
    }
}
