import QtQuick
import Quickshell
import "../.."

// Base state while media plays (or is briefly paused): album art and "title — artist"
// (scrolling like a marquee when it doesn't fit). Track progress is the border ring
// of the pill hosting it (bar/MediaChip.qml). `collapse` morphs the layout into the
// chip's: 0 = island, 1 = the art alone, filling a square pill edge to edge.
Item {
    id: view
    property bool active: IslandController.islandMode === "media"
    property real collapse: 0
    implicitWidth: Theme.islandMediaWidth - 36
    implicitHeight: 42
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fadeDuration
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    AlbumArt {
        id: art
        readonly property real size: 26 + (view.height - 26) * view.collapse
        x: 9 * (1 - view.collapse)
        y: (view.height - size) / 2
        width: size
        height: size
        radius: 6 + (Theme.closedRadius - 6) * view.collapse
        source: MediaService.artUrl
        opacity: MediaService.playing ? 1 : 0.6
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }
    }

    Item {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 18
        height: parent.height
        clip: true
        opacity: Math.max(0, 1 - view.collapse * 2.5)
        visible: opacity > 0

        readonly property string shown: MediaService.artist ? MediaService.title + "  —  " + MediaService.artist : MediaService.title
        readonly property real overflow: Math.max(0, label.implicitWidth - width)
        // Marquee: pause, scroll to the end, pause, restart (like the voice view).
        property real t: 0
        readonly property real scrollMs: Math.max(1500, overflow * 22)
        readonly property real cycle: 1800 + scrollMs + 1400
        readonly property real scrollX: {
            const ph = t % cycle
            return ph < 1800 ? 0 : ph < 1800 + scrollMs ? (ph - 1800) / scrollMs * overflow : overflow
        }
        onShownChanged: t = 0
        Timer {
            interval: 33
            repeat: true
            running: view.active && box.overflow > 0
            onTriggered: box.t += 33
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            x: -box.scrollX
            wrapMode: Text.NoWrap
            textFormat: Text.StyledText
            text: {
                const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                const title = esc(MediaService.title)
                return MediaService.artist ? title + "<font color='" + Theme.muted + "'>  —  " + esc(MediaService.artist) + "</font>" : title
            }
            color: MediaService.playing ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Rectangle {
            visible: box.overflow > 0 && label.x < -1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Theme.surface
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
        Rectangle {
            visible: box.overflow > 0 && label.x > -box.overflow + 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Theme.surface
                }
            }
        }
    }
}
