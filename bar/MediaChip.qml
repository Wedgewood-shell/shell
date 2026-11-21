import QtQuick
import Quickshell
import ".."

// Media, collapsed next to the island while a higher base state (Helium's address
// bar) owns it: the album art in a square pill whose border fills clockwise with
// the track's progress, dimmed while paused.
Item {
    id: chip
    property real dpr: 1
    implicitWidth: Theme.px(Theme.barHeight, dpr)
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: Theme.closedRadius
        color: Theme.surface
        Frame {}
        AlbumArt {
            anchors.centerIn: parent
            width: 26
            height: 26
            source: MediaService.artUrl
            opacity: MediaService.playing ? 1 : 0.6
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
        PerimeterProgress {
            anchors.fill: parent
            z: 101    // on the border, above the Frame
            radius: Theme.closedRadius
            value: MediaService.progress
            color: MediaService.playing ? Theme.highlight : Theme.alpha(Theme.highlight, 0.4)
        }
    }
}
