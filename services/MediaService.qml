pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

// The MPRIS player the island shows: the one playing, else the last one that
// played. `active` while it plays, and for `pausedGrace` ms after it pauses.
Singleton {
    id: root

    readonly property int pausedGrace: 30000

    readonly property var players: Mpris.players.values
    property var lastPlayed: null
    readonly property var player: {
        const ps = players
        const playing = ps.find(p => p.isPlaying)
        if (playing)
            return playing
        if (lastPlayed && ps.indexOf(lastPlayed) >= 0)
            return lastPlayed
        return ps.find(p => p.playbackState === MprisPlaybackState.Paused) || null
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool paused: player !== null && player.playbackState === MprisPlaybackState.Paused
    readonly property bool active: playing || (paused && graceOpen)

    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    // Polled (MPRIS doesn't push position changes), see the timer below.
    property real position: 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    onPlayingChanged: {
        if (playing) {
            lastPlayed = player
            graceOpen = true
            grace.stop()
        } else {
            grace.restart()
        }
    }
    onPlayerChanged: syncPosition()

    // A paused player keeps the island for a while, then drops back to the clock.
    property bool graceOpen: true
    Timer {
        id: grace
        interval: root.pausedGrace
        onTriggered: root.graceOpen = false
    }
    Component.onCompleted: {
        if (!playing)
            grace.start()
    }

    function syncPosition() {
        if (!player || !player.positionSupported) {
            position = 0
            return
        }
        player.positionChanged()
        position = player.position
    }
    Timer {
        interval: 500
        repeat: true
        running: root.playing
        onTriggered: root.syncPosition()
    }
    Connections {
        target: root.player
        function onPostTrackChanged() {
            root.syncPosition()
        }
        function onPlaybackStateChanged() {
            root.syncPosition()
        }
    }
}
