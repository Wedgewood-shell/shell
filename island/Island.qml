import QtQuick
import Quickshell
import ".."

Pill {
    id: pill
    // Page-load progress traced around the island's perimeter.
    property bool showProgress: true
    // Draw the island's border (off when hosted inside a pill that has its own).
    property bool framed: true
    accent: Theme.border
    color: Theme.surface
    clip: true
    // The border is a Frame above the views, so nothing a view draws can cover it.
    border.width: 0
    Frame {
        visible: pill.framed
        border.color: pill.accent
    }
    // The hosting window's devicePixelRatio; geometry is snapped to whole pixels.
    property real dpr: 1
    implicitHeight: Theme.px(Theme.barHeight, dpr)
    implicitWidth: Theme.pxEven(baseWidth, dpr)
    readonly property real baseWidth: {
        switch (IslandController.islandMode) {
        case "helium":
        case "voice":
            return Theme.islandHeliumWidth
        case "media":
            return Theme.islandMediaWidth
        case "volume":
            return volume.implicitWidth + 36
        case "battery":
            return battery.implicitWidth + 36
        case "bluetooth":
            return bluetooth.implicitWidth + 36
        case "brightness":
            return brightness.implicitWidth + 36
        case "network":
            return network.implicitWidth + 36
        default:
            return Theme.islandBaseWidth
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    ClockView {
        id: clock
        anchors.fill: parent
    }
    HeliumView {
        id: helium
        anchors.fill: parent
    }
    VoiceView {
        id: voice
        anchors.fill: parent
    }
    MediaView {
        id: media
        anchors.fill: parent
    }
    PerimeterProgress {
        id: progressRing
        z: 101    // on the border, above the Frame
        // Follows load progress; on completion it runs to 1 and the ring then fades
        // out in place (it never rewinds). A new load restarts from its own value.
        property bool animate: true
        value: 0
        Behavior on value {
            enabled: progressRing.animate
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Connections {
            target: HeliumService
            function onProgressChanged() {
                if (HeliumService.loading)
                    progressRing.value = HeliumService.progress
            }
            function onLoadingChanged() {
                if (HeliumService.loading) {
                    progressRing.animate = false
                    progressRing.value = HeliumService.progress
                    progressRing.animate = true
                } else {
                    progressRing.value = 1
                }
            }
        }
        anchors.fill: parent
        radius: Theme.closedRadius
        visible: pill.showProgress && opacity > 0
        opacity: HeliumService.active && HeliumService.loading ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
    }
    VolumeAlert {
        id: volume
        anchors.centerIn: parent
    }
    BatteryAlert {
        id: battery
        anchors.centerIn: parent
    }
    BluetoothAlert {
        id: bluetooth
        anchors.centerIn: parent
    }
    BrightnessAlert {
        id: brightness
        anchors.centerIn: parent
    }
    NetworkAlert {
        id: network
        anchors.centerIn: parent
    }
}
