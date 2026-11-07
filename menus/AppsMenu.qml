import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    title: "Search applications…"
    glyph: Theme.cp(0xF0349)
    readonly property int appCount: DesktopEntries.applications.values.length
    onAppCountChanged: refresh()
    function filter(q) {
        q = q.trim().toLowerCase()
        const byName = (a, b) => a.name.localeCompare(b.name)
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        const wrap = a => ({
            name: a.name,
            sub: a.genericName || "",
            icon: a.icon,
            app: a
        })
        if (!q)
            return apps.sort(byName).map(wrap)
        const scored = []
        for (const a of apps) {
            const n = a.name.toLowerCase()
            let s = -1
            if (n.startsWith(q))
                s = 100
            else if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
                s = 80
            else if (n.includes(q))
                s = 60
            else if ((a.genericName || "").toLowerCase().includes(q))
                s = 40
            else if ((a.keywords || []).some(k => k.toLowerCase().includes(q)))
                s = 30
            else if ((a.comment || "").toLowerCase().includes(q))
                s = 20
            if (s > 0)
                scored.push({
                                a: a,
                                s: s
                            })
        }
        scored.sort((x, y) => y.s - x.s || byName(x.a, y.a))
        return scored.map(x => wrap(x.a))
    }
    function activate(item) {
        if (!item)
            return
        OverlayController.launcherOpen = false
        const a = item.app
        if (a.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(a.command))
        else
            a.execute()
    }
}
