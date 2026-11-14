pragma Singleton
import QtQuick
import Quickshell
import ".."

// Remembers where the pointer last *really* moved, so lists can tell a user
// moving the mouse from a row appearing/scrolling under a stationary cursor.
Singleton {
    id: gate
    property bool valid: false
    property real x: 0
    property real y: 0
    Connections {
        target: OverlayController
        function onLauncherOpenChanged() {
            gate.valid = false
        }
    }
}
