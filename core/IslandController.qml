pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // The resting state is the clock; transient alerts return here.
    property string islandMode: "clock"
    Timer {
        id: islandTimer
        interval: 2200
        onTriggered: root.islandMode = "clock"
    }
    function showVolume() {
        islandMode = "volume"
        islandTimer.restart()
    }

    property var btDevice: null
    property bool btUp: true
    function showBluetooth(dev, up) {
        btDevice = dev
        btUp = up !== false
        show("bluetooth")
    }
    function show(mode) {
        islandMode = mode
        islandTimer.restart()
    }
    function showBattery() {
        show("battery")
    }
    function showBrightness() {
        show("brightness")
    }
    function showNetwork() {
        show("network")
    }
}
