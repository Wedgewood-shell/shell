pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Raw touchpad swipe stream from libinput. Niri consumes 3-finger swipes
// itself and publishes nothing until they finish; reading the device in
// parallel lets presentation track the fingers live.
Singleton {
    id: root

    property bool live: true
    property bool active: false

    signal began(int fingers)
    signal moved(real dx, real dy)
    signal ended(bool cancelled)

    Process {
        id: stream
        running: root.live
        command: [Quickshell.shellDir + "/scripts/touchpad-gestures.sh"]
        onExited: code => {
            if (root.active) {
                root.active = false
                root.ended(true)
            }
            // Exit 2 means no gesture-capable device (e.g. no touchpad); retry slowly.
            if (root.live)
                restart.interval = code === 2 ? 30000 : 2000
            if (root.live)
                restart.restart()
        }
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(" ")
                if (f[0] === "U") {
                    root.moved(parseFloat(f[1]), parseFloat(f[2]))
                } else if (f[0] === "B") {
                    root.active = true
                    root.began(parseInt(f[1]))
                } else if (f[0] === "E") {
                    root.active = false
                    root.ended(f[1] === "1")
                }
            }
        }
    }
    Timer {
        id: restart
        onTriggered: stream.running = true
    }
}
