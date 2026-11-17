import QtQuick
import Quickshell
import "../.."

// Ephemeral voice-conversation state:
//   say    - what the assistant is speaking (long text scrolls like a marquee)
//   listen - live transcript of the user's reply (follows the newest words)
//   final  - last transcript / notice, shown briefly
Item {
    id: view
    property bool active: IslandController.islandMode === "voice"
    readonly property string kind: IslandController.voiceKind
    readonly property string text: IslandController.voiceText
    readonly property bool listening: kind === "listen"
    implicitWidth: Theme.islandHeliumWidth - 36
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

    IconLabel {
        id: lead
        anchors.verticalCenter: parent.verticalCenter
        x: 18
        text: view.kind === "say" ? Theme.cp(0xF057E) : view.kind === "listen" ? Theme.cp(0xF036C) : view.kind === "notice" ? Theme.cp(0xF0026) : Theme.cp(0xF012C)
        color: view.listening ? "#ff5c5c" : view.kind === "notice" ? Theme.muted : Theme.highlight
        font.pixelSize: 15
        SequentialAnimation on opacity {
            running: view.active && view.listening
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.35
                duration: 650
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 650
                easing.type: Easing.InOutSine
            }
        }
    }

    Item {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: lead.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 18
        height: parent.height
        clip: true

        readonly property string shown: view.text.length > 0 ? view.text : (view.listening ? "Listening…" : "")
        readonly property real overflow: Math.max(0, label.implicitWidth - width)
        // Marquee (say): pause, scroll to the end, pause, restart.
        property real t: 0
        readonly property real scrollMs: Math.max(1500, overflow * 22)
        readonly property real cycle: 1400 + scrollMs + 1000
        readonly property real scrollX: {
            const ph = t % cycle
            return ph < 1400 ? 0 : ph < 1400 + scrollMs ? (ph - 1400) / scrollMs * overflow : overflow
        }
        onShownChanged: t = 0
        Timer {
            interval: 33
            repeat: true
            running: view.active && view.kind === "say" && box.overflow > 0
            onTriggered: box.t += 33
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.NoWrap
            text: box.shown
            color: view.text.length > 0 || !view.listening ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            // listen: stick to the newest words; otherwise follow the marquee.
            x: box.overflow <= 0 ? 0 : view.listening ? -box.overflow : -box.scrollX
            Behavior on x {
                enabled: view.listening
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
        // Fade the clipped edges.
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
