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
    // Follows Helium: while one of its windows has focus (or the address editor
    // that took its focus is open) the island shows the address bar.
    readonly property bool heliumBase: HeliumService.active || (OverlayController.launcherOpen && OverlayController.launcherMode === "address")
    readonly property string baseMode: heliumBase ? "helium" : "clock"
    property string islandMode: baseMode
    // When the island shows something other than the clock as its base,
    // the date/time moves into the bar's right module.
    readonly property bool clockInBar: baseMode !== "clock"
    onBaseModeChanged: if (!islandTimer.running) islandMode = voiceActive ? "voice" : baseMode
    Timer {
        id: islandTimer
        interval: 2200
        onTriggered: root.islandMode = root.voiceActive ? "voice" : root.baseMode
    }

    // Voice conversation (ephemeral): what the assistant says / the live
    // transcript of the user's reply. Driven over IPC by ttsd / sttd.
    // Short alerts (volume, ...) can interrupt it; it returns afterwards.
    property bool voiceActive: false
    property string voiceKind: "" // say | listen | final | notice
    property string voiceText: ""
    function voiceShow(kind, text, lingerMs) {
        voiceKind = kind
        voiceText = text
        voiceActive = true
        if (!islandTimer.running)
            islandMode = "voice"
        voiceTimer.interval = lingerMs
        voiceTimer.restart()
    }
    function voiceEnd() {
        voiceTimer.stop()
        voiceActive = false
        voiceText = ""
        if (!islandTimer.running)
            islandMode = baseMode
    }
    // Failsafe so a lost "speech ended" message can't pin the island.
    Timer {
        id: voiceTimer
        onTriggered: root.voiceEnd()
    }
    function voiceSay(text) {
        voiceShow("say", text, 120000)
    }
    function voiceSayEnd() {
        if (voiceKind === "say")
            voiceEnd()
    }
    function voiceListen() {
        voiceShow("listen", "", 150000)
    }
    function voicePartial(text) {
        if (voiceKind === "listen")
            voiceText = text.trim()
    }
    // status: ok | nopi | "" (empty text = nothing heard)
    function voiceFinal(text, status) {
        if (!text.trim())
            voiceShow("notice", "Didn't catch that", 1800)
        else if (status === "nopi")
            voiceShow("notice", "No pi session to reply to", 2500)
        else
            voiceShow("final", text.trim(), 2200)
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
