pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import Quickshell.Services.Pipewire

Singleton {
    id: root
    // ---- audio ----
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: [root.sink]
    }
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? (sink.properties["device.profile.description"] || sink.nickname
                                               || sink.description || sink.name) : "No output"

    function volumeIcon() {
        if (muted)
            return Theme.cp(0xF075F)
        return volume < 0.34 ? Theme.cp(0xF057F) : volume < 0.67 ? Theme.cp(0xF0580) : Theme.cp(0xF057E)
    }

    signal changed
    Connections {
        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            root.changed()
        }
        function onMutedChanged() {
            root.changed()
        }
    }
    onSinkChanged: if (sink)
                       changed()
}
