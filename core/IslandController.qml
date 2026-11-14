pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    // Base state: persists while its condition holds ("clock" is the default;
    // other base states override it). Ephemeral states (alerts, menus) are
    // timed / user-driven and fall back to the current base state.
    property string baseMode: "clock"
    property string islandMode: baseMode
    // When the island shows something other than the clock as its base,
    // the date/time moves into the bar's right module.
    readonly property bool clockInBar: baseMode !== "clock"
    onBaseModeChanged: if (!islandTimer.running) islandMode = baseMode
    Timer {
        id: islandTimer
        interval: 2200
        onTriggered: root.islandMode = root.baseMode
    }
    function showVolume() {
        show("volume")
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
