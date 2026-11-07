import QtQuick
import Quickshell
import ".."

Pill {
    id: pill
    accent: Theme.border
    color: Theme.surface
    clip: true
    implicitWidth: {
        switch (IslandController.islandMode) {
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
