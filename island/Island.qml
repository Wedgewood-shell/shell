import QtQuick
import Quickshell
import ".."

Pill {
    id: pill
    accent: Theme.border
    color: Theme.surface
    clip: true
    implicitWidth: (IslandController.islandMode === "volume" ? volume.implicitWidth : IslandController.islandMode
                                                               === "battery" ? battery.implicitWidth :
                                                                               IslandController.islandMode
                                                                               === "bluetooth"
                                                                               ? bluetooth.implicitWidth :
                                                                                 IslandController.islandMode
                                                                                 === "brightness"
                                                                                 ? brightness.implicitWidth :
                                                                                   IslandController.islandMode
                                                                                   === "network"
                                                                                   ? network.implicitWidth :
                                                                                     title.implicitWidth) + 36
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    WindowTitle {
        id: title
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
