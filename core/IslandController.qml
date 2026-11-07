pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // island state: "window" or "volume"
    property string islandMode: "window"
    Timer {
        id: islandTimer
        interval: 2200
        onTriggered: root.islandMode = "window"
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
