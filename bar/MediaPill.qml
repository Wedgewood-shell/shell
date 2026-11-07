import QtQuick
import Quickshell
import ".."
import Quickshell.Services.Mpris

Pill {
    id: media
    accent: "#4d7c9cff"
    implicitWidth: mediaRow.implicitWidth + 26
    readonly property var player: {
        const ps = Mpris.players.values
        for (const p of ps)
            if (p.isPlaying)
                return p
        return ps.length ? ps[0] : null
    }
    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: 10
        IconLabel {
            text: Theme.cp(0xF0388)
            color: "#c7d2ff"
        }
        IconLabel {
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            color: "#c7d2ff"
            text: media.player ? (media.player.trackArtist ? media.player.trackArtist + " — " : "")
                                 + media.player.trackTitle : ""
        }
    }
}
