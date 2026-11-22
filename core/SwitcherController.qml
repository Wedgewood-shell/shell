pragma Singleton
import QtQuick
import Quickshell
import ".."

// Window switcher (Mod+Tab: every window, Alt+Tab: the focused app's windows).
// niri owns the keys and the selection (its `recent-windows { external }` mode) and
// reports them as RecentWindowsChanged events; this only presents them. niri
// commits the selection when the modifiers are released.
//
// A quick tap (released before `showDelay`) never displays anything: niri has
// already switched by then. The list appears after the delay, or at once when
// the selection moves again (the user is plainly cycling).
Singleton {
    id: root

    readonly property int showDelay: 250
    property bool open: false           // niri's switcher is open
    property bool shown: false          // ... and the list is on screen
    property var ids: []                // window ids, most recently used first
    property int selected: -1           // selected window id
    property string screen: ""          // output that shows the list
    readonly property int selectedIndex: ids.indexOf(selected)
    // Windows still known to niri, in switcher order.
    readonly property var entries: {
        const all = NiriService.windows
        return ids.map(id => all[id]).filter(w => w !== undefined)
    }

    Connections {
        target: NiriService
        function onEventReceived(ev) {
            if (ev.RecentWindowsChanged)
                root.apply(ev.RecentWindowsChanged)
        }
    }

    function apply(s) {
        if (!s.open) {
            showTimer.stop()
            open = false
            shown = false
            return
        }
        const moved = open && s.selected !== selected
        ids = s.windows
        selected = s.selected === null ? -1 : s.selected
        if (!open) {
            const ws = NiriService.workspaces[NiriService.focusedWs]
            screen = ws ? ws.output : ""
            open = true
            showTimer.restart()
        } else if (moved && !shown) {
            reveal()
        }
    }
    function reveal() {
        showTimer.stop()
        if (!open || shown)
            return
        OverlayController.dismissHud()
        OverlayController.launcherOpen = false
        shown = true
    }
    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: root.reveal()
    }
}
